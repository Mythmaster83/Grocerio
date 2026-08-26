-- Keep list/item tombstones sticky on the server.
--
-- A live upsert from a phone that has not pulled yet must not clear
-- deleted_at. The Flutter client already omits null deleted_at, but a
-- PostgREST merge that sent the column as null would resurrect the row
-- on every other device.

create or replace function public.keep_row_tombstone()
returns trigger
language plpgsql
as $$
begin
  if old.deleted_at is not null and new.deleted_at is null then
    new.deleted_at := old.deleted_at;
  end if;
  return new;
end;
$$;

drop trigger if exists lists_keep_tombstone on public.lists;
create trigger lists_keep_tombstone
  before update on public.lists
  for each row execute function public.keep_row_tombstone();

drop trigger if exists list_items_keep_tombstone on public.list_items;
create trigger list_items_keep_tombstone
  before update on public.list_items
  for each row execute function public.keep_row_tombstone();
