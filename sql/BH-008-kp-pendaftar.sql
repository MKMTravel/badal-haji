-- =====================================================================
-- BH-008: No. kad pengenalan pendaftar (untuk e-invois)
-- =====================================================================
alter table public.bh_pendaftaran add column if not exists kp text default '';

create or replace function public.bh_simpan_kp(p_ref text, p_telefon text, p_kp text) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; d1 text; d2 text; k text;
begin
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'Rujukan tidak dijumpai'); end if;
  d1 := right(regexp_replace(coalesce(r.telefon,''), '\D', '', 'g'), 9);
  d2 := right(regexp_replace(coalesce(p_telefon,''), '\D', '', 'g'), 9);
  if d1 = '' or d1 <> d2 then return json_build_object('ok', false, 'error', 'Telefon tidak sepadan'); end if;
  k := regexp_replace(coalesce(p_kp,''), '\D', '', 'g');
  if length(k) <> 12 then return json_build_object('ok', false, 'error', 'No. KP tidak sah'); end if;
  -- hanya isi jika masih kosong (pendaftar tidak boleh tukar selepas direkod)
  update public.bh_pendaftaran set kp = left(k,6) || '-' || substr(k,7,2) || '-' || right(k,4) where ref = r.ref and coalesce(kp,'') = '';
  return json_build_object('ok', true);
end $$;
revoke all on function public.bh_simpan_kp(text,text,text) from public;
grant execute on function public.bh_simpan_kp(text,text,text) to anon, authenticated;

-- Admin kemas kini KP (staf sahaja)
create or replace function public.bh_admin_kp(p_ref text, p_kp text) returns json
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if not public.bh_is_staff() then return json_build_object('ok', false, 'error', 'Tiada kebenaran'); end if;
  k := regexp_replace(coalesce(p_kp,''), '\D', '', 'g');
  if length(k) <> 12 then return json_build_object('ok', false, 'error', 'No. KP tidak sah (12 digit)'); end if;
  update public.bh_pendaftaran set kp = left(k,6) || '-' || substr(k,7,2) || '-' || right(k,4) where ref = upper(trim(p_ref));
  return json_build_object('ok', true);
end $$;
revoke all on function public.bh_admin_kp(text,text) from public, anon;
grant execute on function public.bh_admin_kp(text,text) to authenticated;

select column_name from information_schema.columns where table_name='bh_pendaftaran' and column_name='kp';
