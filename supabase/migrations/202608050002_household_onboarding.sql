create table public.household_invitations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  email text not null,
  token_hash text not null unique,
  invited_by uuid not null references public.profiles(id),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.household_invitations enable row level security;

create policy household_invitations_owner_read
  on public.household_invitations for select
  using (
    exists (
      select 1 from public.household_members m
      where m.household_id = household_invitations.household_id
        and m.user_id = auth.uid()
        and m.role = 'OWNER'
        and m.status = 'ACTIVE'
    )
  );

create or replace function public.get_my_context()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'profile', jsonb_build_object(
      'id', p.id,
      'displayName', p.display_name,
      'timezone', p.timezone
    ),
    'membership', case when m.id is null then null else jsonb_build_object(
      'id', m.id,
      'role', m.role,
      'status', m.status
    ) end,
    'household', case when h.id is null then null else jsonb_build_object(
      'id', h.id,
      'name', h.name,
      'currency', h.currency,
      'timezone', h.timezone,
      'reportingStartDay', h.reporting_start_day,
      'version', h.version
    ) end
  )
  from public.profiles p
  left join public.household_members m
    on m.user_id = p.id and m.status = 'ACTIVE'
  left join public.households h on h.id = m.household_id
  where p.id = auth.uid();
$$;

create or replace function public.create_household(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  household_name text := btrim(payload->>'name');
  start_day integer := coalesce((payload->>'reportingStartDay')::integer, 25);
  created_household public.households;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household_name is null or char_length(household_name) not between 2 and 100 then
    raise exception 'VALIDATION_ERROR: household name';
  end if;
  if start_day not between 1 and 31 then
    raise exception 'VALIDATION_ERROR: reporting start day';
  end if;
  if exists (select 1 from public.household_members where user_id = actor and status = 'ACTIVE') then
    raise exception 'VALIDATION_ERROR: user already belongs to a household';
  end if;

  insert into public.households(name, reporting_start_day, owner_id)
  values (household_name, start_day, actor)
  returning * into created_household;

  insert into public.household_members(household_id, user_id, role)
  values (created_household.id, actor, 'OWNER');

  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (created_household.id, actor, 'HOUSEHOLD', created_household.id, 'CREATE', to_jsonb(created_household));

  return jsonb_build_object(
    'id', created_household.id,
    'name', created_household.name,
    'currency', created_household.currency,
    'timezone', created_household.timezone,
    'reportingStartDay', created_household.reporting_start_day,
    'version', created_household.version
  );
end;
$$;

create or replace function public.create_invitation(invitee_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  actor_household uuid;
  normalized_email text := lower(btrim(invitee_email));
  raw_token text := encode(gen_random_bytes(24), 'hex');
  invitation public.household_invitations;
begin
  select m.household_id into actor_household
  from public.household_members m
  where m.user_id = actor and m.role = 'OWNER' and m.status = 'ACTIVE';
  if actor_household is null then raise exception 'FORBIDDEN'; end if;
  if normalized_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'VALIDATION_ERROR: email';
  end if;

  insert into public.household_invitations(
    household_id, email, token_hash, invited_by, expires_at
  ) values (
    actor_household, normalized_email, encode(digest(raw_token, 'sha256'), 'hex'), actor, now() + interval '7 days'
  ) returning * into invitation;

  return jsonb_build_object('token', raw_token, 'email', invitation.email, 'expiresAt', invitation.expires_at);
end;
$$;

create or replace function public.accept_invitation(invitation_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  actor_email text;
  invitation public.household_invitations;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if exists (select 1 from public.household_members where user_id = actor and status = 'ACTIVE') then
    raise exception 'VALIDATION_ERROR: user already belongs to a household';
  end if;
  select lower(email) into actor_email from auth.users where id = actor;
  select * into invitation
  from public.household_invitations
  where token_hash = encode(digest(invitation_token, 'sha256'), 'hex')
    and used_at is null and expires_at > now()
  for update;
  if invitation.id is null then raise exception 'NOT_FOUND: invitation'; end if;
  if invitation.email <> actor_email then raise exception 'FORBIDDEN'; end if;

  insert into public.household_members(household_id, user_id, role)
  values (invitation.household_id, actor, 'MEMBER');
  update public.household_invitations set used_at = now() where id = invitation.id;
  return public.get_my_context();
end;
$$;

revoke all on function public.get_my_context() from public;
revoke all on function public.create_household(jsonb) from public;
revoke all on function public.create_invitation(text) from public;
revoke all on function public.accept_invitation(text) from public;
grant execute on function public.get_my_context() to authenticated;
grant execute on function public.create_household(jsonb) to authenticated;
grant execute on function public.create_invitation(text) to authenticated;
grant execute on function public.accept_invitation(text) to authenticated;

