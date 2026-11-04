-- =====================================================================
-- BH 002: Storan gambar profil pengendali (bucket bh-foto)
-- Jalankan SEKALI dalam Supabase > SQL Editor > New query > Run.
-- Selamat dijalankan semula (tiada data dipadam).
-- =====================================================================

-- 1) Bucket awam untuk gambar profil sahaja (maksimum 2MB, jenis gambar sahaja)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bh-foto', 'bh-foto', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2) Hanya staf badal haji (jadual bh_staff) boleh muat naik / tukar / buang gambar
drop policy if exists bh_foto_staf_tambah on storage.objects;
create policy bh_foto_staf_tambah on storage.objects
  for insert to authenticated
  with check (bucket_id = 'bh-foto' and public.bh_is_staff());

drop policy if exists bh_foto_staf_ubah on storage.objects;
create policy bh_foto_staf_ubah on storage.objects
  for update to authenticated
  using (bucket_id = 'bh-foto' and public.bh_is_staff())
  with check (bucket_id = 'bh-foto' and public.bh_is_staff());

drop policy if exists bh_foto_staf_buang on storage.objects;
create policy bh_foto_staf_buang on storage.objects
  for delete to authenticated
  using (bucket_id = 'bh-foto' and public.bh_is_staff());

-- Semakan: patut keluar satu baris bh-foto | true
select id, public from storage.buckets where id = 'bh-foto';
