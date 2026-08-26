-- Sharing support: reading who a list is shared with.
--
-- `profiles` is select-self only, so a plain join from `list_members` returns
-- user ids and no names — useless for a member list, and loosening the profiles
-- policy would let any signed-in user enumerate everyone's email. This definer
-- function is the narrow alternative: it reveals emails only for a list the
-- caller can already access, and only the emails of that list's participants.

create or replace function public.list_members_view(p_list_id uuid)
returns table (user_id uuid, email text, role text, is_owner boolean)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not public.can_access_list(p_list_id) then
    raise exception 'no_list_access';
  end if;

  return query
  select l.owner_id, p.email, 'owner'::text, true
  from public.lists l
  left join public.profiles p on p.id = l.owner_id
  where l.id = p_list_id
  union all
  select m.user_id, p.email, m.role, false
  from public.list_members m
  left join public.profiles p on p.id = m.user_id
  where m.list_id = p_list_id;
end;
$$;

-- An owner removing a member, or a member leaving, both go through the normal
-- delete policy on list_members; no RPC needed for either.

revoke all on function public.list_members_view(uuid) from public;
grant execute on function public.list_members_view(uuid) to authenticated;
