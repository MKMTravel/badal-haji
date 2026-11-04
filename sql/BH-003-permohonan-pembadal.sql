-- =====================================================================
-- BH-003: Permohonan menjadi pengendali (pembadal) badal haji
-- Jalankan sekali dalam Supabase > SQL Editor > New query > Run
-- Selamat dijalankan semula (guna IF NOT EXISTS / DROP POLICY IF EXISTS)
-- =====================================================================

-- 1) Jadual permohonan
create table if not exists public.bh_permohonan_pembadal (
  id               uuid primary key default gen_random_uuid(),
  ref              text not null unique,
  created_at       timestamptz not null default now(),
  status           text not null default 'Baru'
                   check (status in ('Baru','Dalam semakan','Diluluskan','Ditolak')),
  -- A. Maklumat peribadi
  nama             text not null,
  jantina          text,
  no_id            text,
  tarikh_lahir     date,
  warganegara      text,
  telefon          text not null,
  emel             text,
  alamat           text,
  -- B. Kelayakan
  haji             text not null,
  menetap          text,
  status_diri      text,
  kelulusan        text,
  institusi        text,
  pengalaman_musim integer,
  pengalaman       text,
  bahasa           text,
  -- C. Dokumen (laluan dalam bucket bh-permohonan)
  gambar_path      text,
  dok_id_path      text,
  dok_iqamah_path  text,
  dok_sijil_path   text,
  -- D. Rujukan & pengakuan
  rujukan_nama     text,
  rujukan_telefon  text,
  rujukan_hubungan text,
  setuju           boolean not null default false,
  -- Kegunaan admin
  catatan_admin    text,
  tarikh_semakan   timestamptz,
  disemak_oleh     uuid
);

create index if not exists bh_permohonan_pembadal_status_idx
  on public.bh_permohonan_pembadal (status, created_at desc);

alter table public.bh_permohonan_pembadal enable row level security;

grant insert on public.bh_permohonan_pembadal to anon, authenticated;
grant select, update, delete on public.bh_permohonan_pembadal to authenticated;

-- Orang awam hanya boleh MENGHANTAR permohonan baharu (tidak boleh membaca atau mengubah)
drop policy if exists bh_pp_awam_hantar on public.bh_permohonan_pembadal;
create policy bh_pp_awam_hantar on public.bh_permohonan_pembadal
  for insert to anon, authenticated
  with check (
    status = 'Baru'
    and setuju = true
    and catatan_admin is null and tarikh_semakan is null and disemak_oleh is null
    and char_length(nama) between 3 and 150
    and char_length(telefon) between 8 and 20
    and char_length(haji) between 2 and 60
    and char_length(coalesce(pengalaman,'')) <= 2000
    and char_length(coalesce(alamat,'')) <= 500
  );

-- Staf MKM sahaja boleh membaca, mengemas kini dan memadam
drop policy if exists bh_pp_staf_baca on public.bh_permohonan_pembadal;
create policy bh_pp_staf_baca on public.bh_permohonan_pembadal
  for select to authenticated using (public.bh_is_staff());

drop policy if exists bh_pp_staf_ubah on public.bh_permohonan_pembadal;
create policy bh_pp_staf_ubah on public.bh_permohonan_pembadal
  for update to authenticated using (public.bh_is_staff()) with check (public.bh_is_staff());

drop policy if exists bh_pp_staf_buang on public.bh_permohonan_pembadal;
create policy bh_pp_staf_buang on public.bh_permohonan_pembadal
  for delete to authenticated using (public.bh_is_staff());

-- 2) Storan dokumen permohonan (PERIBADI, bukan awam)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bh-permohonan', 'bh-permohonan', false, 5242880,
        array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Orang awam hanya boleh MUAT NAIK ke folder permohonan/ (tidak boleh melihat atau memadam)
drop policy if exists bh_pp_fail_awam_naik on storage.objects;
create policy bh_pp_fail_awam_naik on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'bh-permohonan' and (storage.foldername(name))[1] = 'permohonan');

-- Staf boleh melihat dan memadam dokumen permohonan
drop policy if exists bh_pp_fail_staf_baca on storage.objects;
create policy bh_pp_fail_staf_baca on storage.objects
  for select to authenticated using (bucket_id = 'bh-permohonan' and public.bh_is_staff());

drop policy if exists bh_pp_fail_staf_buang on storage.objects;
create policy bh_pp_fail_staf_buang on storage.objects
  for delete to authenticated using (bucket_id = 'bh-permohonan' and public.bh_is_staff());

-- 3) Notifikasi masa nyata untuk admin (abaikan ralat jika sudah ditambah)
do $$ begin
  alter publication supabase_realtime add table public.bh_permohonan_pembadal;
exception when others then null; end $$;
