/* =====================================================================
   Resit Badal Haji MKM - simpan resit pindahan bank ke Google Drive
   Deploy: Web app, Execute as Me, Who has access: Anyone
   Borang (index.html) POST JSON: { k, ref, nama, telefon, bank, tarikh, nota, mime, nama_fail, data(base64) }
   Fail disimpan dalam folder "Resit Badal Haji" > "<musim>" > "<REF> - <nama>" dengan nama Resit_<REF>_<nama>_<masa>.<ext>
   ===================================================================== */
const FOLDER_UTAMA = "Resit Badal Haji";
const KUNCI = "bh-resit-2026"; // mesti sama dengan RESIT_DRIVE_KEY dalam index.html

function doPost(e){
  let out = { ok: false };
  try{
    const b = JSON.parse(e.postData.contents || "{}");
    if(b.k !== KUNCI) throw new Error("kunci salah");
    if(!b.ref || !b.data) throw new Error("data tidak lengkap");
    const musim = String(b.musim || "1448H").replace(/[\\/]/g, "-");
    const musimFolder = subFolder(rootFolder(), musim);
    /* satu folder bagi setiap pendaftar: "BH-1448-0001 - Nama" (dicari ikut no. rujukan supaya resit ansuran terkumpul) */
    const namaP = String(b.nama || "").replace(/[\\/:*?"<>|]+/g, " ").trim().slice(0, 40);
    let folder = null; const it0 = musimFolder.getFolders();
    while(it0.hasNext()){ const f0 = it0.next(); if(f0.getName().indexOf(b.ref) === 0){ folder = f0; break; } }
    if(!folder) folder = musimFolder.createFolder(b.ref + (namaP ? " - " + namaP : ""));
    else if(namaP && folder.getName() === b.ref) folder.setName(b.ref + " - " + namaP);
    const ext = b.mime === "application/pdf" ? "pdf" : (b.mime === "image/png" ? "png" : "jpg");
    const nama = String(b.nama || "").replace(/[^\w ]+/g, " ").trim().replace(/\s+/g, "_").slice(0, 30);
    const fname = "Resit_" + b.ref + (nama ? "_" + nama : "") + "_" + Utilities.formatDate(new Date(), "Asia/Kuala_Lumpur", "yyyyMMdd-HHmm") + "." + ext;
    const blob = Utilities.newBlob(Utilities.base64Decode(b.data), b.mime || "image/jpeg", fname);
    const f = folder.createFile(blob);
    f.setDescription(["Rujukan: " + b.ref, "Pendaftar: " + (b.nama || ""), "Telefon: " + (b.telefon || ""), "Bank: " + (b.bank || ""), "Tarikh transfer: " + (b.tarikh || ""), "Catatan: " + (b.nota || "")].join("\n"));
    logRow(musimFolder, [new Date(), b.ref, b.nama || "", b.telefon || "", b.bank || "", b.tarikh || "", b.nota || "", f.getName(), f.getUrl()]);
    out = { ok: true, id: f.getId(), url: f.getUrl() };
  }catch(err){ out = { ok: false, error: String(err && err.message || err) }; }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

function doGet(){ return ContentService.createTextOutput(JSON.stringify({ ok: true, app: "Resit Badal Haji MKM" })).setMimeType(ContentService.MimeType.JSON); }

function rootFolder(){
  const props = PropertiesService.getScriptProperties();
  const id = props.getProperty("FOLDER_ID");
  if(id){ try{ return DriveApp.getFolderById(id); }catch(e){} }
  const it = DriveApp.getFoldersByName(FOLDER_UTAMA);
  const f = it.hasNext() ? it.next() : DriveApp.createFolder(FOLDER_UTAMA);
  props.setProperty("FOLDER_ID", f.getId());
  return f;
}
function subFolder(parent, name){
  const it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}
/* Senarai resit (Google Sheet) dalam folder musim */
function logRow(folder, row){
  try{
    const name = "Senarai Resit";
    const it = folder.getFilesByName(name);
    let ss;
    if(it.hasNext()) ss = SpreadsheetApp.open(it.next());
    else{
      ss = SpreadsheetApp.create(name);
      DriveApp.getFileById(ss.getId()).moveTo(folder);
      ss.getSheets()[0].appendRow(["Masa diterima", "Rujukan", "Pendaftar", "Telefon", "Bank", "Tarikh transfer", "Catatan", "Nama fail", "Pautan Drive"]);
      ss.getSheets()[0].setFrozenRows(1);
    }
    ss.getSheets()[0].appendRow(row);
  }catch(e){}
}

/* Jalankan sekali dalam editor untuk beri kebenaran Drive + cipta folder */
function setup(){
  const f = rootFolder();
  Logger.log("Folder: " + f.getUrl());
  return f.getUrl();
}
