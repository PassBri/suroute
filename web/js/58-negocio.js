/* =========================================================================
 * SuRoute · Mi negocio
 * Las cuentas de cada negocio, aparte de las finanzas personales. Una persona puede llevar
 * varios negocios. Por ahora solo plata (lo que entra y sale); el inventario vendrá después.
 * Todo vive en el libro de finanzas con claves "fin#neg#…" (cifradas y bloqueadas con el PIN
 * como el resto del ascenso financiero; la app usa las mismas claves y el mismo formato):
 *   fin#neg#lista                 [{ id, n: nombre, g?: a qué se dedica }]
 *   fin#neg#<id>#mov#<aaaa-mm>    [{ id, f: "aaaa-mm-dd", t: ven|cos|gas|inv|pag, m, c?, n? }]
 *   fin#neg#<id>#bal              { a: [{ id, n, k, m }], p: [{ id, n, k, m }] }   (activos y pasivos)
 * El puente con lo personal: un «Pago al dueño» del negocio escribe también un ingreso personal
 * (categoría «Negocio») en fin#mov#<fecha> con id "ng-<id>"; al borrarlo se borran los dos.
 * ========================================================================= */
(function () {
  const LISTA = "fin#neg#lista";
  const claveMes = (id, ym) => `fin#neg#${id}#mov#${ym}`, claveBal = id => `fin#neg#${id}#bal`;
  /** Tipos de movimiento: [clave, nombre, ícono, ayuda, signo] */
  const TIPOS = [
    ["ven", "Venta", "plata", "Lo que vendiste o cobraste", 1],
    ["cos", "Costo", "bolsa", "Lo que te costó lo vendido: mercancía, materia prima", -1],
    ["gas", "Gasto", "recibo", "Lo que cuesta operar: arriendo, servicios, nómina…", -1],
    ["inv", "Inversión", "crecer", "Equipos, mejoras: lo que hace crecer el negocio", -1],
    ["pag", "Pago a ti", "perfil", "Lo que te pagas: entra a tus finanzas personales", -1]];
  const tipo = t => TIPOS.find(x => x[0] === t) || TIPOS[0];
  const CAT_GAS = [["arriendo", "Arriendo"], ["servicios", "Servicios"], ["nomina", "Nómina"], ["publicidad", "Publicidad"], ["transporte", "Transporte"],
    ["impuestos", "Impuestos"], ["bancos", "Bancos y comisiones"], ["otro", "Otro"]];
  const ACTIVOS = [["caja", "Caja y bancos", true], ["cobrar", "Por cobrar", true], ["inventario", "Inventario", true], ["equipo", "Equipos y muebles", false],
    ["local", "Local o vehículo", false], ["otro", "Otro", false]];
  const PASIVOS = [["proveedores", "Proveedores", true], ["corto", "Crédito a corto plazo", true], ["impuestos", "Impuestos por pagar", true],
    ["largo", "Crédito a largo plazo", false], ["otro", "Otro", false]];

  const leer = (k, d) => { try { const v = JSON.parse(respuesta(k) || "null"); return v ?? d; } catch { return d; } };
  window.negocios = () => { const l = leer(LISTA, []); return Array.isArray(l) ? l.filter(x => x && x.id && x.n) : []; };
  const guardarLista = l => responder(ASC.WB, LISTA, l.length ? JSON.stringify(l) : "");
  const movsMes = (id, ym) => { const l = leer(claveMes(id, ym), []); return Array.isArray(l) ? l.filter(x => x && TIPOS.some(t => t[0] === x.t) && Number.isFinite(Number(x.m))) : []; };
  const guardarMes = (id, ym, l) => responder(ASC.WB, claveMes(id, ym), l.length ? JSON.stringify(l.map(({ id, f, t, m, c, n }) =>
    ({ id, f, t, m: Math.round(Number(m) * 100) / 100, ...(c ? { c } : {}), ...(n ? { n: String(n).slice(0, 120) } : {}) }))) : "");
  const bal = id => { const b = leer(claveBal(id), {}); return { a: Array.isArray(b?.a) ? b.a : [], p: Array.isArray(b?.p) ? b.p : [] }; };
  const guardarBal = (id, b) => responder(ASC.WB, claveBal(id), b.a.length || b.p.length ? JSON.stringify(b) : "");
  /** Los meses con movimientos de un negocio (por las claves guardadas). */
  const mesesDe = id => { const p = `fin#neg#${id}#mov#`;
    return [...new Set(Store.lista("respuesta").filter(r => r.valor && r.clave?.startsWith(p)).map(r => r.clave).map(k => k.slice(p.length)))].sort(); };

  const hoyIso = () => iso(hoyFecha()), ymHoy = () => hoyIso().slice(0, 7);
  const ymMas = (ym, d) => { const [a, m] = ym.split("-").map(Number), f = new Date(a, m - 1 + d, 1); return `${f.getFullYear()}-${pad2(f.getMonth() + 1)}`; };
  const nombreMes = ym => { const [a, m] = ym.split("-").map(Number); return `${mayus(MESES[m - 1])} ${a}`; };
  const actual = () => { const l = negocios(); if (!l.length) return null; return l.find(x => x.id === estado.negSel) || l[0]; };
  const mesVer = () => estado.negMes || ymHoy();

  /** Las cifras de un conjunto de movimientos. */
  function cifras(movs) {
    const s = { ven: 0, cos: 0, gas: 0, inv: 0, pag: 0, n: movs.length, cat: {} };
    movs.forEach(x => { const m = Number(x.m) || 0; s[x.t] += m; if (x.t === "gas") s.cat[x.c || "otro"] = (s.cat[x.c || "otro"] || 0) + m; });
    s.bruta = s.ven - s.cos; s.util = s.bruta - s.gas; s.caja = s.util - s.inv - s.pag;
    return s;
  }
  /** Los últimos 12 meses (hasta el mes que se ve), para los indicadores. */
  function anio(id, ym) {
    const meses = Array.from({ length: 12 }, (_, i) => ymMas(ym, i - 11)), conDatos = meses.filter(m => movsMes(id, m).length);
    return { s: cifras(meses.flatMap(m => movsMes(id, m))), n: Math.max(1, conDatos.length) };
  }
  const sumaK = (l, corr, tabla) => l.filter(x => corr == null || !!tabla.find(t => t[0] === x.k)?.[2] === corr).reduce((a, x) => a + (Number(x.m) || 0), 0);

  /** Indicadores del negocio, con su meta y su riel (los mismos medidores de la salud financiera). */
  function indicadores(id, ym) {
    const { s, n } = anio(id, ym), b = bal(id), act = sumaK(b.a, null, ACTIVOS), pas = sumaK(b.p, null, PASIVOS);
    const actC = sumaK(b.a, true, ACTIVOS), pasC = sumaK(b.p, true, PASIVOS), anual = v => v / n * 12;
    const pct = v => (v * 100).toLocaleString(ascLocale, { maximumFractionDigits: 1 }) + " %", num = v => v.toLocaleString(ascLocale, { maximumFractionDigits: 2 });
    const est = (v, ok, medio, menor = false) => v == null ? "na" : menor ? (v <= ok ? "ok" : v <= medio ? "medio" : "bajo") : (v >= ok ? "ok" : v >= medio ? "medio" : "bajo");
    const margen = s.ven > 0 ? s.bruta / s.ven : null, neto = s.ven > 0 ? s.util / s.ven : null;
    const pe = margen > 0 ? s.gas / n / margen : null, venMes = s.ven / n;
    const l = [
      ["Margen bruto", margen, pct, est(margen, 0.3, 0.15), "(Ventas − costo de lo vendido) ÷ ventas. Lo que te queda de cada venta para pagar la operación.", { max: 0.8, meta: 0.3, metaTxt: "30 % o más", alto: true }],
      ["Rentabilidad neta", neto, pct, est(neto, 0.1, 0.03), "Utilidad ÷ ventas, después de costos y gastos de operación. Ideal: 10 % o más.", { max: 0.4, meta: 0.1, metaTxt: "10 % o más", alto: true }],
      ["Punto de equilibrio", pe, v => plata(Math.round(v)) + " /mes", pe == null ? "na" : venMes >= pe * 1.2 ? "ok" : venMes >= pe ? "medio" : "bajo",
        `Lo que necesitas vender al mes para no perder: gastos de operación ÷ margen bruto. Hoy vendes ${plata(Math.round(venMes))} al mes.`, {}],
      ["Rendimiento de los activos (ROA)", act > 0 && s.ven > 0 ? anual(s.util) / act : null, pct, est(act > 0 && s.ven > 0 ? anual(s.util) / act : null, 0.1, 0.05),
        "Utilidad del año ÷ todo lo que tiene el negocio. Cuánto produce lo que pusiste en él.", { max: 0.4, meta: 0.1, metaTxt: "10 % o más", alto: true }],
      ["Rotación de activos", act > 0 && s.ven > 0 ? anual(s.ven) / act : null, num, est(act > 0 && s.ven > 0 ? anual(s.ven) / act : null, 1, 0.5),
        "Ventas del año ÷ activos. Cuántas veces vendes lo que tienes. Ideal: 1 o más.", { max: 4, meta: 1, metaTxt: "1 o más", alto: true }],
      ["Liquidez corriente", pasC > 0 ? actC / pasC : null, num, est(pasC > 0 ? actC / pasC : null, 1.2, 1),
        "Caja, lo que te deben e inventario ÷ lo que debes pagar pronto. En 1,2 o más pagas tus deudas cortas con holgura.", { max: 3, meta: 1.2, metaTxt: "1,2 o más", alto: true }],
      ["Endeudamiento", act > 0 && pas > 0 ? pas / act : null, pct, est(act > 0 && pas > 0 ? pas / act : null, 0.5, 0.7, true),
        "Lo que debe el negocio ÷ lo que tiene. Menos del 50 %: sano.", { max: 1, meta: 0.5, metaTxt: "50 % o menos", alto: false }],
    ];
    return { s, n, act, pas, ind: l.filter(x => x[1] != null).map(([nombre, v, f, estado, ayuda, esc]) => ({ nombre, valor: f(v), v, estado, ayuda, ...esc })) };
  }

  /* ---------- Pintar ---------- */
  const selector = (l, a) => `<div class="neg-chips" role="tablist" aria-label="Tus negocios">${l.map(x =>
    `<button class="neg-chip" role="tab" aria-selected="${x.id === a.id}" data-acc="negElegir" data-arg="${x.id}">${ic("bolsa")}<span>${esc(x.n)}</span></button>`).join("")}
    <button class="neg-chip neg-mas" data-acc="negNuevo" aria-label="Agregar otro negocio">${ic("mas")}<span>Negocio</span></button></div>`;

  function resultados(s, ym) {
    const fila = (n, v, cls = "") => `<li class="${cls}"><span>${n}</span><b class="${v < 0 ? "neg" : ""}">${plata(v)}</b></li>`;
    return `<ul class="neg-er" aria-label="Estado de resultados de ${nombreMes(ym)}">
      ${fila("Ventas", s.ven)}${fila("− Costo de lo vendido", s.cos, "menos")}${fila("Utilidad bruta", s.bruta, "sub")}
      ${fila("− Gastos de operación", s.gas, "menos")}${fila("Utilidad del mes", s.util, "total")}
      ${s.inv ? fila("− Inversión en el negocio", s.inv, "menos") : ""}${s.pag ? fila("− Pago a ti", s.pag, "menos") : ""}
      ${s.inv || s.pag ? fila("Queda en caja", s.caja, "sub") : ""}</ul>`;
  }
  const filaMov = x => { const [t, n, i] = tipo(x.t), d = deIso(x.f), cat = x.t === "gas" ? CAT_GAS.find(c => c[0] === x.c)?.[1] : "";
    return `<li class="neg-mov t-${t}"><button class="neg-mov-b" data-acc="negMovEditar" data-arg="${x.id}" aria-label="Editar ${n} de ${plata(x.m)}">
      <span class="neg-mov-ic" aria-hidden="true">${ic(i)}</span><span class="neg-mov-txt"><b>${esc(x.n || cat || n)}</b><small>${d.getDate()} ${MES_C[d.getMonth()]} · ${n}${cat && x.n ? " · " + cat : ""}</small></span>
      <b class="neg-mov-m">${t === "ven" ? "+" : "−"}${plata(x.m)}</b></button></li>`; };

  function hojaBalance(id) {
    const b = bal(id), act = sumaK(b.a, null, ACTIVOS), pas = sumaK(b.p, null, PASIVOS);
    const lista = (l, tabla, lado) => l.length ? `<ul class="neg-bal">${l.map(x => `<li><button class="neg-bal-b" data-acc="negBalEditar" data-arg="${lado}:${x.id}">
      <span>${esc(x.n || tabla.find(t => t[0] === x.k)?.[1] || "")}<small>${tabla.find(t => t[0] === x.k)?.[1] || ""}</small></span><b>${plata(Number(x.m) || 0)}</b></button></li>`).join("")}</ul>`
      : `<p class="suave neg-vacio">${lado === "a" ? "Caja, lo que te deben, inventario, equipos…" : "Proveedores, créditos, impuestos por pagar…"}</p>`;
    return hoja(`<div class="cab-lista-btn"><h3 style="margin:0">${ic("flechasVert")} Lo que tiene y lo que debe</h3></div>
      <div class="neg-bal-col"><section><header><h4>Activos</h4><b>${plata(act)}</b></header>${lista(b.a, ACTIVOS, "a")}
        <button class="btn mini" data-acc="negBalNuevo" data-arg="a">${ic("mas")} Activo</button></section>
      <section><header><h4>Pasivos</h4><b>${plata(pas)}</b></header>${lista(b.p, PASIVOS, "p")}
        <button class="btn mini" data-acc="negBalNuevo" data-arg="p">${ic("mas")} Pasivo</button></section></div>
      ${act || pas ? `<p class="neg-patr">Patrimonio del negocio <b class="${act - pas < 0 ? "neg" : ""}">${plata(act - pas)}</b></p>` : ""}`, "neg-hoja");
  }

  window.negocioPagina = () => {
    const l = negocios(), a = actual();
    if (!a) return hoja(`<div class="neg-bienvenida">${ic("bolsa")}<h3>¿Tienes un negocio?</h3>
      <p class="suave">Lleva sus cuentas aquí, aparte de tu plata personal: lo que vendes, lo que cuesta, lo que queda y lo que te pagas. Puedes llevar varios.</p>
      <button class="btn lleno" data-acc="negNuevo">${ic("mas")} Crear mi negocio</button></div>`, "neg-hoja");
    const ym = mesVer(), movs = movsMes(a.id, ym).sort((x, y) => y.f.localeCompare(x.f) || 0), s = cifras(movs), r = indicadores(a.id, ym);
    const nav = `<div class="neg-nav"><button class="rb" data-acc="negMes" data-arg="-1" aria-label="Mes anterior">${ic("izq")}</button>
      <b>${nombreMes(ym)}</b><button class="rb" data-acc="negMes" data-arg="1" aria-label="Mes siguiente" ${ym >= ymHoy() ? "disabled" : ""}>${ic("der")}</button></div>`;
    const cabeza = `<div class="cab-lista-btn neg-cab"><h3 style="margin:0">${esc(a.n)}${a.g ? `<small>${esc(a.g)}</small>` : ""}</h3>
      <span class="hitos-cab-btns"><button class="rb" data-acc="negEditar" aria-label="Cambiar el nombre o borrar «${esc(a.n)}»" title="Ajustes del negocio">${ic("editar")}</button>
      <button class="btn mini lleno" data-acc="negMovNuevo">${ic("mas")} Anotar</button></span></div>`;
    const anotar = `<div class="neg-rapido" role="group" aria-label="Anotar rápido">${TIPOS.map(([t, n, i]) => `<button class="neg-rap t-${t}" data-acc="negMovNuevo" data-arg="${t}">${ic(i)}<span>${n}</span></button>`).join("")}</div>`;
    const mes = hoja(cabeza + anotar + nav + (movs.length ? resultados(s, ym) + `<h4 class="hitos-sub">Movimientos</h4><ul class="neg-movs">${movs.map(filaMov).join("")}</ul>`
      : `<p class="suave neg-vacio">Nada anotado en ${MESES[Number(ym.slice(5)) - 1]}. Empieza por tus ventas: toca «Venta».</p>`), "neg-hoja");
    const inds = r.ind.length ? hoja(`<div class="cab-lista-btn"><h3 style="margin:0">${ic("salud")} Salud del negocio</h3><small class="suave">Últimos ${r.n === 1 ? "mes" : r.n + " meses"}</small></div>
      <div class="medidores neg-meds">${r.ind.map(medidor).join("")}</div>
      <p class="suave neg-nota">No cuentan en tu Salud financiera personal. Lo que te pagas sí: llega como ingreso de tus finanzas.</p>`, "neg-hoja") : "";
    return selector(l, a) + mes + inds + hojaBalance(a.id);
  };

  /* ---------- Formularios ---------- */
  const botones = (borrar, arg) => `<div class="botones">${borrar ? `<button type="button" class="btn" data-acc="${borrar}" data-arg="${arg}" style="margin-right:auto">${ic("borrar")} Borrar</button>` : ""}<button type="button" class="btn" data-cerrar-hoja>Cancelar</button><button class="btn lleno">Guardar</button></div>`;
  function formNegocio(x) {
    return `<div class="hoja-cab"><h3>${x.id ? "Tu negocio" : "Nuevo negocio"}</h3></div>
    <form class="form" data-form="negocio" data-arg="${x.id || ""}">
      <label class="campo"><span>Nombre</span><input name="nombre" maxlength="60" required value="${esc(x.n || "")}" placeholder="Panadería La Cima, Diseño freelance…"></label>
      <label class="campo"><span>¿A qué se dedica? (opcional)</span><input name="giro" maxlength="80" value="${esc(x.g || "")}" placeholder="Venta de pan y café"></label>
      ${x.id ? `<p class="suave neg-nota">Borrar el negocio borra sus movimientos y su balance. Los pagos que te hiciste se quedan en tus finanzas personales.</p>` : ""}
      ${botones(x.id ? "negBorrar" : "", x.id || "")}</form>`;
  }
  function formMov(x) {
    const t = x.t || "ven";
    return `<div class="hoja-cab"><h3>${x.id ? "Editar movimiento" : "Anotar en " + esc(actual()?.n || "el negocio")}</h3></div>
    <form class="form neg-form" data-form="negMov" data-arg="${x.id || ""}" data-ym="${x.f ? x.f.slice(0, 7) : ""}">
      <div class="seg neg-tipos" role="radiogroup" aria-label="Tipo">${TIPOS.map(([v, n]) => `<label class="seg-b t-${v}"><input type="radio" name="tipo" value="${v}" ${v === t ? "checked" : ""}> ${n}</label>`).join("")}</div>
      <p class="suave neg-ayuda" data-neg-ayuda>${tipo(t)[3]}</p>
      <div class="hito-fila">
        <label class="campo"><span>Monto</span><input name="monto" inputmode="decimal" autocomplete="off" required value="${x.m ? numAsc(x.m) : ""}" placeholder="${plata(0)}"></label>
        <label class="campo"><span>Fecha</span><input type="date" name="fecha" required max="${hoyIso()}" value="${x.f || (mesVer() === ymHoy() ? hoyIso() : mesVer() + "-01")}"></label>
      </div>
      <label class="campo neg-cat" ${t === "gas" ? "" : "hidden"}><span>Categoría</span><select name="cat">${CAT_GAS.map(([v, n]) => `<option value="${v}" ${x.c === v ? "selected" : ""}>${n}</option>`).join("")}</select></label>
      <label class="campo"><span>Nota (opcional)</span><input name="nota" maxlength="120" value="${esc(x.n || "")}" placeholder="Cliente, producto, factura…"></label>
      ${botones(x.id ? "negMovBorrar" : "", x.id || "")}</form>`;
  }
  function formBal(lado, x) {
    const tabla = lado === "a" ? ACTIVOS : PASIVOS;
    return `<div class="hoja-cab"><h3>${x.id ? "Editar" : "Nuevo"} ${lado === "a" ? "activo" : "pasivo"}</h3></div>
    <form class="form" data-form="negBal" data-arg="${lado}:${x.id || ""}">
      <label class="campo"><span>Tipo</span><select name="tipo">${tabla.map(([v, n, c]) => `<option value="${v}" ${x.k === v ? "selected" : ""}>${n}${c ? (lado === "a" ? " · a la mano" : " · se paga este año") : ""}</option>`).join("")}</select></label>
      <label class="campo"><span>Nombre (opcional)</span><input name="nombre" maxlength="60" value="${esc(x.n || "")}" placeholder="${lado === "a" ? "Cuenta de ahorros, horno…" : "Banco, proveedor…"}"></label>
      <label class="campo"><span>${lado === "a" ? "Cuánto vale hoy" : "Cuánto debe hoy"}</span><input name="monto" inputmode="decimal" autocomplete="off" required value="${x.m ? numAsc(x.m) : ""}" placeholder="${plata(0)}"></label>
      ${botones(x.id ? "negBalBorrar" : "", `${lado}:${x.id || ""}`)}</form>`;
  }
  document.addEventListener("change", e => {
    const f = e.target.closest?.(".neg-form"); if (!f || e.target.name !== "tipo") return;
    f.querySelector(".neg-cat").hidden = e.target.value !== "gas"; f.querySelector("[data-neg-ayuda]").textContent = tipo(e.target.value)[3];
  });

  /* ---------- El puente con lo personal ---------- */
  function puente(x, negocio, quitar) {
    if (typeof movsGuardados !== "function") return;
    const id = "ng-" + x.id, l = movsGuardados(x.f).filter(y => y.id !== id);
    if (!quitar && x.t === "pag") l.push({ id, t: "ing", m: x.m, c: "negocio", n: `Pago de ${negocio}${x.n ? " · " + x.n : ""}` });
    guardarMovs(x.f, l);
  }
  const buscarMov = (a, id) => { for (const ym of mesesDe(a.id)) { const x = movsMes(a.id, ym).find(y => y.id === id); if (x) return { ym, x }; } return null; };
  const deshacerCon = (claves, msg) => { const antes = claves.map(k => [k, respuesta(k) || ""]);
    toast(msg, { accion: "Deshacer", alHacer: () => { antes.forEach(([k, v]) => responder(ASC.WB, k, v)); pintarDetalle(); } }); };

  Object.assign(ACC, {
    negElegir(el, id) { estado.negSel = id; pintarDetalle(); },
    negMes(el, d) { const ym = ymMas(mesVer(), Number(d)); if (ym > ymHoy()) return; estado.negMes = ym; pintarDetalle(); },
    negNuevo() { abrirHoja(formNegocio({})); },
    negEditar() { const a = actual(); if (a) abrirHoja(formNegocio(a)); },
    negBorrar(el, id) {
      const a = negocios().find(x => x.id === id); if (!a) return;
      const claves = [LISTA, claveBal(id), ...mesesDe(id).map(m => claveMes(id, m))]; deshacerCon(claves, `«${a.n}» borrado`);
      claves.slice(1).forEach(k => responder(ASC.WB, k, "")); guardarLista(negocios().filter(x => x.id !== id));
      estado.negSel = null; cerrarHoja(); pintarDetalle();
    },
    negMovNuevo(el, t) { if (!actual()) return ACC.negNuevo(); abrirHoja(formMov({ t: t || "ven" })); },
    negMovEditar(el, id) { const a = actual(), r = a && buscarMov(a, id); if (r) abrirHoja(formMov(r.x)); },
    negMovBorrar(el, id) {
      const a = actual(), r = a && buscarMov(a, id); if (!r) return;
      deshacerCon([claveMes(a.id, r.ym), claveMov(r.x.f)], "Movimiento borrado");
      guardarMes(a.id, r.ym, movsMes(a.id, r.ym).filter(y => y.id !== id)); puente(r.x, a.n, true); cerrarHoja(); pintarDetalle();
    },
    negBalNuevo(el, lado) { abrirHoja(formBal(lado, { k: lado === "a" ? "caja" : "proveedores" })); },
    negBalEditar(el, arg) { const a = actual(), [lado, id] = arg.split(":"), x = a && bal(a.id)[lado].find(y => y.id === id); if (x) abrirHoja(formBal(lado, x)); },
    negBalBorrar(el, arg) {
      const a = actual(), [lado, id] = arg.split(":"); if (!a) return; const b = bal(a.id);
      deshacerCon([claveBal(a.id)], lado === "a" ? "Activo borrado" : "Pasivo borrado");
      b[lado] = b[lado].filter(y => y.id !== id); guardarBal(a.id, b); cerrarHoja(); pintarDetalle();
    },
  });
  window.FORMULARIOS = Object.assign(window.FORMULARIOS || {}, {
    negocio(form, d) {
      const l = negocios(), id = form.dataset.arg, n = String(d.get("nombre") || "").trim().slice(0, 60), g = String(d.get("giro") || "").trim().slice(0, 80);
      if (!n) return;
      const x = { id: id || "n" + Date.now().toString(36), n, ...(g ? { g } : {}) }, i = l.findIndex(y => y.id === id);
      if (i >= 0) l[i] = x; else l.push(x);
      guardarLista(l); estado.negSel = x.id; cerrarHoja(); pintarDetalle(); toast(id ? "Negocio guardado" : `«${n}» listo: anota tu primera venta`);
    },
    negMov(form, d) {
      const a = actual(); if (!a) return;
      const m = Math.abs(montoFin(d.get("monto"))); if (!(m > 0)) return toast("Escribe el monto");
      const id = form.dataset.arg, t = String(d.get("tipo") || "ven"), f = String(d.get("fecha") || hoyIso()).slice(0, 10), n = String(d.get("nota") || "").trim();
      const x = { id: id || "v" + Date.now().toString(36), f, t, m, ...(t === "gas" ? { c: String(d.get("cat") || "otro") } : {}), ...(n ? { n } : {}) };
      const viejo = id && buscarMov(a, id);
      if (viejo) { guardarMes(a.id, viejo.ym, movsMes(a.id, viejo.ym).filter(y => y.id !== id)); puente(viejo.x, a.n, true); }
      const ym = f.slice(0, 7); guardarMes(a.id, ym, [...movsMes(a.id, ym), x]); puente(x, a.n, false);
      estado.negMes = ym; cerrarHoja(); pintarDetalle();
      toast(t === "pag" ? "Pago anotado: también entró a tus finanzas personales" : `${tipo(t)[1]} anotada`);
    },
    negBal(form, d) {
      const a = actual(); if (!a) return; const [lado, id] = String(form.dataset.arg).split(":"), b = bal(a.id);
      const x = { id: id || "b" + Date.now().toString(36), k: String(d.get("tipo") || "otro"), m: Math.abs(montoFin(d.get("monto"))) || 0 };
      const n = String(d.get("nombre") || "").trim().slice(0, 60); if (n) x.n = n;
      const i = b[lado].findIndex(y => y.id === id); if (i >= 0) b[lado][i] = x; else b[lado].push(x);
      guardarBal(a.id, b); cerrarHoja(); pintarDetalle();
    },
  });

  /* Demo: una panadería con tres meses de cuentas */
  if (location.hash === "#demo") {
    window.addEventListener("load", () => setTimeout(() => {
      if (negocios().length) return;
      const id = "ndemo"; guardarLista([{ id, n: "Panadería La Cima", g: "Pan, café y tortas por encargo" }]);
      [0, -1, -2].forEach(k => { const ym = ymMas(ymHoy(), k), d = n => `${ym}-${pad2(Math.min(n, k === 0 ? Number(hoyIso().slice(8)) : 28))}`;
        guardarMes(id, ym, [{ id: "d1" + k, f: d(3), t: "ven", m: 4200000 + k * 150000, n: "Ventas de mostrador" }, { id: "d2" + k, f: d(5), t: "cos", m: 1800000, n: "Harina, mantequilla y café" },
          { id: "d3" + k, f: d(1), t: "gas", m: 900000, c: "arriendo" }, { id: "d4" + k, f: d(10), t: "gas", m: 320000, c: "servicios" }, { id: "d5" + k, f: d(15), t: "gas", m: 600000, c: "nomina", n: "Ayudante" },
          { id: "d6" + k, f: d(20), t: "ven", m: 850000, n: "Tortas por encargo" }, ...(k === 0 ? [] : [{ id: "d7" + k, f: d(28), t: "pag", m: 1000000 }])]); });
      guardarBal(id, { a: [{ id: "a1", k: "caja", n: "Cuenta del negocio", m: 2300000 }, { id: "a2", k: "inventario", m: 600000 }, { id: "a3", k: "equipo", n: "Horno y vitrina", m: 9000000 }],
        p: [{ id: "p1", k: "proveedores", n: "Molino", m: 700000 }, { id: "p2", k: "largo", n: "Crédito del horno", m: 4500000 }] });
    }, 3000));
  }
})();

/** Mi negocio: dentro del Ascenso financiero, las cuentas de cada negocio aparte de las personales. */
DET["finanzas.negocio"] = () => (window.finBloqueado?.() ? pantallaBloqueo() : cab(avAsc(), "Mi negocio", "Las cuentas de tu negocio, aparte de tu plata personal", ojoAsc()) +
  cuerpo(negocioPagina(), "max-width:980px"));
