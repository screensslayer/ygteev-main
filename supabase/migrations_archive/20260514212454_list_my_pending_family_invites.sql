
-- =============================================================================
-- list_my_pending_family_invites()
-- For the "scan their QR" flow: after the parent scans the invited user's QR
-- and calls create_family_invite(_invited_user_id: ...), the invited user's
-- iOS app calls this to discover the pending invite and show an Accept banner.
-- =============================================================================

create or replace function public.list_my_pending_family_invites()
returns table (
  invite_id     uuid,
  family_id     uuid,
  family_name   text,
  pairing_code  text,
  inviter_id    uuid,
  inviter_name  text,
  inviter_avatar text,
  created_at    timestamptz,
  expires_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $func$
  -- Sweep stale rows first
  with sweep as (
    update public.family_invites
       set status = 'expired'
     where status = 'pending' and expires_at <= now()
     returning 1
  )
  select
    fi.id            as invite_id,
    fi.family_id,
    f.name           as family_name,
    fi.pairing_code,
    fi.created_by    as inviter_id,
    p.display_name   as inviter_name,
    p.avatar_url     as inviter_avatar,
    fi.created_at,
    fi.expires_at
  from public.family_invites fi
  join public.families f on f.id = fi.family_id
  join public.profiles p on p.id = fi.created_by
  where fi.invited_user_id = auth.uid()
    and fi.status = 'pending'
    and fi.expires_at > now()
  order by fi.created_at desc;
$func$;

grant execute on function public.list_my_pending_family_invites() to authenticated;
notify pgrst, 'reload schema';
