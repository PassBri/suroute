/* Fogatas en vivo: una transmisión con intención. Quien la enciende dice el tema y el eje; quienes miran
   reaccionan con las luces (suben por la pantalla, para todos) y, al salir, escriben qué se llevan para
   su paso de mañana. El video viaja por LiveKit (se carga solo al abrir una fogata); el permiso lo da la
   función «fogata» de Supabase. La capa vive fuera de #detalle, así los repintados no cortan el video. */
(function () {
  const LK_URL = "https://cdn.jsdelivr.net/npm/livekit-client@2.22.4/dist/livekit-client.umd.js";
  const P = {
    cam: "M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z",
    camNo: "M21 6.5l-4 4V7c0-.55-.45-1-1-1H9.82L21 17.18V6.5zM3.27 2L2 3.27 4.73 6H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.21 0 .39-.08.54-.18L19.73 21 21 19.73 3.27 2z",
    micNo: "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z",
  };
  const svgP = (d, cls = "i") => `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true"><path d="${d}"/></svg>`;
  const FOG = { vivas: null, cargando: false, puede: null, room: null, f: null, anfitrion: false, demo: false, luces: 0, inicio: 0, latido: null, simula: null, vista: null, mic: true, cam: true, frente: true };
  window.FOG = FOG;

  const ini = n => (n || "?").split(" ").map(x => x[0]).join("").slice(0, 2).toUpperCase();
  const cara = (f, cls = "") => f.avatar ? `<span class="avatar ${cls}" style="padding:0;overflow:hidden"><img src="${esc(f.avatar)}" alt="" style="width:100%;height:100%;border-radius:50%;object-fit:cover"></span>`
    : `<span class="avatar ${cls}" style="--c:${COLOR_EJE[f.eje] || "var(--burdeos)"}">${esc(ini(f.autor))}</span>`;
  const DEMO = () => [{ id: "demo-fogata", titulo: "Hábitos que se sostienen solos", eje: "VOL", autor: "Brian S.", avatar: "", personas: 23, demo: true, empezo: Date.now() - 14 * 60000 }];

  /* ---------- Las fogatas encendidas ahora ---------- */
  async function cargarVivas() {
    if (FOG.cargando) return; FOG.cargando = true;
    try {
      if (!Store.nube) FOG.vivas = DEMO();
      else {
        const desde = new Date(Date.now() - 3 * 60000).toISOString();
        const { data, error } = await Store.nube.sb.from("fogatas").select("id,titulo,eje,user_id,empezo_at,autor:profiles!fogatas_user_id_fkey(nombre,username,avatar_url)")
          .eq("estado", "EN_VIVO").gte("latido_at", desde).order("empezo_at", { ascending: false }).limit(12);
        if (error) throw error;
        FOG.vivas = (data || []).map(f => ({ id: f.id, titulo: f.titulo, eje: f.eje, autorId: f.user_id, autor: f.autor?.nombre || f.autor?.username || "Senderista", avatar: f.autor?.avatar_url || "", empezo: Date.parse(f.empezo_at) }));
        if (FOG.puede === null) { const { data: p } = await Store.nube.sb.rpc("puede_encender"); FOG.puede = p === true; }
      }
    } catch (e) { console.warn("fogatas", e); FOG.vivas = FOG.vivas || []; }
    finally { FOG.cargando = false; FOG.cargadas = Date.now(); if (estado.sec === "comunidad" && !enEdicion()) pintarDetalle(); }
  }
  window.cargarFogatas = cargarVivas;
  // Se revisa cada minuto mientras se mira Comunidad
  setInterval(() => { if (estado.sec === "comunidad" && !document.hidden && !FOG.room) cargarVivas(); }, 60000);

  const franja = clase => {
    if (!FOG.vivas && Date.now() - (FOG.cargadas || 0) > 5000) setTimeout(cargarVivas, 0);
    const vs = FOG.vivas || []; if (!vs.length) return "";
    return `<div class="fogatas-vivo ${clase}" role="list" aria-label="Fogatas en vivo ahora">${vs.map(f => `<button role="listitem" class="fv-item" data-acc="fogataVer" data-arg="${esc(f.id)}" aria-label="En vivo: ${esc(f.autor)}, ${esc(f.titulo)}">
      <span class="fv-aro">${cara(f)}</span><span class="fv-txt"><span class="fv-vivo">En vivo</span><b>${esc(f.autor.split(" ")[0])}</b><span class="fv-tit">${esc(f.titulo)}</span></span></button>`).join("")}</div>`;
  };
  // En Cimas, debajo de las pestañas; en el muro, arriba de las publicaciones
  const feed = DET["comunidad.feed"];
  DET["comunidad.feed"] = (...a) => {
    const h = feed(...a);
    if (h.includes('class="cimas-cab"')) { const fr = franja("en-cimas"); return fr ? h.replace(/(<span class="cimas-ancla" hidden><\/span><\/div>)/, `$1${fr}`).replace('class="cimas-demo"', 'class="cimas-demo con-fogata"') : h; }
    const fr = franja("en-muro"); return fr ? h.replace(/(<div class="ancho"[^>]*>)/, `$1${fr}`) : h;
  };

  /* ---------- Entrada en Publicar ---------- */
  const pub = DET["comunidad.publicar"];
  DET["comunidad.publicar"] = (...a) => {
    if (Store.nube && FOG.puede === null) setTimeout(cargarVivas, 0);
    const tarjeta = `<button class="fogata-entrada" data-acc="fogataEncender">
      <span class="fe-luz">${window.luzSVG ? luzSVG("fogata", "") : ""}</span>
      <span class="fe-txt"><b>Encender una fogata en vivo</b><span>Habla con tu comunidad sobre un paso de tu ascenso. Al final, cada quien se lleva algo para su paso de mañana.</span></span>
      ${svgP("M10 6 8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z", "i fe-ir")}</button>`;
    return pub(...a).replace(/(<div class="ancho"[^>]*>)/, `$1${tarjeta}`);
  };

  /* ---------- LiveKit, solo cuando hace falta ---------- */
  let lkPromesa = null;
  const cargarLK = () => window.LivekitClient ? Promise.resolve(window.LivekitClient) : (lkPromesa ||= new Promise((ok, mal) => {
    const s = document.createElement("script"); s.src = LK_URL; s.async = true;
    s.onload = () => ok(window.LivekitClient); s.onerror = () => { lkPromesa = null; mal(new Error("No se pudo cargar el video en vivo.")); };
    document.head.append(s);
  }));
  async function pedir(cuerpo) {
    const { data, error } = await Store.nube.sb.functions.invoke("fogata", { body: cuerpo });
    if (error) { let m = ""; try { m = (await error.context?.json())?.error; } catch {} throw new Error(m || "No se pudo conectar con la fogata."); }
    if (data?.error) throw new Error(data.error);
    return data;
  }

  /* ---------- La capa a pantalla completa ---------- */
  function capa() {
    let c = document.getElementById("fogataCapa");
    if (!c) {
      c = document.createElement("div"); c.id = "fogataCapa"; c.className = "fogata-capa"; c.setAttribute("role", "dialog"); c.setAttribute("aria-modal", "true");
      document.body.append(c);
      c.addEventListener("click", e => { const b = e.target.closest("[data-fog]"); if (b) ACCF[b.dataset.fog]?.(b, b.dataset.arg || ""); });
      c.addEventListener("keydown", e => { if (e.key === "Escape") ACCF.salir(); });
      document.documentElement.classList.add("con-fogata");
    }
    return c;
  }
  function quitarCapa() {
    clearInterval(FOG.latido); clearInterval(FOG.simula); FOG.latido = FOG.simula = null;
    FOG.preview?.getTracks().forEach(t => t.stop()); FOG.preview = null;
    document.getElementById("fogataCapa")?.remove(); document.documentElement.classList.remove("con-fogata");
  }
  const fondoArte = id => `<div class="fg-arte">${window.Arte ? Arte.cordillera("fogata-" + id, 3, { bandera: false }) : ""}</div>`;
  const filaLuces = () => `<div class="fg-luces" role="group" aria-label="Dar una luz">${(window.LUCES || []).map(l =>
    `<button data-fog="luz" data-arg="${l.id}" aria-label="${esc(l.nombre)}">${luzSVG(l.id, "quieta")}<span>${esc(l.nombre)}</span></button>`).join("")}</div>`;

  /* Encender: vista previa de la cámara, el tema y el eje */
  ACC.fogataEncender = async () => {
    // Se pregunta cada vez que se abre: si te acaban de dar permiso (moderador o coach verificado), ya cuenta
    if (Store.nube) { try { const { data, error } = await Store.nube.sb.rpc("puede_encender"); if (error) throw error; FOG.puede = data === true; } catch (e) { console.warn("puede_encender", e); FOG.puede = false; } }
    const puede = !Store.nube || FOG.puede;
    const c = capa(); FOG.vista = "encender";
    const ejes = [["", "Sin eje"], ...EJES.map(([k, n]) => [k, n])];
    c.innerHTML = `<div class="fg-escena">${fondoArte("previa")}<video class="fg-video espejo" id="fgPrevia" autoplay playsinline muted></video></div>
      <div class="fg-arriba"><button class="fg-ic" data-fog="salir" aria-label="Cerrar">${ic("cerrar")}</button></div>
      <form class="fg-hoja" id="fgForm" onsubmit="return false">
        <h2>Encender una fogata</h2>
        <p class="suave">Di de qué hablarás. Tu comunidad reaccionará con luces y, al final, cada persona escribirá qué se lleva para su paso de mañana.</p>
        <label class="campo"><span>¿De qué hablarás?</span><input name="titulo" maxlength="90" required placeholder="Ej.: Cómo vuelvo a la ruta después de una caída" autocomplete="off"></label>
        <div class="fg-ejes" role="radiogroup" aria-label="Eje">${ejes.map(([k, n], i) => `<button type="button" role="radio" aria-checked="${i === 0}" data-fog="eje" data-arg="${k}">${esc(n)}</button>`).join("")}</div>
        ${puede ? "" : `<p class="fg-nota">${ic("info")} Por ahora encienden fogatas los coaches verificados. Muy pronto podrás encender la tuya.</p>`}
        <div class="botones"><button type="button" class="btn lleno" data-fog="encender" ${puede ? "" : "disabled"}>${window.luzSVG ? luzSVG("fogata", "quieta") : ""} Encender la fogata</button></div>
      </form>`;
    c.querySelector("input")?.focus();
    if (puede) try {
      FOG.preview = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user", width: { ideal: 1280 } }, audio: false });
      const v = document.getElementById("fgPrevia"); if (v) { v.srcObject = FOG.preview; v.classList.add("lista"); }
    } catch (e) { console.warn(e); }
  };

  /* Ver una fogata (como público) */
  ACC.fogataVer = async (el, id) => {
    const f = (FOG.vivas || []).find(x => String(x.id) === String(id)); if (!f) return;
    FOG.f = f; FOG.anfitrion = false; FOG.demo = !!f.demo; FOG.luces = 0; FOG.inicio = f.empezo || Date.now();
    pintarVivo();
    if (FOG.demo) { simular(); return; }
    try {
      const d = await pedir({ accion: "entrar", id });
      await conectar(d);
    } catch (e) { toast(e.message); quitarCapa(); FOG.vivas = null; cargarVivas(); }
  };

  function pintarVivo() {
    const f = FOG.f, c = capa(); FOG.vista = "vivo";
    c.innerHTML = `<div class="fg-escena">${fondoArte(f.id)}<video class="fg-video${FOG.anfitrion ? " espejo" : ""}" id="fgVideo" autoplay playsinline ${FOG.anfitrion ? "muted" : ""}></video>
        <p class="fg-espera" id="fgEspera">${FOG.demo ? "Ejemplo: en una fogata real verás y oirás a quien la enciende." : "Avivando la llama…"}</p><div class="fg-suben" id="fgSuben" aria-hidden="true"></div></div>
      <div class="fg-arriba">
        <div class="fg-quien">${cara(f)}<div><b>${esc(f.autor)}</b><span>${esc(f.titulo)}${f.eje ? ` · ${esc(NOMBRE_EJE[f.eje] || "")}` : ""}</span></div></div>
        <span class="fg-vivo">En vivo</span>
        <span class="fg-personas" id="fgPersonas" aria-label="Personas mirando">${ic("ojo")}<b>${f.personas || 1}</b></span>
        <button class="fg-ic" data-fog="salir" aria-label="${FOG.anfitrion ? "Apagar la fogata" : "Salir de la fogata"}">${ic("cerrar")}</button></div>
      <div class="fg-abajo">
        ${filaLuces()}
        <div class="fg-ctrl">${FOG.anfitrion
          ? `<button class="fg-ic" data-fog="mic" aria-pressed="${!FOG.mic}" aria-label="Micrófono">${FOG.mic ? ic("mic") : svgP(P.micNo)}</button>
             <button class="fg-ic" data-fog="cam" aria-pressed="${!FOG.cam}" aria-label="Cámara">${svgP(FOG.cam ? P.cam : P.camNo)}</button>
             <button class="fg-ic" data-fog="girar" aria-label="Cambiar de cámara">${ic("girar")}</button>
             <button class="btn fg-apagar" data-fog="salir">Apagar la fogata</button>`
          : `<span class="fg-total" id="fgTotal" aria-live="polite"></span>
             ${!FOG.demo ? `<button class="fg-ic" data-fog="reportar" aria-label="Reportar esta fogata">${ic("reportar")}</button>` : ""}
             ${!FOG.demo && typeof MOD !== "undefined" && MOD.soy ? `<button class="btn fg-apagar" data-fog="cortar">Cortar</button>` : ""}`}</div></div>`;
  }

  async function conectar(d) {
    const LK = await cargarLK();
    const room = new LK.Room({ adaptiveStream: true, dynacast: true });
    FOG.room = room;
    const ponerVideo = track => { const v = document.getElementById("fgVideo"); if (v && track) { track.attach(v); v.classList.add("lista"); document.getElementById("fgEspera")?.remove(); } };
    room.on(LK.RoomEvent.TrackSubscribed, track => { if (track.kind === "video") ponerVideo(track); else track.attach(); })
      .on(LK.RoomEvent.DataReceived, (bytes, part) => { try { const m = JSON.parse(new TextDecoder().decode(bytes)); if (m.t === "luz") subirLuz(m.k, part?.name); } catch {} })
      .on(LK.RoomEvent.ParticipantConnected, contar).on(LK.RoomEvent.ParticipantDisconnected, contar)
      .on(LK.RoomEvent.Disconnected, () => { if (FOG.room === room) terminar(true); });
    await room.connect(d.url, d.token);
    contar();
    if (d.anfitrion) {
      await room.localParticipant.enableCameraAndMicrophone();
      const pub = [...room.localParticipant.videoTrackPublications.values()][0];
      ponerVideo(pub?.track);
      FOG.latido = setInterval(() => pedir({ accion: "latido", id: FOG.f.id, personas: room.numParticipants }).catch(() => {}), 60000);
    } else {
      // Si quien transmite ya estaba, sus pistas llegan con TrackSubscribed; si aún no hay video, queda la cordillera
      setTimeout(() => { const e = document.getElementById("fgEspera"); if (e && !room.remoteParticipants.size) e.textContent = "Quien encendió la fogata volverá en un momento…"; }, 6000);
    }
  }
  function contar() {
    const n = FOG.room ? FOG.room.numParticipants || FOG.room.remoteParticipants.size + 1 : FOG.f?.personas || 1;
    const b = document.querySelector("#fgPersonas b"); if (b) b.textContent = n;
  }

  /* Las luces suben por la pantalla, para todos */
  function subirLuz(k, quien) {
    const cont = document.getElementById("fgSuben"); if (!cont || !window.luzSVG) return;
    FOG.luces++; const t = document.getElementById("fgTotal"); if (t) t.textContent = `${FOG.luces} ${FOG.luces === 1 ? "luz" : "luces"}`;
    const s = document.createElement("span"); s.className = "fg-sube";
    s.style.setProperty("--x", (Math.random() * 46 - 23).toFixed(0) + "px"); s.style.setProperty("--g", (Math.random() * 16 - 8).toFixed(0) + "deg");
    s.innerHTML = luzSVG(k, "") + (quien ? `<small>${esc(String(quien).split(" ")[0])}</small>` : "");
    cont.append(s); setTimeout(() => s.remove(), 3200);
    while (cont.children.length > 24) cont.firstChild.remove();
  }
  // El ejemplo: luces que llegan solas, para ver cómo se siente
  function simular() {
    const nombres = ["Lucía", "Mateo", "Sofía", "Camilo", "Diana", "Julián"], ids = (window.LUCES || []).map(l => l.id);
    FOG.simula = setInterval(() => { if (Math.random() < 0.7) subirLuz(ids[Math.floor(Math.random() * ids.length)], nombres[Math.floor(Math.random() * nombres.length)]); }, 1400);
  }

  async function terminar(desdeServidor = false) {
    const f = FOG.f, anfitrion = FOG.anfitrion, luces = FOG.luces, minutos = Math.max(1, Math.round((Date.now() - FOG.inicio) / 60000));
    const room = FOG.room; FOG.room = null;
    try { room?.disconnect(); } catch {}
    quitarCapa(); FOG.vista = null;
    FOG.vivas = null; cargarVivas();
    if (!f) return;
    if (anfitrion) return resumen(f, minutos, luces);
    // Al salir: qué me llevo para mi paso de mañana
    abrirHoja(`<div class="hoja-cab"><h3>${desdeServidor ? "La fogata se apagó" : "Antes de irte"}</h3></div>
      <form class="form fg-llevo" data-form="fogataLlevo" data-arg="${esc(f.id)}">
        <p class="suave" style="margin:0">De lo que escuchaste en la fogata de ${esc(f.autor.split(" ")[0])}, ¿qué te llevas para tu paso de mañana?</p>
        <label class="campo"><span>Me llevo…</span><textarea name="texto" maxlength="280" required placeholder="Ej.: dejar la ropa lista la noche anterior"></textarea></label>
        <p class="suave" style="margin:0;font-size:13px">${esc(f.autor.split(" ")[0])} verá lo que te llevas. Así sabe qué dejó en su gente.</p>
        <div class="botones"><button type="button" class="btn" data-cerrar-hoja>Ahora no</button><button class="btn lleno">Llevármelo</button></div></form>`);
  }
  async function resumen(f, minutos, luces) {
    let llevo = [];
    if (!f.demo && Store.nube) try {
      await new Promise(r => setTimeout(r, 1500));
      const { data } = await Store.nube.sb.from("fogata_llevo").select("texto,autor:profiles!fogata_llevo_user_id_fkey(nombre,username)").eq("fogata_id", f.id).order("created_at");
      llevo = data || [];
    } catch (e) { console.warn(e); }
    abrirHoja(`<div class="hoja-cab"><h3>Tu fogata se apagó</h3></div>
      <div class="fg-resumen"><p><b>${minutos}</b> min encendida · <b>${luces}</b> ${luces === 1 ? "luz" : "luces"} recibidas</p>
      <h4>Lo que se llevaron</h4>
      ${llevo.length ? `<ul>${llevo.map(x => `<li><b>${esc(x.autor?.nombre || x.autor?.username || "")}</b> ${esc(x.texto)}</li>`).join("")}</ul>` : `<p class="suave">Las personas lo están escribiendo ahora. Lo verás en el resumen de esta fogata en unos minutos.</p>`}
      <div class="botones"><button class="btn lleno" data-cerrar-hoja>Listo</button></div></div>`);
  }

  /* Acciones dentro de la capa */
  const ACCF = {
    eje(b) { b.parentElement.querySelectorAll("[role=radio]").forEach(x => x.setAttribute("aria-checked", x === b)); },
    async encender(b) {
      const form = document.getElementById("fgForm"), titulo = form.titulo.value.trim();
      if (titulo.length < 3) { form.titulo.focus(); toast("Escribe de qué hablarás en la fogata."); return; }
      const eje = form.querySelector('[role=radio][aria-checked="true"]')?.dataset.arg || "";
      b.disabled = true; b.textContent = "Encendiendo…";
      const yo = perfil();
      FOG.anfitrion = true; FOG.luces = 0; FOG.inicio = Date.now(); FOG.mic = FOG.cam = true;
      if (!Store.nube) {
        // Ejemplo: la vista previa se vuelve la fogata, sin salir de este navegador
        const prev = FOG.preview; FOG.preview = null;
        FOG.f = { id: "demo-mia", titulo, eje, autor: yo.nombre || "Tú", avatar: yo.fotoPerfilUrl || "", demo: true, personas: 1 }; FOG.demo = true;
        pintarVivo(); const v = document.getElementById("fgVideo");
        if (prev && v) { v.srcObject = prev; v.classList.add("lista"); document.getElementById("fgEspera")?.remove(); FOG.preview = prev; }
        simular(); return;
      }
      try {
        FOG.preview?.getTracks().forEach(t => t.stop()); FOG.preview = null;
        const d = await pedir({ accion: "encender", titulo, eje });
        FOG.f = { id: d.fogata.id, titulo, eje, autor: yo.nombre || "Tú", avatar: yo.fotoPerfilUrl || "", personas: 1 }; FOG.demo = false;
        pintarVivo(); await conectar(d);
      } catch (e) { toast(e.message || "No se pudo encender la fogata."); FOG.anfitrion = false; quitarCapa(); }
    },
    luz(b, k) {
      subirLuz(k, "");
      try { if (window.navigator.vibrate) navigator.vibrate(8); } catch {}
      if (FOG.room) FOG.room.localParticipant.publishData(new TextEncoder().encode(JSON.stringify({ t: "luz", k })), { reliable: false }).catch(() => {});
    },
    async mic(b) { FOG.mic = !FOG.mic; await FOG.room?.localParticipant.setMicrophoneEnabled(FOG.mic).catch(() => {}); b.innerHTML = FOG.mic ? ic("mic") : svgP(P.micNo); b.setAttribute("aria-pressed", !FOG.mic); },
    async cam(b) {
      FOG.cam = !FOG.cam; b.innerHTML = svgP(FOG.cam ? P.cam : P.camNo); b.setAttribute("aria-pressed", !FOG.cam);
      if (FOG.room) await FOG.room.localParticipant.setCameraEnabled(FOG.cam).catch(() => {});
      else FOG.preview?.getVideoTracks().forEach(t => t.enabled = FOG.cam);
      document.getElementById("fgVideo")?.classList.toggle("oculto", !FOG.cam);
    },
    async girar() {
      FOG.frente = !FOG.frente;
      const pub = FOG.room && [...FOG.room.localParticipant.videoTrackPublications.values()][0];
      if (pub?.track?.restartTrack) await pub.track.restartTrack({ facingMode: FOG.frente ? "user" : "environment" }).catch(() => {});
      document.getElementById("fgVideo")?.classList.toggle("espejo", FOG.frente);
    },
    salir() {
      if (FOG.vista === "encender") { quitarCapa(); FOG.vista = null; return; }
      if (!FOG.anfitrion) return terminar(false);
      abrirHoja(`<div class="hoja-cab"><h3>¿Apagar la fogata?</h3></div><p class="suave" style="margin:0 0 12px">Todas las personas saldrán y cada una escribirá qué se lleva para su paso de mañana.</p>
        <div class="botones"><button class="btn" data-cerrar-hoja>Seguir en vivo</button><button class="btn lleno" data-acc="fogataApagar">Apagar</button></div>`);
    },
    reportar() {
      abrirHoja(`<div class="hoja-cab"><h3>Reportar esta fogata</h3></div>
        <form class="form" data-form="fogataReporte"><label class="campo"><span>¿Qué está pasando?</span><textarea name="texto" maxlength="600" required placeholder="Cuéntanos qué viste o escuchaste"></textarea></label>
        <div class="botones"><button type="button" class="btn" data-cerrar-hoja>Cancelar</button><button class="btn lleno">Enviar reporte</button></div></form>`);
    },
    cortar() {
      abrirHoja(`<div class="hoja-cab"><h3>¿Cortar esta fogata?</h3></div><p class="suave" style="margin:0 0 12px">La transmisión termina para todos y queda registrada como cortada por moderación.</p>
        <div class="botones"><button class="btn" data-cerrar-hoja>Cancelar</button><button class="btn lleno peligro" data-acc="fogataCortar">Cortar</button></div>`);
    },
  };
  ACC.fogataApagar = async () => {
    cerrarHoja();
    if (!FOG.demo) try { await pedir({ accion: "apagar", id: FOG.f.id }); } catch (e) { toast(e.message); }
    terminar(false);
  };
  ACC.fogataCortar = async () => {
    cerrarHoja();
    try { await pedir({ accion: "apagar", id: FOG.f.id }); toast("Fogata cortada"); } catch (e) { toast(e.message); }
    FOG.f = null; terminar(true);
  };

  // Los formularios de las hojas pasan por el mismo «enviar» de la app
  document.addEventListener("submit", async e => {
    const f = e.target.closest('form[data-form="fogataLlevo"], form[data-form="fogataReporte"]'); if (!f) return;
    e.preventDefault(); e.stopImmediatePropagation();
    const texto = String(new FormData(f).get("texto") || "").trim(); if (!texto) return;
    if (f.dataset.form === "fogataLlevo") {
      const id = f.dataset.arg;
      if (Store.nube && !String(id).startsWith("demo")) {
        const { error } = await Store.nube.sb.from("fogata_llevo").upsert({ fogata_id: id, user_id: Store.nube.dueno, texto });
        if (error) { toast("No se pudo guardar." + detalleError(error)); return; }
      }
      cerrarHoja(); toast("Te lo llevas. Mañana es tu paso.");
    } else {
      const fg = FOG.f; if (!fg || !Store.nube) return;
      const { error } = await Store.nube.sb.from("reportes").insert({ quien: Store.nube.dueno, a_quien: fg.autorId || null, motivo: `Fogata en vivo «${fg.titulo}» (${fg.id}): ${texto}`.slice(0, 1000) });
      cerrarHoja(); toast(error ? "No se pudo enviar el reporte." : "Gracias. Moderación lo revisará.");
    }
  }, true);
})();
