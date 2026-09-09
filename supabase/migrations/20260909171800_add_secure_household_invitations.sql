create table if not exists public.household_invitations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  invited_email text not null check (btrim(invited_email) <> ''),
  token_hash text not null unique,
  role text not null default 'member' check (role = 'member'),
  status text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
  expires_at timestamptz not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null
);

create index if not exists household_invitations_household_idx
  on public.household_invitations (household_id, status, created_at desc);
create index if not exists household_invitations_email_idx
  on public.household_invitations (lower(invited_email), status);

revoke all on table public.household_invitations from anon;
grant select, insert, update on table public.household_invitations to authenticated;
grant all on table public.household_invitations to service_role;
alter table public.household_invitations enable row level security;

drop policy if exists household_invitation_select_manager on public.household_invitations;
drop policy if exists household_invitation_insert_manager on public.household_invitations;
drop policy if exists household_invitation_update_manager on public.household_invitations;

create policy household_invitation_select_manager
on public.household_invitations
for select
to authenticated
using (
  public.is_active_household_member(household_id)
  and exists (
    select 1
    from public.household_members actor
    where actor.household_id = household_invitations.household_id
      and actor.user_id = (select auth.uid())
      and actor.status = 'active'
      and actor.role in ('owner','admin')
  )
);

create policy household_invitation_insert_manager
on public.household_invitations
for insert
to authenticated
with check (
  public.is_active_household_member(household_id)
  and created_by = (select auth.uid())
  and exists (
    select 1
    from public.household_members actor
    where actor.household_id = household_invitations.household_id
      and actor.user_id = (select auth.uid())
      and actor.status = 'active'
      and actor.role in ('owner','admin')
  )
);

create policy household_invitation_update_manager
on public.household_invitations
for update
to authenticated
using (
  exists (
    select 1
    from public.household_members actor
    where actor.household_id = household_invitations.household_id
      and actor.user_id = (select auth.uid())
      and actor.status = 'active'
      and actor.role in ('owner','admin')
  )
)
with check (
  exists (
    select 1
    from public.household_members actor
    where actor.household_id = household_invitations.household_id
      and actor.user_id = (select auth.uid())
      and actor.status = 'active'
      and actor.role in ('owner','admin')
  )
  and role = 'member'
  and invited_email = lower(invited_email)
);

create or replace function public.accept_household_invitation(invite_token text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  current_user_id uuid := (select auth.uid());
  current_email text := lower(btrim(coalesce((select auth.jwt() ->> 'email'), '')));
  token_value text := btrim(invite_token);
  invitation public.household_invitations%rowtype;
begin
  if current_user_id is null or current_email = '' then
    raise exception 'Authenticated verified email is required.' using errcode = '42501';
  end if;
  if token_value = '' or length(token_value) < 16 then
    raise exception 'Invitation token is invalid.' using errcode = '22023';
  end if;

  select * into invitation
  from public.household_invitations
  where token_hash = encode(extensions.digest(convert_to(token_value, 'utf8'), 'sha256'), 'hex')
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Invitation is invalid or already used.' using errcode = 'P0002';
  end if;
  if invitation.expires_at <= now() then
    update public.household_invitations
      set status = 'expired'
    where id = invitation.id;
    raise exception 'Invitation has expired.' using errcode = '22007';
  end if;
  if lower(btrim(invitation.invited_email)) <> current_email then
    raise exception 'Invitation email does not match the signed-in account.' using errcode = '42501';
  end if;

  insert into public.household_members (household_id, user_id, role, status)
  values (invitation.household_id, current_user_id, 'member', 'active')
  on conflict (household_id, user_id) do update
    set role = case when public.household_members.role = 'owner' then 'owner' else 'member' end,
        status = 'active';

  update public.household_invitations
  set status = 'accepted', accepted_at = now(), accepted_by = current_user_id
  where id = invitation.id;

  return invitation.household_id;
end;
$$;

revoke all on function public.accept_household_invitation(text) from anon;
grant execute on function public.accept_household_invitation(text) to authenticated;
grant all on function public.accept_household_invitation(text) to service_role;
