/* Luces de Comunidad: cinco reacciones pintadas como objetos reales (vela, farol de queroseno,
   estrella, luna y sol). Se dibujan en SVG con degradados para que pesen poco, se vean nítidas
   y se animen con CSS (la animación se apaga con «reducir movimiento»). */
(function () {
  const LUCES = [
    { id: "vela", nombre: "Te acompaño", cosa: "una vela" },
    { id: "farol", nombre: "Me iluminó", cosa: "un farol" },
    { id: "estrella", nombre: "Te admiro", cosa: "una estrella" },
    { id: "luna", nombre: "Te entiendo", cosa: "una luna" },
    { id: "sol", nombre: "¡Celebremos!", cosa: "un sol" },
  ];
  let n = 0;

  function estrellaFacetas(u) {
    const cx = 32, cy = 33, R = 26, r = 10.5, pts = [];
    for (let i = 0; i < 10; i++) {
      const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r : R;
      pts.push([cx + rr * Math.cos(a), cy + rr * Math.sin(a)]);
    }
    const f = (p) => p[0].toFixed(2) + " " + p[1].toFixed(2);
    let s = "";
    for (let i = 0; i < 10; i++) {
      const a = pts[i], b = pts[(i + 1) % 10];
      // Las caras que miran a la luz (arriba a la izquierda) más claras
      const mx = (a[0] + b[0]) / 2 - cx, my = (a[1] + b[1]) / 2 - cy;
      const luz = (-mx * 0.6 - my * 0.8) / 20;
      const cl = luz > 0.25 ? `url(#es-c${u})` : luz > -0.25 ? `url(#es-m${u})` : `url(#es-o${u})`;
      s += `<path d="M${cx} ${cy}L${f(a)}L${f(b)}Z" fill="${cl}"/>`;
    }
    return { caras: s, contorno: "M" + pts.map(f).join("L") + "Z" };
  }

  function svg(id, cls) {
    const u = "l" + (++n);
    const c = `class="luz luz-${id} ${cls || ""}" viewBox="0 0 64 64" aria-hidden="true" focusable="false"`;
    if (id === "vela") return `<svg ${c}><defs>
      <radialGradient id="vh${u}" cx="32" cy="18" r="26" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FFC66B" stop-opacity=".55"/><stop offset="1" stop-color="#FFC66B" stop-opacity="0"/></radialGradient>
      <linearGradient id="vc${u}" x1="0" x2="1"><stop offset="0" stop-color="#CDBF9F"/><stop offset=".32" stop-color="#FBF5E6"/><stop offset=".62" stop-color="#EFE5CE"/><stop offset="1" stop-color="#BBAA86"/></linearGradient>
      <radialGradient id="vf${u}" cx="50%" cy="72%" r="60%"><stop offset="0" stop-color="#FFFBE8"/><stop offset=".38" stop-color="#FFDA74"/><stop offset=".78" stop-color="#FF9A2E"/><stop offset="1" stop-color="#F06A12"/></radialGradient>
      <linearGradient id="vb${u}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#FFF4D6" stop-opacity=".9"/><stop offset="1" stop-color="#FFF4D6" stop-opacity="0"/></linearGradient>
    </defs>
      <circle class="luz-halo" cx="32" cy="18" r="26" fill="url(#vh${u})"/>
      <ellipse cx="32" cy="61" rx="13" ry="1.8" fill="#000" opacity=".16"/>
      <rect x="22" y="30" width="20" height="30" rx="2.2" fill="url(#vc${u})"/>
      <path d="M23.4 30.6c-.8 5-.4 9.5.6 11.4.9 1.6 2.2 1.2 2.3-.6.2-3.3-.2-7.3-.5-10.6z" fill="#F7EFDC"/>
      <path d="M37 31c.3 3 .6 4.6 1.5 5 .9.4 1.5-.4 1.4-2-.1-1.3-.4-2.2-.7-3z" fill="#F3EAD4"/>
      <ellipse cx="32" cy="30.3" rx="10" ry="2.6" fill="#EDE2C7"/>
      <ellipse cx="32" cy="30.5" rx="6.8" ry="1.5" fill="#FFF8E3"/>
      <path d="M32 30.4c.5-1.8.2-3.4-.5-4.8" stroke="#2A211B" stroke-width="1.2" fill="none" stroke-linecap="round"/>
      <g class="luz-llama">
        <path d="M32 4.5C37.6 12.4 38.6 19.6 32 26.3 25.4 19.6 26.4 12.4 32 4.5z" fill="url(#vf${u})"/>
        <path d="M32 12.5c2.6 3.8 3 7.4 0 11.4-3-4-2.6-7.6 0-11.4z" fill="#FFFDF3"/>
        <ellipse cx="32" cy="24.6" rx="2" ry="1.3" fill="#5E8DF0" opacity=".55"/>
      </g>
      <rect x="25" y="32" width="2.2" height="26" rx="1.1" fill="url(#vb${u})" opacity=".55"/>
    </svg>`;

    if (id === "farol") return `<svg ${c}><defs>
      <radialGradient id="fh${u}" cx="32" cy="32" r="28" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FFC66B" stop-opacity=".6"/><stop offset="1" stop-color="#FFC66B" stop-opacity="0"/></radialGradient>
      <linearGradient id="fb${u}" x1="0" x2="1"><stop offset="0" stop-color="#7A5A1E"/><stop offset=".3" stop-color="#E9CB7E"/><stop offset=".55" stop-color="#B88E3A"/><stop offset="1" stop-color="#5E4314"/></linearGradient>
      <radialGradient id="fv${u}" cx="50%" cy="58%" r="58%"><stop offset="0" stop-color="#FFF6D2" stop-opacity=".95"/><stop offset=".5" stop-color="#FFD782" stop-opacity=".6"/><stop offset="1" stop-color="#F3E3C0" stop-opacity=".22"/></radialGradient>
      <radialGradient id="ff${u}" cx="50%" cy="72%" r="60%"><stop offset="0" stop-color="#FFFBE8"/><stop offset=".4" stop-color="#FFDA74"/><stop offset=".8" stop-color="#FF9A2E"/><stop offset="1" stop-color="#F06A12"/></radialGradient>
    </defs>
      <circle class="luz-halo" cx="32" cy="32" r="28" fill="url(#fh${u})"/>
      <ellipse cx="32" cy="61.5" rx="15" ry="1.8" fill="#000" opacity=".16"/>
      <path d="M21.5 13.5C21 1.5 43 1.5 42.5 13.5" stroke="#4A3B2E" stroke-width="1.8" fill="none" stroke-linecap="round"/>
      <rect x="28.6" y="6.6" width="6.8" height="3.6" rx="1" fill="url(#fb${u})"/>
      <path d="M21 17.5h22l-4-7.5H25z" fill="url(#fb${u})"/>
      <path d="M23.6 17.5C13.6 24 13.6 40.5 23.6 47h16.8c10-6.5 10-23 0-29.5z" fill="url(#fv${u})" stroke="#8A6A2E" stroke-opacity=".45" stroke-width=".8"/>
      <g class="luz-llama luz-llama-farol">
        <path d="M32 23.5c3.6 5 4.2 9.6 0 14-4.2-4.4-3.6-9 0-14z" fill="url(#ff${u})"/>
        <path d="M32 29c1.6 2.4 1.8 4.6 0 7-1.8-2.4-1.6-4.6 0-7z" fill="#FFFDF3"/>
      </g>
      <rect x="27.5" y="37.6" width="9" height="3.6" rx="1" fill="url(#fb${u})"/>
      <path d="M20 21.5c-2.6 6-2.6 15.5 0 21.5" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" fill="none" opacity=".55"/>
      <path d="M20.6 17.5v29.5M43.4 17.5v29.5" stroke="url(#fb${u})" stroke-width="1.3"/>
      <path d="M19.5 47h25c3 0 5 2 5 5v3.6c0 2.4-1.8 4.4-4.2 4.4H18.7c-2.4 0-4.2-2-4.2-4.4V52c0-3 2-5 5-5z" fill="url(#fb${u})"/>
      <path d="M17 51.6h30" stroke="#FFF1C8" stroke-width=".9" opacity=".6"/>
      <circle cx="50.6" cy="51.5" r="2" fill="url(#fb${u})" stroke="#5E4314" stroke-width=".5"/>
    </svg>`;

    if (id === "estrella") {
      const e = estrellaFacetas(u);
      return `<svg ${c}><defs>
      <radialGradient id="eg${u}" cx="32" cy="33" r="30" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#F3D27A" stop-opacity=".55"/><stop offset="1" stop-color="#F3D27A" stop-opacity="0"/></radialGradient>
      <linearGradient id="es-c${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#FFF1BF"/><stop offset="1" stop-color="#E9C463"/></linearGradient>
      <linearGradient id="es-m${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#E2B54E"/><stop offset="1" stop-color="#C39033"/></linearGradient>
      <linearGradient id="es-o${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#A97A27"/><stop offset="1" stop-color="#7C5719"/></linearGradient>
    </defs>
      <circle class="luz-halo" cx="32" cy="33" r="30" fill="url(#eg${u})"/>
      ${e.caras}
      <path d="${e.contorno}" fill="none" stroke="#6E4D16" stroke-width=".7" stroke-linejoin="round" opacity=".6"/>
      <g class="luz-destello"><path d="M50 9l1.1 4.4L55.5 14.5l-4.4 1.1L50 20l-1.1-4.4L44.5 14.5l4.4-1.1z" fill="#FFF8DF" stroke="#C99A3A" stroke-width=".6"/></g>
    </svg>`;
    }

    if (id === "luna") return `<svg ${c}><defs>
      <radialGradient id="lg${u}" cx="30" cy="32" r="31" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#D9E6FF" stop-opacity=".55"/><stop offset="1" stop-color="#D9E6FF" stop-opacity="0"/></radialGradient>
      <radialGradient id="ld${u}" cx="30%" cy="35%" r="75%"><stop offset="0" stop-color="#FCFAF1"/><stop offset=".55" stop-color="#E2DDCD"/><stop offset="1" stop-color="#ACA591"/></radialGradient>
      <radialGradient id="lk${u}" cx="40%" cy="40%" r="60%"><stop offset="0" stop-color="#B9B29E"/><stop offset="1" stop-color="#CFC9B7"/></radialGradient>
      <mask id="lm${u}"><rect width="64" height="64" fill="#fff"/><circle cx="43" cy="26" r="19.5" fill="#000"/></mask>
    </defs>
      <circle class="luz-halo" cx="30" cy="32" r="31" fill="url(#lg${u})"/>
      <g mask="url(#lm${u})">
        <circle cx="32" cy="32" r="22" fill="url(#ld${u})"/>
        <circle cx="18" cy="31" r="3.2" fill="url(#lk${u})"/><path d="M15.2 32.2a3.2 3.2 0 0 0 5.6 .4" stroke="#FFFDF4" stroke-width=".8" fill="none" opacity=".8"/>
        <circle cx="23" cy="45" r="2.4" fill="url(#lk${u})"/>
        <circle cx="14.5" cy="40.5" r="1.5" fill="url(#lk${u})"/>
        <circle cx="31" cy="50" r="1.7" fill="url(#lk${u})"/>
        <circle cx="21" cy="21.5" r="1.8" fill="url(#lk${u})"/>
        <circle cx="38" cy="47" r="1.1" fill="url(#lk${u})"/>
      </g>
    </svg>`;

    // sol
    let rayos = "";
    for (let i = 0; i < 12; i++) rayos += `<path d="M32 3.5l2.2 12h-4.4z" transform="rotate(${i * 30} 32 32)"/>`;
    return `<svg ${c}><defs>
      <radialGradient id="sg${u}" cx="32" cy="32" r="31" gradientUnits="userSpaceOnUse"><stop offset=".35" stop-color="#FFD978" stop-opacity=".75"/><stop offset="1" stop-color="#FFB347" stop-opacity="0"/></radialGradient>
      <radialGradient id="sd${u}" cx="42%" cy="40%" r="62%"><stop offset="0" stop-color="#FFFBE6"/><stop offset=".35" stop-color="#FFE07A"/><stop offset=".78" stop-color="#FFA126"/><stop offset="1" stop-color="#DD6417"/></radialGradient>
      <filter id="st${u}" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".55" numOctaves="2" seed="4"/><feColorMatrix values="0 0 0 0 .55  0 0 0 0 .25  0 0 0 0 0  0 0 0 .55 0"/><feComposite in2="SourceGraphic" operator="in"/></filter>
    </defs>
      <circle class="luz-halo" cx="32" cy="32" r="31" fill="url(#sg${u})"/>
      <g class="luz-rayos" fill="#FFC24A" opacity=".55">${rayos}</g>
      <circle cx="32" cy="32" r="15.5" fill="url(#sd${u})"/>
      <circle cx="32" cy="32" r="15.5" fill="#fff" filter="url(#st${u})" opacity=".35"/>
      <ellipse cx="27" cy="26" rx="4.5" ry="3" fill="#fff" opacity=".35"/>
    </svg>`;
  }

  window.LUCES = LUCES;
  window.luzSVG = svg;
})();

/* ======================================================================
 * Luces: la reacción de la comunidad. Reemplaza al impulso y a los climas de las publicaciones
 * (los climas siguen en Bienestar del día, como clima interior).
 * · Cada luz es un impulso con su matiz: vive en la tabla votes, columna luz (supabase/2026-11-01-luces.sql).
 *   Por eso los milímetros de la expedición, los avisos y «Para ti» siguen contando igual.
 * · Un toque (o doble toque sobre la cima) da tu luz de siempre: la última que elegiste; al principio, el sol.
 *   Si ya diste una, un toque la quita. Mantén el dedo y se abre la fila de las cinco: desliza y suelta.
 * · Todos ven qué luces recibió una publicación y cuántas.
 * ====================================================================== */
(function () {
  const L = window.LUCES, ids = L.map(l => l.id);
  const luzDe = k => L.find(l => l.id === k) || L[4];
  const nombreLuz = k => luzDe(k).nombre;
  window.fraseLuz = k => ids.includes(k) ? `te dio ${luzDe(k).cosa}: «${nombreLuz(k)}»` : "";
  const ultima = () => { try { const k = localStorage.getItem("suroute-luz-ultima"); return ids.includes(k) ? k : "sol"; } catch { return "sol"; } };
  const locales = () => { try { return JSON.parse(localStorage.getItem("suroute-luces") || "{}"); } catch { return {}; } };
  /** Conteos de ejemplo estables por publicación (los mismos que la app). */
  function demo(id) {
    let h = 7; for (const ch of String(id)) h = (h * 37 + ch.charCodeAt(0)) >>> 0;
    const r = {}; ids.forEach((k, i) => { r[k] = (h >>> (i * 4)) % (k === "sol" ? 11 : k === "estrella" ? 7 : 4); }); return r;
  }
  const total = p => ids.reduce((s, k) => s + (p.luces?.[k] || 0), 0);
  const top = p => ids.filter(k => p.luces?.[k]).sort((a, b) => p.luces[b] - p.luces[a] || ids.indexOf(b) - ids.indexOf(a)).slice(0, 3);
  const enNube = p => Store.nube && !p.demo && /^[0-9a-f-]{36}$/i.test(String(p.id));
  /** El impulso de siempre sigue al día con la luz (milímetros, «Para ti», contadores). */
  const sincronizar = p => { p.impulsos = total(p); p.yoImpulse = !!p.miLuz; };

  /** Agrega luces y miLuz a las publicaciones (la nube o el ejemplo). */
  async function cargarLuces(ps) {
    if (!ps?.length) return;
    const loc = locales();
    ps.forEach(p => {
      if (enNube(p)) { p.luces = {}; p.miLuz = null; return; }
      p.luces = demo(p.id); p.miLuz = loc[p.id] || null;
      if (p.miLuz) p.luces[p.miLuz]++;
      sincronizar(p);
    });
    const nube = ps.filter(enNube); if (!nube.length) return;
    const sb = Store.nube.sb, yo = Store.nube.dueno, por = new Map(nube.map(p => [String(p.id), p]));
    let r = await sb.from("votes").select("post_id,user_id,luz").in("post_id", nube.map(p => p.id));
    if (r.error) { console.warn("Luces: falta correr supabase/2026-11-01-luces.sql", r.error); r = await sb.from("votes").select("post_id,user_id").in("post_id", nube.map(p => p.id)); }
    (r.data || []).forEach(f => { const p = por.get(String(f.post_id)); if (!p) return; const k = ids.includes(f.luz) ? f.luz : "sol"; p.luces[k] = (p.luces[k] || 0) + 1; if (f.user_id === yo) p.miLuz = k; });
    nube.forEach(sincronizar);
  }
  window.cargarLuces = cargarLuces;
  // El muro carga las luces donde antes cargaba los climas (los climas ya no van en las publicaciones)
  window.cargarClimas = cargarLuces;

  /** El botón: en Cimas, un círculo con la luz; en el muro, la pila de luces recibidas y una píldora con el nombre. */
  function botonLuz(p, lista = false) {
    if (!p.luces) cargarLuces([p]).then(() => pintar(p));
    const t = total(p), mia = p.miLuz, muestra = mia || (lista ? ultima() : top(p)[0] || ultima());
    const cifra = t || "";
    const etiqueta = mia ? `Diste «${nombreLuz(mia)}». Toca para quitarla; mantén para elegir otra` : `Dar «${nombreLuz(ultima())}». Mantén para elegir otra luz`;
    const boton = inner => `<button type="button" class="luz-btn ${lista ? "en-lista" : "en-cima"}${mia ? " mia" : ""}" data-post="${esc(String(p.id))}" aria-haspopup="menu" aria-pressed="${!!mia}" aria-label="${esc(etiqueta)}${cifra ? `, ${cifra} luces` : ""}">${inner}</button>`;
    if (lista) return `<span class="luz-wrap en-lista">${t ? `<span class="luz-pila" aria-hidden="true">${top(p).map(k => luzSVG(k, "quieta")).join("")}${cifra ? `<b>${cifra}</b>` : ""}</span>` : ""}${boton(`${luzSVG(muestra, mia ? "" : "quieta")}<span>${esc(nombreLuz(muestra))}</span>`)}</span>`;
    return `<span class="luz-wrap en-cima">${boton(`<span class="lb-circ${!mia && !t ? " apagada" : ""}">${luzSVG(muestra, mia ? "" : "quieta")}</span><b>${cifra}</b>`)}</span>`;
  }
  globalThis.botonLuz = botonLuz;

  const postDe = id => [...(estado.feed || []), ...(estado.misPosts || [])].find(x => String(x.id) === String(id)) || (String(estado.post?.id) === String(id) ? estado.post : null);

  /* ---------- La fila de las cinco luces ---------- */
  function cerrar() { document.querySelector(".luz-selector")?.remove(); document.removeEventListener("pointerdown", fuera, true); document.removeEventListener("keydown", teclas); }
  function fuera(e) { if (!e.target.closest(".luz-selector, .luz-btn")) cerrar(); }
  function teclas(e) {
    const s = document.querySelector(".luz-selector"); if (!s) return;
    if (e.key === "Escape") { const b = s.parentElement.querySelector(".luz-btn"); cerrar(); b?.focus(); return; }
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      const bs = [...s.querySelectorAll(".lz-op")], i = bs.indexOf(document.activeElement);
      bs[(i + (e.key === "ArrowRight" ? 1 : -1) + bs.length) % bs.length]?.focus(); e.preventDefault();
    }
  }
  function abrir(b, conDedo) {
    cerrar();
    const p = postDe(b.dataset.post); if (!p) return;
    const s = document.createElement("div");
    s.className = "luz-selector"; s.setAttribute("role", "menu"); s.setAttribute("aria-label", "Elige tu luz");
    s.innerHTML = L.map((l, i) => `<button type="button" role="menuitemradio" class="lz-op${p.miLuz === l.id ? " si" : ""}" style="--i:${i}" data-luz="${l.id}" aria-checked="${p.miLuz === l.id}" aria-label="${esc(l.nombre)}">${luzSVG(l.id)}<span class="lz-n">${esc(l.nombre)}</span><small aria-hidden="true">${esc(l.nombre)}</small></button>`).join("");
    s.addEventListener("click", e => { const o = e.target.closest(".lz-op"); if (o) { e.stopPropagation(); elegir(p, o.dataset.luz); } });
    b.after(s);
    navigator.vibrate?.(8);
    setTimeout(() => { document.addEventListener("pointerdown", fuera, true); document.addEventListener("keydown", teclas); }, 0);
    if (!conDedo) s.querySelector(".lz-op.si, .lz-op")?.focus({ preventScroll: true });
  }

  function pintar(p) {
    // Se actualiza en su lugar (sin reemplazar el botón): dos toques seguidos no deben verse como un doble toque en la cima
    document.querySelectorAll(`.luz-btn[data-post="${CSS.escape(String(p.id))}"]`).forEach(viejo => {
      const w = viejo.closest(".luz-wrap"), t = document.createElement("template");
      t.innerHTML = botonLuz(p, w.classList.contains("en-lista"));
      const nuevo = t.content.querySelector(".luz-btn");
      viejo.className = nuevo.className; viejo.innerHTML = nuevo.innerHTML;
      ["aria-pressed", "aria-label"].forEach(k => viejo.setAttribute(k, nuevo.getAttribute(k)));
      w.querySelector(".luz-pila")?.remove();
      const pila = t.content.querySelector(".luz-pila"); if (pila) w.prepend(pila);
    });
  }
  async function elegir(p, k) {
    if (!p.luces) await cargarLuces([p]);
    const antes = p.miLuz, nuevo = antes === k ? null : k;
    if (antes) p.luces[antes] = Math.max(0, (p.luces[antes] || 0) - 1);
    if (nuevo) { p.luces[nuevo] = (p.luces[nuevo] || 0) + 1; try { localStorage.setItem("suroute-luz-ultima", nuevo); } catch {} }
    p.miLuz = nuevo; sincronizar(p);
    cerrar(); pintar(p);
    if (nuevo) {
      document.querySelectorAll(`.luz-btn[data-post="${CSS.escape(String(p.id))}"]`).forEach(b => { b.classList.add("recien"); setTimeout(() => b.classList.remove("recien"), 700); });
      navigator.vibrate?.(12);
    }
    if (!enNube(p)) {
      const l = locales(); if (nuevo) l[p.id] = nuevo; else delete l[p.id];
      try { localStorage.setItem("suroute-luces", JSON.stringify(l)); } catch {}
      return;
    }
    try {
      const sb = Store.nube.sb, yo = Store.nube.dueno;
      let r;
      if (!nuevo) r = await sb.from("votes").delete().eq("post_id", p.id).eq("user_id", yo);
      else if (antes) r = await sb.from("votes").update({ luz: nuevo }).eq("post_id", p.id).eq("user_id", yo);
      else {
        r = await sb.from("votes").insert({ post_id: p.id, user_id: yo, luz: nuevo });
        if (r.error?.code === "23505") r = await sb.from("votes").update({ luz: nuevo }).eq("post_id", p.id).eq("user_id", yo);
        else if (r.error && /luz/.test(r.error.message || "")) r = await sb.from("votes").insert({ post_id: p.id, user_id: yo });   // sin la columna luz todavía: queda como impulso
      }
      if (r.error) throw r.error;
    } catch (e) { console.error(e); toast("No se pudo guardar tu luz." + detalleError(e)); }
  }
  function tocar(b) { const p = postDe(b.dataset.post); if (p) elegir(p, p.miLuz || ultima()); }

  // El impulso de siempre (doble toque en la cima, «me lo llevo», atajos) ahora da tu luz
  Object.assign(ACC, {
    impulsar() { const p = estado.post; if (p) elegir(p, p.miLuz || ultima()); },
    impulsarId(el, id) { const p = postDe(id); if (p) elegir(p, p.miLuz || ultima()); },
  });

  /* ---------- Toque, mantener y deslizar ---------- */
  let g = null;
  const sobre = (x, y) => document.elementFromPoint(x, y)?.closest?.(".luz-selector .lz-op");
  document.addEventListener("pointerdown", e => {
    const b = e.target.closest?.(".luz-btn"); if (!b || e.button > 0) return;
    g = { b, x: e.clientX, y: e.clientY, largo: false };
    g.t = setTimeout(() => { if (!g) return; g.largo = true; abrir(b, true); }, 420);
  });
  document.addEventListener("pointermove", e => {
    if (!g) return;
    if (!g.largo) { if (Math.hypot(e.clientX - g.x, e.clientY - g.y) > 10) { clearTimeout(g.t); g = null; } return; }
    const o = sobre(e.clientX, e.clientY);
    document.querySelectorAll(".luz-selector .lz-op").forEach(x => x.classList.toggle("lz-sobre", x === o));
    if (o && o !== g.o) { g.o = o; navigator.vibrate?.(4); }
  });
  document.addEventListener("pointerup", e => {
    if (!g) return; const x = g; g = null; clearTimeout(x.t);
    if (!x.largo) { if (e.target.closest?.(".luz-btn") === x.b) tocar(x.b); return; }
    const o = sobre(e.clientX, e.clientY);
    if (o) { const p = postDe(x.b.dataset.post); if (p) elegir(p, o.dataset.luz); }
  });
  document.addEventListener("pointercancel", () => { if (g) { clearTimeout(g.t); g = null; } });
  // Con mouse (computador): al dejar el cursor sobre la luz se abre la fila; al salir, se cierra
  let tSobre = null, tSalir = null;
  const zona = el => el?.closest?.(".luz-btn, .luz-selector");
  document.addEventListener("pointerover", e => {
    if (e.pointerType !== "mouse") return;
    const z = zona(e.target); if (!z) return;
    clearTimeout(tSalir);
    const b = e.target.closest(".luz-btn"), abierta = document.querySelector(".luz-selector");
    if (b && !(abierta && abierta.parentElement === b.parentElement)) { clearTimeout(tSobre); tSobre = setTimeout(() => { if (b.matches(":hover")) abrir(b, true); }, 450); }
  });
  document.addEventListener("pointerout", e => {
    if (e.pointerType !== "mouse") return;
    const de = zona(e.target); if (!de) return;
    const a = zona(e.relatedTarget);
    if (a && a.closest(".luz-wrap") === de.closest(".luz-wrap")) return;
    clearTimeout(tSobre);
    tSalir = setTimeout(() => { if (!document.querySelector(".luz-selector:hover, .luz-btn:hover")) cerrar(); }, 350);
  });
  // Teclado: Intro da o quita; flecha arriba, menú contextual o Mayús+F10 abre la fila
  document.addEventListener("click", e => { const b = e.target.closest?.(".luz-btn"); if (b && e.detail === 0) tocar(b); });
  document.addEventListener("keydown", e => {
    const b = e.target.closest?.(".luz-btn"); if (!b) return;
    if (e.key === "ArrowUp" || e.key === "ContextMenu" || (e.key === "F10" && e.shiftKey)) { e.preventDefault(); e.stopPropagation(); abrir(b, false); }
  }, true);
  // Dos toques seguidos sobre la luz no son el doble toque de la cima
  document.addEventListener("dblclick", e => { if (!e.target.isConnected || e.target.closest?.(".luz-wrap, .luz-selector")) e.stopPropagation(); }, true);
  document.addEventListener("contextmenu", e => { if (e.target.closest?.(".luz-btn, .luz-selector")) e.preventDefault(); });
})();
