"use strict";
/* ======================================================================
 * Acceder con Face ID (o la huella, Touch ID o Windows Hello del aparato).
 * Igual que el sello de la app con rostro o huella: al abrir SuRoute, y al volver tras 5 minutos
 * fuera, una pantalla pide el desbloqueo del aparato antes de mostrar la ruta.
 * Usa una llave de acceso (WebAuthn) que vive en el aparato: SuRoute nunca ve ni guarda la cara
 * ni la huella. Si falla, el sistema ofrece el código del teléfono; y "Entrar de otra forma"
 * cierra la sesión para volver a entrar con el correo.
 *   localStorage suroute-acceso-llave  → id de la llave de este aparato
 *   localStorage suroute-acceso-nombre → nombre para el saludo
 * ====================================================================== */
(() => {
  const LLAVE = "suroute-acceso-llave", NOMBRE = "suroute-acceso-nombre", AUSENCIA = 5 * 60 * 1000;
  const leer = k => { try { return localStorage.getItem(k) || ""; } catch { return ""; } };
  const guardar = (k, v) => { try { v ? localStorage.setItem(k, v) : localStorage.removeItem(k); } catch {} };
  const posible = () => !!window.PublicKeyCredential && !!navigator.credentials?.get && isSecureContext;
  const aB64 = b => btoa(String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const deB64 = t => Uint8Array.from(atob(t.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((t.length + 3) % 4)), c => c.charCodeAt(0));

  /** Cómo se llama el desbloqueo en este aparato. */
  function metodo() {
    const ua = navigator.userAgent || "";
    const ipad = /iPad/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
    if (/iPhone/.test(ua) || ipad) return { n: "Face ID", ic: "faceid" };
    if (/Macintosh/.test(ua)) return { n: "Touch ID", ic: "huella" };
    if (/Windows/.test(ua)) return { n: "Windows Hello", ic: "rostro" };
    return { n: "tu huella o rostro", ic: "huella" };
  }
  window.accesoMetodo = metodo;
  const activo = () => !!leer(LLAVE) && posible();

  async function crear() {
    const nombre = (perfil().nombre || "").trim();
    const cred = await navigator.credentials.create({ publicKey: {
      rp: { name: "SuRoute" }, challenge: crypto.getRandomValues(new Uint8Array(32)),
      user: { id: crypto.getRandomValues(new Uint8Array(16)), name: "Acceso a SuRoute", displayName: (nombre ? nombre + " · " : "") + "SuRoute" },
      pubKeyCredParams: [{ type: "public-key", alg: -7 }, { type: "public-key", alg: -257 }],
      authenticatorSelection: { authenticatorAttachment: "platform", userVerification: "required", residentKey: "discouraged" }, timeout: 60000 } });
    guardar(LLAVE, aB64(cred.rawId)); guardar(NOMBRE, nombre);
  }
  const verificar = () => navigator.credentials.get({ publicKey: {
    challenge: crypto.getRandomValues(new Uint8Array(32)), userVerification: "required", timeout: 60000,
    allowCredentials: [{ type: "public-key", id: deB64(leer(LLAVE)) }] } });

  /* ---------- La pantalla de acceso ---------- */
  let velo = null, ocupado = false;
  function cerrarVelo() {
    if (!velo) return;
    const v = velo; velo = null; v.classList.add("sale");
    document.documentElement.classList.remove("acceso-cerrado");
    setTimeout(() => v.remove(), 260);
  }
  async function intentar() {
    if (ocupado || !velo) return; ocupado = true;
    const msg = velo.querySelector(".acc-msg"); msg.textContent = "";
    try { await verificar(); cerrarVelo(); }
    catch (e) { if (velo) msg.textContent = e?.name === "NotAllowedError" ? "" : `No se pudo usar ${metodo().n}. Inténtalo otra vez.`; }
    finally { ocupado = false; }
  }
  function mostrar(auto) {
    if (velo || !activo()) return;
    const m = metodo(), nombre = (typeof perfil === "function" && perfil().nombre) || leer(NOMBRE) || "";
    const ini = nombre.trim().split(/\s+/).slice(0, 2).map(x => x[0] || "").join("").toUpperCase();
    velo = document.createElement("div"); velo.className = "acc-velo"; velo.setAttribute("role", "dialog"); velo.setAttribute("aria-modal", "true"); velo.setAttribute("aria-labelledby", "accTitulo");
    velo.innerHTML = `<div class="acc-caja">
        <div class="acc-marca">${marca("logo", true)}</div>
        <div class="acc-saludo"><h1 id="accTitulo">Hola${nombre ? ",<br>" + esc(nombre.split(/\s+/).slice(0, 2).join(" ")) : ""}</h1>${ini ? `<span class="acc-ini" aria-hidden="true">${esc(ini)}</span>` : ""}</div>
        <p class="suave">Tu ruta está guardada. Ábrela con ${esc(m.n)}.</p>
        <button class="btn lleno acc-btn" type="button" data-a="ok">${ic(m.ic)} Acceder con ${esc(m.n)}</button>
        <p class="acc-msg" role="alert"></p>
        <button class="acc-otra" type="button" data-a="otra">Entrar de otra forma</button>
      </div>`;
    velo.onclick = e => {
      const a = e.target.closest("[data-a]")?.dataset.a;
      if (a === "ok") intentar();
      if (a === "otra") {
        const b = e.target.closest("button");
        if (!b.dataset.seguro) { b.dataset.seguro = "1"; b.textContent = Store.nube ? "Se cerrará la sesión. Toca otra vez" : "Se quitará el acceso. Toca otra vez"; return; }
        guardar(LLAVE, ""); cerrarVelo();
        if (Store.nube) ACC.salir();
      }
    };
    document.documentElement.classList.add("acceso-cerrado");
    document.body.append(velo);
    velo.querySelector(".acc-btn").focus();
    if (auto) setTimeout(intentar, 350);   // donde el navegador lo permite, el sistema pregunta solo
  }
  window.accesoMostrar = mostrar;

  // Al abrir, antes de ver la ruta
  if (activo() && location.hash !== "#demo") mostrar(true);
  // Al volver tras 5 minutos fuera
  let fuera = 0;
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) fuera = Date.now();
    else if (fuera && Date.now() - fuera >= AUSENCIA) mostrar(true);
  });

  /* ---------- Ajustes: en Mi cuenta ---------- */
  Object.assign(ACC, {
    async accesoActivar() {
      try { await crear(); toast(`Listo: SuRoute se abrirá con ${metodo().n}`); pintarDetalle(); }
      catch (e) { if (e?.name !== "NotAllowedError") toast(`Este aparato no permitió usar ${metodo().n}`); }
    },
    accesoQuitar() { guardar(LLAVE, ""); toast(`Acceso con ${metodo().n} quitado en este aparato`); pintarDetalle(); },
    accesoProbar() { mostrar(false); },
  });
  const cuenta = DET["perfil.cuenta"];
  DET["perfil.cuenta"] = (...a) => {
    const html = cuenta(...a), m = metodo();
    const bloque = hoja(`<h3>Acceder con ${esc(m.n)}</h3>` + (posible()
      ? `<div class="capa">${ic(m.ic)}<span><b>${activo() ? "Activo en este aparato" : "Abre SuRoute como abres tu banco"}</b><small>${activo()
          ? `Al abrir SuRoute, y al volver tras 5 minutos fuera, se pide ${esc(m.n)}. Tu rostro o tu huella nunca salen del aparato.`
          : `Al abrir SuRoute se pide ${esc(m.n)} antes de mostrar tu ruta. Tu rostro o tu huella nunca salen del aparato. En la app de Android: Perfil › Ajustes.`}</small></span>
          ${activo() ? `<div class="acc-bots"><button class="btn mini" data-acc="accesoProbar">Probar</button><button class="btn mini" data-acc="accesoQuitar">Quitar</button></div>` : `<button class="btn mini lleno" data-acc="accesoActivar">Activar</button>`}</div>`
      : `<p class="suave">Este navegador no permite el desbloqueo del aparato. En iPhone, abre SuRoute en Safari o desde la pantalla de inicio.</p>`));
    const i = html.indexOf('<div class="ancho"'), j = i < 0 ? -1 : html.indexOf(">", i) + 1;
    return j > 0 ? html.slice(0, j) + bloque + html.slice(j) : html + bloque;
  };
})();
