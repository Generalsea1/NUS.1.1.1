create schema if not exists private;

create or replace function private.accept_household_invitation_impl(invite_token text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
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
$function$;

revoke all on function private.accept_household_invitation_impl(text) from public;
revoke all on function private.accept_household_invitation_impl(text) from anon;
revoke all on function private.accept_household_invitation_impl(text) from authenticated;
grant execute on function private.accept_household_invitation_impl(text) to postgres;

create or replace function public.accept_household_invitation(invite_token text)
returns uuid
language sql
security invoker
set search_path = public, pg_catalog
as $function$
  select private.accept_household_invitation_impl(invite_token);
$function$;

revoke all on function public.accept_household_invitation(text) from public;
grant execute on function public.accept_household_invitation(text) to authenticated;
