create or replace function public.validate_budget_target()
returns trigger language plpgsql security definer set search_path = '' as $$
declare selected_period public.financial_periods; selected_category public.categories;
begin
  select * into selected_period from public.financial_periods where id = new.period_id;
  select * into selected_category from public.categories where id = new.category_id;
  if selected_period.id is null or selected_period.household_id <> new.household_id then
    raise exception 'VALIDATION_ERROR: period';
  end if;
  if selected_category.id is null or selected_category.household_id <> new.household_id
      or selected_category.direction <> 'EXPENSE' then
    raise exception 'VALIDATION_ERROR: category';
  end if;
  if (new.scope = 'HOUSEHOLD' and selected_period.period_type <> 'HOUSEHOLD')
      or (new.scope = 'PRIVATE' and selected_period.period_type <> 'PERSONAL') then
    raise exception 'VALIDATION_ERROR: period scope';
  end if;
  if new.scope = 'HOUSEHOLD' and selected_category.scope <> 'HOUSEHOLD' then
    raise exception 'VALIDATION_ERROR: category scope';
  end if;
  return new;
end;
$$;

create trigger budget_target_guard
before insert or update of period_id, category_id, scope on public.budgets
for each row execute function public.validate_budget_target();

create or replace function public.protect_soft_locked_funds()
returns trigger language plpgsql security definer set search_path = '' as $$
declare aggregate_kind public.transaction_kind; current_balance numeric; reserved numeric;
begin
  if new.direction <> 'DEBIT' then return new; end if;
  select a.kind into aggregate_kind from public.transaction_aggregates a where a.id = new.aggregate_id;
  if aggregate_kind not in ('EXPENSE', 'BILL_PAYMENT', 'TRANSFER') then return new; end if;
  select w.balance into current_balance from public.wallet_balances w where w.id = new.wallet_id;
  select coalesce(sum(f.amount), 0) into reserved from public.locked_funds f
    where f.wallet_id = new.wallet_id and f.active;
  if reserved > 0 and current_balance - new.amount < reserved then
    raise exception 'LOCKED_FUNDS_IN_USE';
  end if;
  return new;
end;
$$;

create trigger ledger_soft_lock_guard
before insert on public.ledger_entries
for each row execute function public.protect_soft_locked_funds();

revoke all on function public.validate_budget_target(), public.protect_soft_locked_funds()
  from public, anon, authenticated;
