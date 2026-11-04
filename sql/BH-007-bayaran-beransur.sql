-- =====================================================================
-- BH-007: Bayaran beransur (ansuran) + rekod setiap bayaran
-- Jalankan dalam Supabase > SQL Editor. Selamat dijalankan semula.
-- status_bayaran pendaftaran: Belum Bayar | Sebahagian | Berjaya (penuh, disahkan)
-- =====================================================================

-- 1) Jadual rekod bayaran (satu baris setiap resit / bayaran)
create table if not exists public.bh_bayaran (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  ref text not null references public.bh_pendaftaran(ref) on delete cascade,
  amaun numeric(10,2) not null check (amaun > 0),
  bank text default '',
  tarikh date,
  resit_path text default '',
  nota text default '',
  sumber text not null default 'pendaftar',      -- pendaftar | admin
  status text not null default 'Menunggu',       -- Menunggu | Disahkan | Bermasalah
  catatan_semakan text default '',
  disemak_oleh uuid,
  tarikh_semakan timestamptz,
  dicipta_oleh uuid
);
create index if not exists bh_idx_bayaran_ref on public.bh_bayaran (ref);
alter table public.bh_bayaran enable row level security;
drop policy if exists bh_bayaran_staf_baca on public.bh_bayaran;
create policy bh_bayaran_staf_baca on public.bh_bayaran for select to authenticated using (public.bh_is_staff());
grant select on public.bh_bayaran to authenticated;

-- realtime untuk notifikasi admin
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'bh_bayaran') then
    alter publication supabase_realtime add table public.bh_bayaran;
  end if;
end $$;

-- 2) Kira semula jumlah & status pendaftaran daripada rekod bayaran
create or replace function public.bh_kira_bayaran(p_ref text) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; sah numeric := 0; tunggu numeric := 0; penuh boolean; last_sah record;
begin
  select * into r from public.bh_pendaftaran where ref = p_ref;
  if not found then return json_build_object('ok', false, 'error', 'Rujukan tidak dijumpai'); end if;
  select coalesce(sum(amaun),0) into sah from public.bh_bayaran where ref = p_ref and status = 'Disahkan';
  select coalesce(sum(amaun),0) into tunggu from public.bh_bayaran where ref = p_ref and status = 'Menunggu';
  penuh := sah + 0.009 >= coalesce(r.harga, 0) and coalesce(r.harga,0) > 0;
  select bank, tarikh, resit_path into last_sah from public.bh_bayaran where ref = p_ref and status = 'Disahkan' order by tarikh desc nulls last, id desc limit 1;

  update public.bh_pendaftaran set
    amaun_dibayar = sah,
    status_bayaran = case when penuh then 'Berjaya' when sah > 0 then 'Sebahagian' else 'Belum Bayar' end,
    bank = case when sah > 0 then 'Transfer: ' || coalesce(last_sah.bank, '') else bank end,
    transaction_id = case when sah > 0 then 'RESIT' else transaction_id end,
    tarikh_bayar = case when sah > 0 then coalesce(last_sah.tarikh::timestamptz, tarikh_bayar, now()) else tarikh_bayar end,
    semakan = case when penuh then 'Disahkan' when pembadal_id is not null then semakan else '' end,
    tarikh_semakan = case when penuh and semakan <> 'Disahkan' then now() else tarikh_semakan end,
    status = case
      when pembadal_id is not null then status
      when penuh then 'Bayaran Disahkan'
      when tunggu > 0 then 'Menunggu Semakan Bayaran'
      when sah > 0 then 'Ansuran'
      else 'Menunggu Bayaran' end
  where ref = p_ref;

  return json_build_object('ok', true, 'ref', p_ref, 'harga', r.harga, 'dibayar', sah, 'menunggu', tunggu,
    'baki', greatest(coalesce(r.harga,0) - sah, 0), 'penuh', penuh);
end $$;
revoke all on function public.bh_kira_bayaran(text) from public, anon, authenticated;

-- 3) Pendaftar hantar resit (dengan amaun). Ganti versi lama 6 parameter.
drop function if exists public.bh_hantar_resit(text, text, text, text, date, text);
create or replace function public.bh_hantar_resit(
  p_ref text, p_telefon text, p_path text, p_bank text, p_tarikh date, p_nota text, p_amaun numeric
) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; d1 text; d2 text; k json;
begin
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'No. rujukan tidak dijumpai'); end if;
  d1 := right(regexp_replace(coalesce(r.telefon,''), '\D', '', 'g'), 9);
  d2 := right(regexp_replace(coalesce(p_telefon,''), '\D', '', 'g'), 9);
  if d1 = '' or d1 <> d2 then return json_build_object('ok', false, 'error', 'No. telefon tidak sepadan dengan pendaftaran'); end if;
  if r.status_bayaran = 'Berjaya' then
    return json_build_object('ok', false, 'error', 'Bayaran bagi pendaftaran ini telah penuh dan disahkan');
  end if;
  if p_path is null or p_path !~ ('^resit/' || r.ref || '/') then
    return json_build_object('ok', false, 'error', 'Fail resit tidak sah');
  end if;
  if p_amaun is null or p_amaun <= 0 or p_amaun > coalesce(r.harga,0) * 1.5 then
    return json_build_object('ok', false, 'error', 'Jumlah bayaran tidak sah');
  end if;
  insert into public.bh_bayaran (ref, amaun, bank, tarikh, resit_path, nota, sumber, status)
  values (r.ref, round(p_amaun, 2), left(coalesce(p_bank,''), 80), p_tarikh, p_path, left(coalesce(p_nota,''), 500), 'pendaftar', 'Menunggu');
  update public.bh_pendaftaran set
    resit_path = p_path, resit_bank = left(coalesce(p_bank,''), 80), resit_tarikh = p_tarikh,
    resit_nota = left(coalesce(p_nota,''), 500), resit_masa = now()
  where ref = r.ref;
  k := public.bh_kira_bayaran(r.ref);
  return k;
end $$;
revoke all on function public.bh_hantar_resit(text,text,text,text,date,text,numeric) from public;
grant execute on function public.bh_hantar_resit(text,text,text,text,date,text,numeric) to anon, authenticated;

-- 4) Pendaftar semak status bayaran (rujukan + telefon). Pautan portal diberi bila bayaran penuh & disahkan.
create or replace function public.bh_status_bayaran(p_ref text, p_telefon text) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; d1 text; d2 text; sah numeric; tunggu numeric; purl text; u text; senarai json;
begin
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'No. rujukan tidak dijumpai'); end if;
  d1 := right(regexp_replace(coalesce(r.telefon,''), '\D', '', 'g'), 9);
  d2 := right(regexp_replace(coalesce(p_telefon,''), '\D', '', 'g'), 9);
  if d1 = '' or d1 <> d2 then return json_build_object('ok', false, 'error', 'No. telefon tidak sepadan dengan pendaftaran'); end if;
  select coalesce(sum(amaun),0) into sah from public.bh_bayaran where ref = r.ref and status = 'Disahkan';
  select coalesce(sum(amaun),0) into tunggu from public.bh_bayaran where ref = r.ref and status = 'Menunggu';
  select coalesce(json_agg(json_build_object('amaun', b.amaun, 'tarikh', b.tarikh, 'bank', b.bank, 'status', b.status, 'masa', b.created_at, 'catatan', case when b.status = 'Bermasalah' then b.catatan_semakan else '' end) order by b.id), '[]'::json)
    into senarai from public.bh_bayaran b where b.ref = r.ref;
  select nilai into purl from public.bh_tetapan where kunci = 'portal_url';
  select nama into u from public.bh_pembadal where id = r.pembadal_id;
  return json_build_object('ok', true, 'ref', r.ref, 'nama', r.nama, 'd_nama', r.d_nama, 'harga', r.harga,
    'dibayar', sah, 'menunggu', tunggu, 'baki', greatest(coalesce(r.harga,0) - sah, 0),
    'penuh', r.status_bayaran = 'Berjaya', 'disahkan', r.semakan = 'Disahkan',
    'portal', case when r.status_bayaran = 'Berjaya' and purl is not null and purl <> '' then purl || '?ref=' || r.ref || '&t=' || r.token else '' end,
    'pengendali', coalesce(u, ''), 'senarai', senarai);
end $$;
revoke all on function public.bh_status_bayaran(text,text) from public;
grant execute on function public.bh_status_bayaran(text,text) to anon, authenticated;

-- 5) Admin: sahkan / tanda bermasalah satu bayaran
create or replace function public.bh_sah_bayaran(p_id bigint, p_keputusan text, p_catatan text) returns json
language plpgsql security definer set search_path = public as $$
declare b public.bh_bayaran%rowtype; k json;
begin
  if not public.bh_is_staff() then return json_build_object('ok', false, 'error', 'Tiada kebenaran'); end if;
  select * into b from public.bh_bayaran where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'Rekod bayaran tidak dijumpai'); end if;
  update public.bh_bayaran set
    status = case when p_keputusan = 'Bermasalah' then 'Bermasalah' when p_keputusan = 'Menunggu' then 'Menunggu' else 'Disahkan' end,
    catatan_semakan = left(coalesce(p_catatan,''), 500), disemak_oleh = auth.uid(), tarikh_semakan = now()
  where id = p_id;
  k := public.bh_kira_bayaran(b.ref);
  insert into public.bh_audit_log (user_id, staf, tindakan, ref, butiran) values (auth.uid(), '', 'sah_bayaran', b.ref, json_build_object('id', p_id, 'keputusan', p_keputusan, 'amaun', b.amaun)::jsonb);
  return k;
end $$;
revoke all on function public.bh_sah_bayaran(bigint,text,text) from public, anon;
grant execute on function public.bh_sah_bayaran(bigint,text,text) to authenticated;

-- 6) Admin: rekod bayaran sendiri (resit pilihan). Terus dikira disahkan.
create or replace function public.bh_admin_bayaran(p_ref text, p_amaun numeric, p_bank text, p_tarikh date, p_path text, p_nota text) returns json
language plpgsql security definer set search_path = public as $$
declare r public.bh_pendaftaran%rowtype; k json;
begin
  if not public.bh_is_staff() then return json_build_object('ok', false, 'error', 'Tiada kebenaran'); end if;
  select * into r from public.bh_pendaftaran where ref = upper(trim(p_ref));
  if not found then return json_build_object('ok', false, 'error', 'Rujukan tidak dijumpai'); end if;
  if p_amaun is null or p_amaun <= 0 then return json_build_object('ok', false, 'error', 'Jumlah tidak sah'); end if;
  insert into public.bh_bayaran (ref, amaun, bank, tarikh, resit_path, nota, sumber, status, disemak_oleh, tarikh_semakan, dicipta_oleh)
  values (r.ref, round(p_amaun,2), left(coalesce(p_bank,''),80), p_tarikh, coalesce(p_path,''), left(coalesce(p_nota,''),500), 'admin', 'Disahkan', auth.uid(), now(), auth.uid());
  if coalesce(p_path,'') <> '' then
    update public.bh_pendaftaran set resit_path = p_path, resit_bank = left(coalesce(p_bank,''),80), resit_tarikh = p_tarikh, resit_masa = now() where ref = r.ref;
  end if;
  k := public.bh_kira_bayaran(r.ref);
  insert into public.bh_audit_log (user_id, staf, tindakan, ref, butiran) values (auth.uid(), '', 'admin_bayaran', r.ref, json_build_object('amaun', p_amaun, 'bank', p_bank)::jsonb);
  return k;
end $$;
revoke all on function public.bh_admin_bayaran(text,numeric,text,date,text,text) from public, anon;
grant execute on function public.bh_admin_bayaran(text,numeric,text,date,text,text) to authenticated;

-- 7) Admin: padam rekod bayaran (kesilapan)
create or replace function public.bh_padam_bayaran(p_id bigint) returns json
language plpgsql security definer set search_path = public as $$
declare b public.bh_bayaran%rowtype;
begin
  if not public.bh_is_staff() then return json_build_object('ok', false, 'error', 'Tiada kebenaran'); end if;
  select * into b from public.bh_bayaran where id = p_id;
  if not found then return json_build_object('ok', false, 'error', 'Rekod tidak dijumpai'); end if;
  delete from public.bh_bayaran where id = p_id;
  insert into public.bh_audit_log (user_id, staf, tindakan, ref, butiran) values (auth.uid(), '', 'padam_bayaran', b.ref, json_build_object('id', p_id, 'amaun', b.amaun)::jsonb);
  return public.bh_kira_bayaran(b.ref);
end $$;
revoke all on function public.bh_padam_bayaran(bigint) from public, anon;
grant execute on function public.bh_padam_bayaran(bigint) to authenticated;

-- 8) Semak
select routine_name from information_schema.routines where routine_schema = 'public' and routine_name like 'bh_%bayaran%' order by 1;
