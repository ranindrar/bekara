create or replace function public.archive_category(category_id uuid, expected_version integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); changed public.categories;
begin
  update public.categories set active = false, updated_at = now(), version = version + 1
  where id = category_id and household_id = public.my_active_household_id()
    and owner_id = actor and not system_category and version = expected_version
  returning * into changed;
  if changed.id is null then raise exception 'NOT_FOUND_OR_VERSION_CONFLICT'; end if;
  return jsonb_build_object('id', changed.id, 'version', changed.version, 'active', false);
end;
$$;

create or replace function public.reverse_transaction(
  transaction_id uuid, transaction_date date, reason text, client_reference_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); original public.transaction_aggregates; reversal public.transaction_aggregates;
  entry record;
begin
  select * into original from public.transaction_aggregates
  where id = transaction_id and household_id = public.my_active_household_id() for update;
  if original.id is null then raise exception 'NOT_FOUND'; end if;
  if original.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
  if original.status <> 'POSTED' then raise exception 'VALIDATION_ERROR: already reversed'; end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, status, reversal_of_id, client_reference_id, created_by)
  values (original.household_id, actor, 'REVERSAL', transaction_date, original.scope, original.privacy,
    reason, 'POSTED', original.id, client_reference_id, actor) returning * into reversal;
  for entry in select * from public.ledger_entries where aggregate_id = original.id loop
    insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
    values (reversal.id, entry.wallet_id, entry.category_id,
      case when entry.direction = 'CREDIT' then 'DEBIT'::public.entry_direction else 'CREDIT'::public.entry_direction end,
      entry.amount);
  end loop;
  update public.transaction_aggregates set status = 'REVERSED', updated_at = now(), version = version + 1
  where id = original.id;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, reason, after_value)
  values (original.household_id, actor, 'TRANSACTION', original.id, 'REVERSE', reason, to_jsonb(reversal));
  return jsonb_build_object('id', reversal.id, 'reversalOfId', original.id, 'version', reversal.version);
end;
$$;

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
  values (aggregate.id, wallet.id, case when difference > 0 then 'CREDIT' else 'DEBIT' end, abs(difference));
  return jsonb_build_object('id', aggregate.id, 'difference', difference::text, 'version', aggregate.version);
end;
$$;

grant execute on function public.archive_category(uuid, integer),
  public.reverse_transaction(uuid, date, text, uuid), public.reconcile_wallet(jsonb) to authenticated;
