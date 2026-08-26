-- Tracked store locations follow the signed-in account (not only the device).
--
-- Seeded store rows stay on-device (large directory). This table stores only
-- the slugs the user turned on, so a new phone can restore the same set.

create table if not exists public.user_tracked_stores (
  user_id uuid not null references auth.users (id) on delete cascade,
  store_slug text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, store_slug)
);

create index if not exists user_tracked_stores_user_idx
  on public.user_tracked_stores (user_id);

alter table public.user_tracked_stores enable row level security;

drop policy if exists user_tracked_stores_select_own on public.user_tracked_stores;
create policy user_tracked_stores_select_own on public.user_tracked_stores
  for select using (auth.uid() = user_id);

drop policy if exists user_tracked_stores_insert_own on public.user_tracked_stores;
create policy user_tracked_stores_insert_own on public.user_tracked_stores
  for insert with check (auth.uid() = user_id);

drop policy if exists user_tracked_stores_update_own on public.user_tracked_stores;
create policy user_tracked_stores_update_own on public.user_tracked_stores
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists user_tracked_stores_delete_own on public.user_tracked_stores;
create policy user_tracked_stores_delete_own on public.user_tracked_stores
  for delete using (auth.uid() = user_id);
