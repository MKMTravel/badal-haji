-- =====================================================================
-- BH-005: Bayaran secara transfer bank + muat naik resit (ganti BCL)
-- Jalankan dalam Supabase > SQL Editor > New query > Run
-- Selamat dijalankan semula.
-- =====================================================================

-- 1) Lajur resit pada pendaftaran
alter table public.bh_pendaftaran add column if not exists resit_path   text default '';
alter table public.bh_pendaftaran add column if not exists resit_bank   text default '';
alter table public.bh_pendaftaran add column if not exists resit_tarikh date;
alter table public.bh_pendaftaran add column if not exists resit_nota   text default '';
alter table public.bh_pendaftaran add column if not exists resit_masa   timestamptz;

-- 2) Tetapan akaun bank (rujukan; borang juga memaparkan maklumat ini)
insert into public.bh_tetapan (kunci, nilai, keterangan) values
  ('kaedah_bayaran', 'transfer', 'transfer = pindahan bank + resit, bcl = borang BCL'),
  ('bank_1', 'RHB Islamic Bank Berhad|26231700021373|MKM Ticketing Travel & Tours Sdn Bhd', 'Nama bank|No. akaun|Nama akaun'),
  ('bank_2', 'CIMB Bank|8602108663|MKM Ticketing Travel & Tours Sdn Bhd', 'Nama bank|No. akaun|Nama akaun')
on conflict (kunci) do update set nilai = excluded.nilai, keterangan = excluded.keterangan;

-- 3) Storan resit (peribadi)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bh-resit', 'bh-resit', false, 10485760, array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists bh_resit_awam_naik on storage.objects;
create policy bh_resit_awam_naik on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'bh-resit' and (storage.foldername(name))[1] = 'resit');

drop policy if exists bh_resit_staf_baca on storage.objects;
create policy bh_resit_staf_baca on storage.objects
  for select to authenticated using (bucket_id = 'bh-resit' and public.bh_is_staff());

drop policy if exists bh_resit_staf_buang on storage.objects;
create policy bh_resit_staf_buang on storage.objects
  for delete to authenticated using (bucket_id = 'bh-resit' and public.bh_is_staff());

-- 4) Fungsi: pendaftar hantar resit (disahkan dengan no. rujukan + no. telefon pendaftaran)
create or replace function public.bh_hantar_resit(
  p_ref text, p_telefon text, p_path text, p_bank text, p_tarikh date, p_nota text
) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; d1 text; d2 text;
begin
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'No. rujukan tidak dijumpai'); end if;
  d1 := right(regexp_replace(coalesce(r.telefon,''), '\D', '', 'g'), 9);
  d2 := right(regexp_replace(coalesce(p_telefon,''), '\D', '', 'g'), 9);
  if d1 = '' or d1 <> d2 then return json_build_object('ok', false, 'error', 'No. telefon tidak sepadan dengan pendaftaran'); end if;
  if r.semakan = 'Disahkan' or r.pembadal_id is not null then
    return json_build_object('ok', false, 'error', 'Bayaran bagi pendaftaran ini telah disahkan');
  end if;
  if p_path is null or p_path !~ ('^resit/' || r.ref || '/') then
    return json_build_object('ok', false, 'error', 'Fail resit tidak sah');
  end if;
  update public.bh_pendaftaran set
    resit_path = p_path, resit_bank = left(coalesce(p_bank,''), 80), resit_tarikh = p_tarikh,
    resit_nota = left(coalesce(p_nota,''), 500), resit_masa = now(),
    status_bayaran = 'Berjaya', bank = 'Transfer: ' || left(coalesce(p_bank,''), 60),
    transaction_id = 'RESIT', amaun_dibayar = harga,
    tarikh_bayar = coalesce(p_tarikh::timestamptz, now()),
    semakan = '', catatan_semakan = '', status = 'Menunggu Semakan Bayaran'
  where ref = r.ref;
  return json_build_object('ok', true, 'ref', r.ref);
end $$;

revoke all on function public.bh_hantar_resit(text,text,text,text,date,text) from public;
grant execute on function public.bh_hantar_resit(text,text,text,text,date,text) to anon, authenticated;

-- 5) Semak: ruangan yang dijangka
select column_name from information_schema.columns
where table_name = 'bh_pendaftaran' and column_name like 'resit_%';
