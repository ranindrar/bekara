alter function public.create_invitation(text) set search_path = '', extensions;
alter function public.accept_invitation(text) set search_path = '', extensions;
alter function public.post_transaction(jsonb) set search_path = '', extensions;
alter function public.post_transfer(jsonb) set search_path = '', extensions;
alter function public.reverse_transaction(uuid, date, text, uuid) set search_path = '', extensions;
alter function public.correct_transaction(jsonb) set search_path = '', extensions;

create or replace function public.reconcile_wallet(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); wallet public.wallet_balances; aggregate public.transaction_aggregates;
  difference numeric; reference uuid := (payload->>'clientReferenceId')::uuid;
begin
  select * into wallet from public.wallet_balances
  where id = (payload->>'walletId')::uuid and household_id = public.my_active_household_id();
  if wallet.id is null then raise exception 'NOT_FOUND'; end if;
  if wallet.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
  difference := (payload->>'actualBalance')::numeric - wallet.balance;
  if difference = 0 then return jsonb_build_object('walletId', wallet.id, 'difference', '0'); end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, client_reference_id, created_by)
  values (wallet.household_id, actor, 'ADJUSTMENT', (payload->>'transactionDate')::date, 'PRIVATE', 'PRIVATE_FULL',
    nullif(btrim(payload->>'reason'), ''), reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, direction, amount)
  values (aggregate.id, wallet.id, case when difference > 0
    then 'CREDIT'::public.entry_direction else 'DEBIT'::public.entry_direction end, abs(difference));
  return jsonb_build_object('id', aggregate.id, 'difference', difference::text, 'version', aggregate.version);
end;
$$;

create or replace function public.resolve_obligation_occurrence(
  occurrence_id uuid, action text, rescheduled_date date default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare occurrence public.obligation_occurrences; obligation public.recurring_obligations; replacement public.obligation_occurrences;
begin
  if action not in ('SKIP', 'RESCHEDULE') then raise exception 'VALIDATION_ERROR'; end if;
  select * into occurrence from public.obligation_occurrences x
    where x.id = occurrence_id and x.household_id = public.my_active_household_id() for update;
  if occurrence.id is null or occurrence.status <> 'PENDING' then raise exception 'NOT_FOUND'; end if;
  select * into obligation from public.recurring_obligations where id = occurrence.obligation_id;
  if obligation.owner_id <> auth.uid() and obligation.scope <> 'HOUSEHOLD' then raise exception 'FORBIDDEN'; end if;
  update public.obligation_occurrences set status = case when action = 'SKIP'
      then 'SKIPPED'::public.obligation_occurrence_status
      else 'RESCHEDULED'::public.obligation_occurrence_status end,
    resolved_at = now(), resolved_by = auth.uid(), updated_at = now(), version = version + 1
    where id = occurrence.id;
  if action = 'RESCHEDULE' then
    if rescheduled_date is null or rescheduled_date < current_date then raise exception 'VALIDATION_ERROR: reschedule date'; end if;
    insert into public.obligation_occurrences(household_id, obligation_id, due_date, estimated_amount)
    values (occurrence.household_id, occurrence.obligation_id, rescheduled_date, occurrence.estimated_amount)
    returning * into replacement;
  end if;
  return jsonb_build_object('id', occurrence.id,
    'status', case when action = 'SKIP' then 'SKIPPED' else 'RESCHEDULED' end,
    'replacementId', replacement.id);
end;
$$;

revoke all on function public.reconcile_wallet(jsonb),
  public.resolve_obligation_occurrence(uuid, text, date) from public, anon;
grant execute on function public.reconcile_wallet(jsonb),
  public.resolve_obligation_occurrence(uuid, text, date) to authenticated;
