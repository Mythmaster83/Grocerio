-- Grocerio backend schema.
--
-- Design notes that matter when reading the policies below:
--
-- 1. Access to a list is "owner OR member". Expressing that directly in a
--    policy on `lists` that queries `list_members`, while `list_members` has a
--    policy that queries `lists`, makes Postgres recurse and fail at runtime.
--    The SECURITY DEFINER helpers exist to break that cycle; they bypass RLS
--    internally and are the only place allowed to do so.
-- 2. Rows are never hard-deleted by the client. Tombstones (`deleted_at`) are
--    what let a delete on one device reach another; a real DELETE just gets
--    re-pushed by whichever device hadn't synced yet.
-- 3. Prices are readable by every signed-in user. That's the entire point of
--    collecting them, and because they're all shopper-submitted there is no
--    third-party redistribution question to answer.

-- ---------------------------------------------------------------- extensions
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

-- Populated by a trigger rather than the client so an invite can resolve an
-- email to a user id even before that user has opened the app.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------- lists
create table if not exists public.lists (
  id uuid primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  frequency int not null default 0,
  scheduled_for timestamptz not null,
  last_missed_on timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists lists_owner_idx on public.lists (owner_id);
create index if not exists lists_updated_idx on public.lists (updated_at);

create table if not exists public.list_items (
  id uuid primary key,
  list_id uuid not null references public.lists (id) on delete cascade,
  name text not null,
  quantity double precision not null default 1,
  unit int not null default 0,
  custom_unit text,
  -- Slug, not an integer id: local catalog ids differ per install.
  canonical_slug text,
  is_checked boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists list_items_list_idx on public.list_items (list_id);
create index if not exists list_items_updated_idx on public.list_items (updated_at);

create table if not exists public.list_members (
  list_id uuid not null references public.lists (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'editor',
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);

create index if not exists list_members_user_idx on public.list_members (user_id);

-- -------------------------------------------------------------- price reports
create table if not exists public.price_reports (
  id uuid primary key,
  canonical_slug text not null,
  store_slug text not null,
  price numeric(10, 2) not null check (price > 0 and price <= 9999.99),
  unit text not null,
  reported_at timestamptz not null default now(),
  reported_by uuid not null references auth.users (id) on delete cascade,
  zip text
);

create index if not exists price_reports_lookup_idx
  on public.price_reports (canonical_slug, store_slug, reported_at desc);
create index if not exists price_reports_zip_idx on public.price_reports (zip);
create index if not exists price_reports_reported_at_idx
  on public.price_reports (reported_at);

-- ------------------------------------------------------- access helper (RLS)
create or replace function public.is_list_owner(p_list_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.lists l
    where l.id = p_list_id and l.owner_id = auth.uid()
  );
$$;

create or replace function public.can_access_list(p_list_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.lists l
    where l.id = p_list_id and l.owner_id = auth.uid()
  ) or exists (
    select 1 from public.list_members m
    where m.list_id = p_list_id and m.user_id = auth.uid()
  );
$$;

-- ------------------------------------------------------------------- policies
alter table public.profiles enable row level security;
alter table public.lists enable row level security;
alter table public.list_items enable row level security;
alter table public.list_members enable row level security;
alter table public.price_reports enable row level security;

-- Profiles are private. Email lookup for invites happens inside a definer
-- function, so no policy needs to expose other people's addresses.
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles
  for select using (id = auth.uid());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists lists_select on public.lists;
create policy lists_select on public.lists
  for select using (owner_id = auth.uid() or public.can_access_list(id));

drop policy if exists lists_insert on public.lists;
create policy lists_insert on public.lists
  for insert with check (owner_id = auth.uid());

-- Members may edit a shared list (that is what sharing means here) but only the
-- owner may remove it.
drop policy if exists lists_update on public.lists;
create policy lists_update on public.lists
  for update using (public.can_access_list(id))
  with check (public.can_access_list(id));

drop policy if exists lists_delete on public.lists;
create policy lists_delete on public.lists
  for delete using (owner_id = auth.uid());

drop policy if exists list_items_all on public.list_items;
create policy list_items_all on public.list_items
  for all using (public.can_access_list(list_id))
  with check (public.can_access_list(list_id));

drop policy if exists list_members_select on public.list_members;
create policy list_members_select on public.list_members
  for select using (user_id = auth.uid() or public.can_access_list(list_id));

drop policy if exists list_members_insert on public.list_members;
create policy list_members_insert on public.list_members
  for insert with check (public.is_list_owner(list_id));

-- A member can remove themselves; an owner can remove anyone.
drop policy if exists list_members_delete on public.list_members;
create policy list_members_delete on public.list_members
  for delete using (user_id = auth.uid() or public.is_list_owner(list_id));

drop policy if exists price_reports_select on public.price_reports;
create policy price_reports_select on public.price_reports
  for select using (auth.uid() is not null);

drop policy if exists price_reports_insert on public.price_reports;
create policy price_reports_insert on public.price_reports
  for insert with check (reported_by = auth.uid());

drop policy if exists price_reports_update on public.price_reports;
create policy price_reports_update on public.price_reports
  for update using (reported_by = auth.uid())
  with check (reported_by = auth.uid());

drop policy if exists price_reports_delete on public.price_reports;
create policy price_reports_delete on public.price_reports
  for delete using (reported_by = auth.uid());

-- ----------------------------------------------------------------------- rpcs
-- Invites are by email, but the client must never be able to enumerate emails,
-- so the lookup happens here with the caller's ownership checked first.
create or replace function public.invite_member_by_email(
  p_list_id uuid,
  p_email text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  if not public.is_list_owner(p_list_id) then
    raise exception 'not_list_owner';
  end if;

  select id into v_user_id
  from public.profiles
  where lower(email) = lower(trim(p_email));

  if v_user_id is null then
    raise exception 'user_not_found';
  end if;

  insert into public.list_members (list_id, user_id)
  values (p_list_id, v_user_id)
  on conflict do nothing;
end;
$$;

-- Google requires in-app account deletion. Deleting the auth user cascades to
-- profiles, lists, memberships, and price reports.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.invite_member_by_email(uuid, text) from public;
revoke all on function public.delete_own_account() from public;
grant execute on function public.invite_member_by_email(uuid, text) to authenticated;
grant execute on function public.delete_own_account() to authenticated;
