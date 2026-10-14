/* =========================================================
   Pop-up "Pasang app" untuk portal Badal Haji MKM
   Guna: <script src="install.js" data-app="pembadal|pendaftar|admin" data-offset="0" defer></script>
   - Android/Chrome: butang Pasang terus (beforeinstallprompt)
   - iPhone/iPad: arahan Kongsi > Tambah ke Skrin Utama
   - Tidak dipaparkan jika sudah dipasang / dibuka sebagai app
   - "Nanti" menyembunyikan pop-up selama 3 hari
   ========================================================= */
(function(){
  const me = document.currentScript;
  const APP = (me && me.dataset.app) || "pendaftar";
  const OFFSET = Number((me && me.dataset.offset) || 0);
  const KEY = "bh_install_later_" + APP;
  const DAYS = 3;

  if("serviceWorker" in navigator){
    window.addEventListener("load", () => { navigator.serviceWorker.register("sw.js", { scope: "./" }).catch(() => {}); });
  }

  const standalone = () => window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;
  if(standalone()) return;
  const ua = navigator.userAgent || "";
  const isIOS = /iphone|ipad|ipod/i.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isAndroid = /android/i.test(ua);
  const isIPad = /ipad/i.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  const isMacSafari = !isIOS && /Macintosh/i.test(ua) && /Safari/i.test(ua) && !/Chrome|Chromium|Edg|OPR|Firefox/i.test(ua);
  const inApp = /FBAN|FBAV|Instagram|WhatsApp|Line\/|; wv\)/i.test(ua);
  const snoozed = () => { try{ return Date.now() < Number(localStorage.getItem(KEY) || 0); }catch(e){ return false; } };
  const snooze = () => { try{ localStorage.setItem(KEY, String(Date.now() + DAYS * 864e5)); }catch(e){} };

  const T = {
    ms: {
      title: { pembadal: "Pasang Portal Pembadal", pendaftar: "Pasang Portal Pendaftar", admin: "Pasang Admin Badal Haji" },
      sub: "Buka terus dari skrin utama dengan satu sentuhan, tanpa perlu cari pautan lagi.",
      install: "Pasang", later: "Nanti", ok: "Faham",
      ios: 'Tekan butang <b>Kongsi</b> <span class="bhi-share" aria-hidden="true"></span> __POS__, kemudian pilih <b>Tambah ke Skrin Utama</b> (Add to Home Screen).',
      iosApp: 'Dibuka dari WhatsApp? Tekan ikon <b>Safari</b> atau <b>Buka dalam Safari</b> dahulu, kemudian tekan <b>Kongsi</b> <span class="bhi-share" aria-hidden="true"></span> dan pilih <b>Tambah ke Skrin Utama</b>.',
      android: 'Tekan <b>&#8942;</b> di penjuru kanan atas, kemudian pilih <b>Tambah ke skrin utama</b> atau <b>Install app</b>.',
      androidApp: 'Dibuka dari WhatsApp? Tekan <b>&#8942;</b> dan pilih <b>Buka dalam Chrome</b> dahulu, kemudian <b>&#8942;</b> &gt; <b>Tambah ke skrin utama</b>.',
      mac: 'Dalam Safari, pilih menu <b>Fail</b> (File) &gt; <b>Tambah ke Dock</b> (Add to Dock), atau tekan <b>Kongsi</b> <span class="bhi-share" aria-hidden="true"></span> &gt; <b>Tambah ke Dock</b>.',
      posPhone: "di bawah skrin", posPad: "di atas sebelah kanan",
      done: "App berjaya dipasang. Buka dari skrin utama."
    },
    en: {
      title: { pembadal: "Install Pembadal Portal", pendaftar: "Install Registrant Portal", admin: "Install Badal Haji Admin" },
      sub: "Open it straight from your home screen with one tap, no need to look for the link again.",
      install: "Install", later: "Later", ok: "Got it",
      ios: 'Tap <b>Share</b> <span class="bhi-share" aria-hidden="true"></span> __POS__, then choose <b>Add to Home Screen</b>.',
      iosApp: 'Opened from WhatsApp? Tap the <b>Safari</b> icon or <b>Open in Safari</b> first, then tap <b>Share</b> <span class="bhi-share" aria-hidden="true"></span> and choose <b>Add to Home Screen</b>.',
      android: 'Tap <b>&#8942;</b> at the top right, then choose <b>Add to Home screen</b> or <b>Install app</b>.',
      androidApp: 'Opened from WhatsApp? Tap <b>&#8942;</b> and choose <b>Open in Chrome</b> first, then <b>&#8942;</b> &gt; <b>Add to Home screen</b>.',
      mac: 'In Safari, choose <b>File</b> &gt; <b>Add to Dock</b>, or tap <b>Share</b> <span class="bhi-share" aria-hidden="true"></span> &gt; <b>Add to Dock</b>.',
      posPhone: "at the bottom of the screen", posPad: "at the top right",
      done: "App installed. Open it from your home screen."
    }
  };
  const L = () => (document.documentElement.lang || "ms").slice(0, 2) === "en" ? T.en : T.ms;

  const css = `
.bhi{position:fixed;left:12px;right:12px;bottom:calc(${12 + OFFSET}px + env(safe-area-inset-bottom,0px));z-index:55;max-width:460px;margin:0 auto;background:#fff;color:#1A1F3C;border-radius:18px;box-shadow:0 18px 50px rgba(10,19,64,.28),0 0 0 1px rgba(18,32,107,.08);padding:16px;font:14px/1.5 "Plus Jakarta Sans",system-ui,sans-serif;transform:translateY(140%);opacity:0;transition:transform .35s cubic-bezier(.2,.8,.2,1),opacity .35s}
.bhi.show{transform:none;opacity:1}
.bhi-h{display:flex;gap:12px;align-items:center}
.bhi-h img{width:52px;height:52px;border-radius:13px;flex:none;box-shadow:0 2px 8px rgba(18,32,107,.25)}
.bhi-h b{display:block;font-size:15.5px;color:#12206B;line-height:1.3}
.bhi-h small{display:block;font-size:12.5px;color:#5E6584;margin-top:2px;line-height:1.4}
.bhi-x{margin-left:auto;align-self:flex-start;border:0;background:#EEF0F6;color:#5E6584;width:30px;height:30px;border-radius:50%;font-size:18px;line-height:1;cursor:pointer;flex:none}
.bhi-steps{margin:12px 0 0;background:#F3F5FB;border-radius:12px;padding:11px 13px;font-size:13.5px;color:#2A3055}
.bhi-steps b{color:#12206B}
.bhi-a{display:flex;gap:8px;margin-top:12px}
.bhi-a button{flex:1;height:44px;border-radius:12px;font-weight:700;font-size:14.5px;cursor:pointer;border:0;font-family:inherit}
.bhi-a .p{background:#12206B;color:#fff}
.bhi-a .g{background:#EEF0F6;color:#12206B}
.bhi-share{display:inline-block;width:15px;height:18px;vertical-align:-3px;background:no-repeat center/contain url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 28' fill='none' stroke='%231E32C8' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 2v15M7 7l5-5 5 5'/%3E%3Cpath d='M8 11H5a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V13a2 2 0 0 0-2-2h-3'/%3E%3C/svg%3E")}
.bhi-arrow{position:fixed;left:50%;bottom:calc(4px + env(safe-area-inset-bottom,0px));transform:translateX(-50%);z-index:56;width:0;height:0;border-left:10px solid transparent;border-right:10px solid transparent;border-top:12px solid #fff;filter:drop-shadow(0 4px 4px rgba(10,19,64,.2));display:none}
@media (min-width:900px){.bhi{left:auto;right:24px;bottom:24px;width:400px;max-width:none}}
@media (prefers-reduced-motion:reduce){.bhi{transition:none}}`;

  let deferred = null, box = null, mode = "";
  function mount(){
    if(box) return box;
    const st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
    box = document.createElement("div"); box.className = "bhi"; box.setAttribute("role", "dialog"); box.setAttribute("aria-live", "polite");
    document.body.appendChild(box);
    return box;
  }
  function render(){
    const t = L();
    const steps = (mode === "ios" ? (inApp ? t.iosApp : t.ios) : mode === "android" ? (inApp ? t.androidApp : t.android) : mode === "mac" ? t.mac : "").replace("__POS__", isIPad || /CriOS|EdgiOS|FxiOS/i.test(ua) ? t.posPad : t.posPhone);
    box.innerHTML = `<div class="bhi-h"><img src="icons/${APP}/icon-192.png" alt=""><div><b>${t.title[APP] || t.title.pendaftar}</b><small>${t.sub}</small></div><button class="bhi-x" type="button" aria-label="Tutup">&times;</button></div>
      ${steps ? `<div class="bhi-steps">${steps}</div>` : ""}
      <div class="bhi-a">${mode === "prompt" ? `<button class="g" type="button" data-a="later">${t.later}</button><button class="p" type="button" data-a="install">${t.install}</button>` : `<button class="p" type="button" data-a="later">${t.ok}</button>`}</div>`;
    box.querySelector(".bhi-x").onclick = () => hide(true);
    box.querySelectorAll("[data-a]").forEach(b => b.onclick = () => b.dataset.a === "install" ? doInstall() : hide(true));
  }
  function show(m){
    if(snoozed() || standalone()) return;
    if(document.querySelector(".sheet:not(.hide)")) { setTimeout(() => show(m), 4000); return; }
    mode = m; mount(); render();
    requestAnimationFrame(() => requestAnimationFrame(() => box.classList.add("show")));
  }
  function hide(later){
    if(later) snooze();
    if(box){ box.classList.remove("show"); setTimeout(() => { if(box){ box.remove(); box = null; } }, 400); }
  }
  async function doInstall(){
    if(!deferred){ hide(true); return; }
    deferred.prompt();
    try{ const r = await deferred.userChoice; if(r && r.outcome === "dismissed") snooze(); }catch(e){}
    deferred = null; hide(false);
  }

  window.addEventListener("beforeinstallprompt", e => {
    e.preventDefault(); deferred = e;
    if(box && mode !== "prompt"){ mode = "prompt"; render(); return; }
    setTimeout(() => show("prompt"), 2500);
  });
  window.addEventListener("appinstalled", () => {
    deferred = null; try{ localStorage.setItem(KEY, String(Date.now() + 3650 * 864e5)); }catch(e){}
    if(box){ box.innerHTML = `<div class="bhi-h"><img src="icons/${APP}/icon-192.png" alt=""><div><b>${L().done}</b></div></div>`; setTimeout(() => hide(false), 3500); }
  });
  /* iPhone tiada butang install automatik: tunjuk arahan. Android tanpa prompt (contoh dalam WhatsApp): tunjuk arahan manual. */
  window.addEventListener("load", () => {
    if(isIOS) setTimeout(() => { if(!box) show("ios"); }, 3000);
    else if(isAndroid) setTimeout(() => { if(!box && !deferred) show("android"); }, 6000);
    else if(isMacSafari) setTimeout(() => { if(!box) show("mac"); }, 3000);
    /* Chrome / Edge di komputer & Chromebook: pop-up keluar melalui beforeinstallprompt. Firefox komputer tidak menyokong pemasangan app. */
  });
  /* tukar bahasa portal: kemas kini teks pop-up */
  new MutationObserver(() => { if(box) render(); }).observe(document.documentElement, { attributes: true, attributeFilter: ["lang"] });
  window.BH_INSTALL = { show: () => { try{ localStorage.removeItem(KEY); }catch(e){} show(deferred ? "prompt" : isIOS ? "ios" : isMacSafari ? "mac" : "android"); } };
})();
