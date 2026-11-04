-- =====================================================================
-- BH-006: Kosongkan semua data ujian sebelum guna sebenar
-- Tidak menyentuh: bh_tetapan, bh_akad_poin, bh_staff
-- =====================================================================
begin;

delete from public.bh_checkin;
delete from public.bh_pendaftaran;
delete from public.bh_permohonan_pembadal;
delete from public.bh_pembadal;
delete from public.bh_log_bayaran;
delete from public.bh_audit_log;

-- Nombor rujukan bermula semula dari 0001
delete from public.bh_counters;

-- Fail ujian dalam storan
delete from storage.objects where bucket_id in ('bh-dokumen','bh-bukti','bh-foto','bh-permohonan','bh-resit');

commit;

select 'bh_pendaftaran' j, count(*) n from public.bh_pendaftaran
union all select 'bh_checkin', count(*) from public.bh_checkin
union all select 'bh_pembadal', count(*) from public.bh_pembadal
union all select 'bh_permohonan_pembadal', count(*) from public.bh_permohonan_pembadal
union all select 'bh_counters', count(*) from public.bh_counters
union all select 'storage bh-*', count(*) from storage.objects where bucket_id like 'bh-%';
