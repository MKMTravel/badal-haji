-- =====================================================================
-- BH-009: Admin padam pendaftaran abandon (tiada bayaran disahkan, tiada pengendali)
-- =====================================================================
create or replace function public.bh_padam_pendaftaran(p_ref text) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype;
begin
  if not public.bh_is_staff() then return json_build_object('ok', false, 'error', 'Tiada kebenaran'); end if;
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'Rujukan tidak dijumpai'); end if;
  if r.pembadal_id is not null or r.status_bayaran = 'Berjaya' or exists (select 1 from public.bh_bayaran where ref = r.ref and status = 'Disahkan') then
    return json_build_object('ok', false, 'error', 'Pendaftaran ini ada bayaran disahkan atau pengendali; tidak boleh dipadam');
  end if;
  insert into public.bh_audit_log (user_id, staf, tindakan, ref, butiran)
  values (auth.uid(), '', 'padam_pendaftaran', r.ref, json_build_object('nama', r.nama, 'telefon', r.telefon, 'd_nama', r.d_nama, 'status_bayaran', r.status_bayaran, 'tarikh', r.created_at)::jsonb);
  delete from public.bh_checkin where ref = r.ref;
  delete from public.bh_bayaran where ref = r.ref;
  delete from public.bh_pendaftaran where ref = r.ref;
  return json_build_object('ok', true, 'ref', r.ref);
end $$;
revoke all on function public.bh_padam_pendaftaran(text) from public, anon;
grant execute on function public.bh_padam_pendaftaran(text) to authenticated;
select 'ok' as status;
