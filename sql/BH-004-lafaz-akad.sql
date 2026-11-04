-- BH-004: Kemas kini lafaz akad (dam -> hadyu)
-- Jalankan dalam Supabase > SQL Editor > New query > Run
update public.bh_tetapan
set nilai = $$Saya serahkan amanah menunaikan haji bagi pihak {nama_dibadalkan} kepada {agensi_pendek} dengan upah {harga}, dan saya wakilkan {agensi_pendek} untuk melantik pembadal dan penyembelihan hadyu bagi pihak beliau.$$
where kunci = 'akad_lafaz';

-- Semak hasil (patut keluar satu baris dengan perkataan "hadyu")
select kunci, nilai from public.bh_tetapan where kunci = 'akad_lafaz';
