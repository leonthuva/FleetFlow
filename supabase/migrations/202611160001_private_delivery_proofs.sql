begin;
-- Review-gated migration. A service-side Firestore decision precedes every grant.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('delivery-proofs','delivery-proofs',false,5000000,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=5000000,allowed_mime_types=excluded.allowed_mime_types;
create schema if not exists fleetflow_private;
revoke all on schema fleetflow_private from public,anon,authenticated;
grant usage on schema fleetflow_private to authenticated,service_role;
create table if not exists fleetflow_private.proof_upload_grants(
 attempt_id uuid primary key,
 driver_uid text not null check(driver_uid ~ '^[A-Za-z0-9_-]{1,128}$'),
 delivery_id text not null check(delivery_id ~ '^[A-Za-z0-9_-]{1,128}$'),
 object_name text unique not null,
 mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
 size_bytes bigint not null check(size_bytes between 1 and 5000000),
 sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),
 expires_at timestamptz not null,
 state text not null default 'pending' check(state in ('pending','closed')),
 created_at timestamptz not null default now(),
 check(object_name = driver_uid || '/' || delivery_id || '/' || attempt_id::text || case mime_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png' else '.webp' end)
);
alter table fleetflow_private.proof_upload_grants enable row level security;
revoke all on fleetflow_private.proof_upload_grants from public,anon,authenticated;
grant all on fleetflow_private.proof_upload_grants to service_role;

create or replace function fleetflow_private.proof_upload_allowed(object_path text)
returns boolean language sql stable security definer set search_path = '' as $$
 select coalesce(auth.jwt()->>'role'='authenticated'
  and auth.jwt()->>'iss'='https://securetoken.google.com/fleetflow-dev-29e55'
  and auth.jwt()->>'aud'='fleetflow-dev-29e55'
  and exists(select 1 from fleetflow_private.proof_upload_grants g
   where g.object_name=object_path and g.driver_uid=auth.jwt()->>'sub'
    and g.state='pending' and g.expires_at>now()),false)
$$;
revoke all on function fleetflow_private.proof_upload_allowed(text) from public,anon;
grant execute on function fleetflow_private.proof_upload_allowed(text) to authenticated,service_role;

create or replace function public.fleetflow_put_proof_grant(p_attempt_id uuid,p_driver_uid text,p_delivery_id text,p_object_name text,p_mime_type text,p_size_bytes bigint,p_sha256 text,p_expires_at timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if p_expires_at>now()+interval '16 minutes' or p_expires_at<=now() then raise exception 'Invalid upload expiry'; end if;
 insert into fleetflow_private.proof_upload_grants(attempt_id,driver_uid,delivery_id,object_name,mime_type,size_bytes,sha256,expires_at)
 values(p_attempt_id,p_driver_uid,p_delivery_id,p_object_name,p_mime_type,p_size_bytes,p_sha256,p_expires_at)
 on conflict(attempt_id) do nothing;
 if not exists(select 1 from fleetflow_private.proof_upload_grants where attempt_id=p_attempt_id and driver_uid=p_driver_uid and delivery_id=p_delivery_id and object_name=p_object_name and mime_type=p_mime_type and size_bytes=p_size_bytes and sha256=p_sha256 and expires_at=p_expires_at) then raise exception 'Immutable upload authorization conflict'; end if;
 -- Never reopen a closed grant during a retry; the existing immutable object can still be finalized.
end $$;
revoke all on function public.fleetflow_put_proof_grant(uuid,text,text,text,text,bigint,text,timestamptz) from public,anon,authenticated;
grant execute on function public.fleetflow_put_proof_grant(uuid,text,text,text,text,bigint,text,timestamptz) to service_role;

create or replace function public.fleetflow_close_proof_grant(p_attempt_id uuid)
returns void language sql security definer set search_path = '' as $$
 update fleetflow_private.proof_upload_grants set state='closed' where attempt_id=p_attempt_id
$$;
revoke all on function public.fleetflow_close_proof_grant(uuid) from public,anon,authenticated;
grant execute on function public.fleetflow_close_proof_grant(uuid) to service_role;

-- The restrictive guard also protects this bucket from unrelated permissive policies.
-- No client SELECT, UPDATE or DELETE: proof reads go through fresh Firestore authorization
-- and short-lived signed URLs; cleanup is exclusively server-side and proof-aware.
drop policy if exists fleetflow_private_proof_guard on storage.objects;
create policy fleetflow_private_proof_guard on storage.objects as restrictive for all to authenticated
 using(bucket_id <> 'delivery-proofs')
 with check(bucket_id <> 'delivery-proofs' or (bucket_id='delivery-proofs' and (select auth.jwt()->>'role')='authenticated' and fleetflow_private.proof_upload_allowed(name)));
drop policy if exists fleetflow_anonymous_proof_guard on storage.objects;
create policy fleetflow_anonymous_proof_guard on storage.objects as restrictive for all to anon
 using(bucket_id <> 'delivery-proofs') with check(bucket_id <> 'delivery-proofs');
drop policy if exists fleetflow_proof_authorized_insert on storage.objects;
create policy fleetflow_proof_authorized_insert on storage.objects for insert to authenticated
 with check(bucket_id='delivery-proofs' and fleetflow_private.proof_upload_allowed(name));
commit;
