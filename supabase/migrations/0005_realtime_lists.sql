-- Broadcast list row changes (including tombstones) to signed-in clients.
--
-- The app subscribes with supabase realtime so a delete on one phone is
-- pulled on the other without waiting for the 30s heartbeat.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'lists'
  ) then
    execute 'alter publication supabase_realtime add table public.lists';
  end if;
end $$;
