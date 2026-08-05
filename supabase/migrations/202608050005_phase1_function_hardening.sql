revoke all on function public.list_wallets() from public, anon;
revoke all on function public.create_wallet(jsonb) from public, anon;
revoke all on function public.update_wallet(uuid, integer, jsonb) from public, anon;
revoke all on function public.list_categories(text) from public, anon;
revoke all on function public.create_category(jsonb) from public, anon;
revoke all on function public.post_transaction(jsonb) from public, anon;
revoke all on function public.post_transfer(jsonb) from public, anon;
revoke all on function public.list_transactions(integer) from public, anon;
revoke all on function public.dashboard_summary() from public, anon;
revoke all on function public.report_category() from public, anon;
revoke all on function public.archive_category(uuid, integer) from public, anon;
revoke all on function public.reverse_transaction(uuid, date, text, uuid) from public, anon;
revoke all on function public.reconcile_wallet(jsonb) from public, anon;

grant execute on function public.list_wallets(), public.create_wallet(jsonb),
  public.update_wallet(uuid, integer, jsonb), public.list_categories(text),
  public.create_category(jsonb), public.post_transaction(jsonb), public.post_transfer(jsonb),
  public.list_transactions(integer), public.dashboard_summary(), public.report_category(),
  public.archive_category(uuid, integer), public.reverse_transaction(uuid, date, text, uuid),
  public.reconcile_wallet(jsonb) to authenticated;
