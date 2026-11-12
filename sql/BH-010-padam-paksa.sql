-- BH-010: bh_padam_pendaftaran dengan pilihan paksa (padam walaupun ada bayaran disahkan / pengendali)
drop function if exists public.bh_padam_pendaftaran(text);
create or replace function public.bh_padam_pendaftaran(p_ref text, p_paksa boolean default false) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; ada_sah boolean;
begin
  if not public.bh_is_staff() then return json_build_object('ok', false, 'error', 'Tiada kebenaran'); end if;
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'Rujukan tidak dijumpai'); end if;
  ada_sah := exists (select 1 from public.bh_bayaran where ref = r.ref and status = 'Disahkan');
  if not coalesce(p_paksa,false) and (r.pembadal_id is not null or r.status_bayaran = 'Berjaya' or ada_sah) then
    return json_build_object('ok', false, 'error', 'Pendaftaran ini ada bayaran disahkan atau pengendali; sahkan pemadaman paksa');
  end if;
  insert into public.bh_audit_log (user_id, staf, tindakan, ref, butiran)
  values (auth.uid(), '', case when coalesce(p_paksa,false) then 'padam_pendaftaran_paksa' else 'padam_pendaftaran' end, r.ref,
    json_build_object('nama', r.nama, 'telefon', r.telefon, 'd_nama', r.d_nama, 'status_bayaran', r.status_bayaran, 'amaun_dibayar', r.amaun_dibayar, 'pembadal_id', r.pembadal_id, 'tarikh', r.created_at)::jsonb);
  delete from public.bh_checkin where ref = r.ref;
  delete from public.bh_bayaran where ref = r.ref;
  delete from public.bh_pendaftaran where ref = r.ref;
  return json_build_object('ok', true, 'ref', r.ref);
end $$;
revoke all on function public.bh_padam_pendaftaran(text, boolean) from public, anon;
grant execute on function public.bh_padam_pendaftaran(text, boolean) to authenticated;
select 'ok' as status;
