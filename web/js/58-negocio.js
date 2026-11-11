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

  /* ---------- Pintar: Mi negocio › año › mes › día (como el ascenso financiero personal) ---------- */
  const todos = id => mesesDe(id).flatMap(m => movsMes(id, m));
  const de = (id, pref) => pref.length >= 7 ? movsMes(id, pref.slice(0, 7)).filter(x => x.f.startsWith(pref)) : todos(id).filter(x => x.f.startsWith(pref));
  const ir = (lugar) => "negocio" + (lugar ? ":" + lugar : "");
  const selector = (l, a, lugar) => `<div class="neg-chips" role="tablist" aria-label="Tus negocios">${l.map(x =>
    `<button class="neg-chip" role="tab" aria-selected="${x.id === a.id}" data-acc="negElegir" data-arg="${x.id}">${ic("bolsa")}<span>${esc(x.n)}</span></button>`).join("")}
    <button class="neg-chip neg-mas" data-acc="negNuevo" aria-label="Agregar otro negocio">${ic("mas")}<span>Negocio</span></button></div>`;

  function resultados(s, titulo) {
    const fila = (n, v, cls = "") => `<li class="${cls}"><span>${n}</span><b class="${v < 0 ? "neg" : ""}">${plata(v)}</b></li>`;
    return `<ul class="neg-er" aria-label="${esc(titulo)}">
      ${fila("Ventas", s.ven)}${fila("− Costo de lo vendido", s.cos, "menos")}${fila("Utilidad bruta", s.bruta, "sub")}
      ${fila("− Gastos de operación", s.gas, "menos")}${fila(titulo, s.util, "total")}
      ${s.inv ? fila("− Inversión en el negocio", s.inv, "menos") : ""}${s.pag ? fila("− Pago a ti", s.pag, "menos") : ""}
      ${s.inv || s.pag ? fila("Queda en caja", s.caja, "sub") : ""}</ul>`;
  }
  /** Tabla de periodos (años, meses o días): cada fila abre su periodo. */
  function tabla(filas, col, total) {
    const c = v => `<td class="num${v < 0 ? " neg" : ""}">${v ? plata(v) : "—"}</td>`;
    return `<div class="asc-tabla"><table class="neg-per"><thead><tr><th>${col}</th><th class="num">Ventas</th><th class="num">Costos</th><th class="num">Gastos</th><th class="num">Utilidad</th></tr></thead><tbody>
      ${filas.map(({ etq, sel, s, actual }) => `<tr class="${actual ? "actual" : ""}${s.n ? "" : " vacia"}" data-sel="${sel}" tabindex="0" role="link" aria-label="Abrir ${esc(etq)}"><th scope="row">${esc(etq)}</th>${c(s.ven)}${c(s.cos)}${c(s.gas)}${c(s.util)}</tr>`).join("")}
      </tbody><tfoot><tr><th scope="row">Total</th>${c(total.ven)}${c(total.cos)}${c(total.gas)}${c(total.util)}</tr></tfoot></table></div>`;
  }
  /** Las barras de ventas y salidas por periodo (mismo dibujo que el personal). */
  function barras(filas) {
    const sal = s => s.cos + s.gas + s.inv + s.pag, max = Math.max(1, ...filas.flatMap(x => [x.s.ven, sal(x.s)]));
    if (!filas.some(x => x.s.n)) return ""; const W = 100 / filas.length;
    return `<div class="asc-graf" role="img" aria-label="Ventas y salidas por periodo">${filas.map(x => `<button class="asc-col" data-sel="${x.sel}" style="width:${W}%" title="${esc(x.etq)}: vendiste ${plata(x.s.ven)}, salió ${plata(sal(x.s))}">
      <span class="pila"><i class="b-ing" style="height:${(x.s.ven / max * 100).toFixed(1)}%"></i><i class="b-gas" style="height:${(sal(x.s) / max * 100).toFixed(1)}%"></i></span><small>${esc(x.corto)}</small></button>`).join("")}</div>
      <p class="asc-ley"><span><i class="b-ing"></i>Ventas</span><span><i class="b-gas"></i>Salió (costos, gastos, inversión y tu pago)</span></p>`;
  }
  /** El calendario del mes: cada día abre su registro; un punto si tiene movimientos. */
  function calendario(id, ym) {
    const [a, m] = ym.split("-").map(Number), hoy = hoyIso(), con = new Set(movsMes(id, ym).map(x => x.f));
    let h = ["L", "M", "X", "J", "V", "S", "D"].map(x => `<b aria-hidden="true">${x}</b>`).join("") + `<i></i>`.repeat((new Date(a, m - 1, 1).getDay() + 6) % 7);
    for (let d = 1; d <= new Date(a, m, 0).getDate(); d++) { const f = `${ym}-${pad2(d)}`;
      h += `<button class="neg-dia${f === hoy ? " hoy" : ""}${con.has(f) ? " con" : ""}" data-sel="${ir("d:" + f)}" ${f > hoy ? "disabled" : ""} aria-label="${d} de ${MESES[m - 1]}${con.has(f) ? ", con movimientos" : ""}">${d}</button>`; }
    return `<div class="neg-cal">${h}</div>`;
  }
  const cabeza = a => `<div class="cab-lista-btn neg-cab"><h3 style="margin:0">${esc(a.n)}${a.g ? `<small>${esc(a.g)}</small>` : ""}</h3>
    <button class="btn mini lleno" data-sel="${ir("d:" + hoyIso())}">${ic("mas")} Registrar hoy</button></div>`;

  function hojaBalance(id) {
    const b = bal(id), act = sumaK(b.a, null, ACTIVOS), pas = sumaK(b.p, null, PASIVOS);
    const col = (lado, l, tabla, total) => `<section><header><h4>${lado === "a" ? "Activos" : "Pasivos"}</h4><b>${plata(total)}</b></header>
      ${l.length ? `<ul class="neg-bal">${l.map(x => `<li><select data-acc-change="negBalCambia" data-arg="${lado}|${x.id}|k" aria-label="Tipo">${tabla.map(([v, n]) => `<option value="${v}" ${x.k === v ? "selected" : ""}>${n}</option>`).join("")}</select>
        <input value="${esc(x.n || "")}" maxlength="60" placeholder="Nombre" data-acc-change="negBalCambia" data-arg="${lado}|${x.id}|n" aria-label="Nombre">
        <input class="num" inputmode="decimal" value="${esc(numAsc(Number(x.m) || 0))}" data-acc-change="negBalCambia" data-arg="${lado}|${x.id}|m" aria-label="Valor">
        <button class="rb" data-acc="negBalBorrar" data-arg="${lado}:${x.id}" aria-label="Borrar" title="Borrar">${ic("borrar")}</button></li>`).join("")}</ul>`
        : `<p class="suave neg-vacio">${lado === "a" ? "Caja, lo que te deben, inventario, equipos…" : "Proveedores, créditos, impuestos por pagar…"}</p>`}
      <form class="neg-bal-nuevo" data-form="negBal" data-arg="${lado}:"><select name="tipo" aria-label="Tipo">${tabla.map(([v, n, c]) => `<option value="${v}">${n}${c ? (lado === "a" ? " · a la mano" : " · este año") : ""}</option>`).join("")}</select>
        <input name="monto" inputmode="decimal" autocomplete="off" required placeholder="${plata(0)}" aria-label="${lado === "a" ? "Cuánto vale hoy" : "Cuánto debe hoy"}">
        <button class="btn mini" type="submit">${ic("mas")} ${lado === "a" ? "Activo" : "Pasivo"}</button></form></section>`;
    return hoja(`<div class="cab-lista-btn"><h3 style="margin:0">${ic("flechasVert")} Lo que tiene y lo que debe</h3></div>
      <div class="neg-bal-col">${col("a", b.a, ACTIVOS, act)}${col("p", b.p, PASIVOS, pas)}</div>
      ${act || pas ? `<p class="neg-patr">Patrimonio del negocio <b class="${act - pas < 0 ? "neg" : ""}">${plata(act - pas)}</b></p>` : ""}`, "neg-hoja");
  }
  function hojaSalud(id, ym) {
    const r = indicadores(id, ym); if (!r.ind.length) return "";
    return hoja(`<div class="cab-lista-btn"><h3 style="margin:0">${ic("salud")} Salud del negocio</h3><small class="suave">Últimos ${r.n === 1 ? "mes" : r.n + " meses"}</small></div>
      <div class="medidores neg-meds">${r.ind.map(medidor).join("")}</div>
      <p class="suave neg-nota">No cuentan en tu Salud financiera personal. Lo que te pagas sí: llega como ingreso de tus finanzas.</p>`, "neg-hoja");
  }
  const formNegocio = (x = {}) => `<form class="form neg-form-neg" data-form="negocio" data-arg="${x.id || ""}">
      <div class="hito-fila"><label class="campo"><span>Nombre</span><input name="nombre" maxlength="60" required value="${esc(x.n || "")}" placeholder="Panadería La Cima, Diseño freelance…"></label>
      <label class="campo"><span>¿A qué se dedica? (opcional)</span><input name="giro" maxlength="80" value="${esc(x.g || "")}" placeholder="Venta de pan y café"></label></div>
      <div class="botones">${x.id ? `<button type="button" class="btn" data-acc="negBorrar" data-arg="${x.id}" style="margin-right:auto">${ic("borrar")} Borrar negocio</button>` : estado.negCreando && negocios().length ? `<button type="button" class="btn" data-acc="negNuevo" data-arg="no">Cancelar</button>` : ""}<button class="btn lleno">${x.id ? "Guardar" : "Crear negocio"}</button></div></form>`;

  /** El día: anotar en la misma página (como en las finanzas personales) y la tabla del día, editable. */
  function dia(a, f) {
    const t = estado.negTipo || "ven", movs = de(a.id, f), s = cifras(movs), ym = f.slice(0, 7), mes = cifras(movsMes(a.id, ym)), d = deIso(f);
    const cats = CAT_GAS.map(([v, n]) => `<option value="${v}">${n}</option>`).join("");
    return hoja(`<form class="asc-nuevo asc-compacto neg-nuevo" data-form="negMov" data-arg="${f}">
        <div class="seg neg-seg" role="radiogroup" aria-label="Tipo de movimiento">${TIPOS.map(([k, n]) => `<button type="button" role="radio" aria-checked="${t === k}" class="seg-b nt-${k}" data-acc="negTipo" data-arg="${k}">${n}</button>`).join("")}</div>
        <p class="suave neg-ayuda">${tipo(t)[3]}</p>
        <div class="neg-fila-nueva${t === "gas" ? " con-cat" : ""}">
          <label class="campo"><span>Monto</span><input name="monto" inputmode="decimal" autocomplete="off" placeholder="${plata(0)}" required aria-label="Monto"></label>
          ${t === "gas" ? `<label class="campo"><span>Categoría</span><select name="cat">${cats}</select></label>` : ""}
          <label class="campo"><span>Concepto</span><input name="nota" maxlength="120" autocomplete="off" placeholder="${{ ven: "Ventas de mostrador", cos: "Mercancía del proveedor", gas: "Arriendo del local", inv: "Horno nuevo", pag: "Mi sueldo de la quincena" }[t]}"></label>
          <button class="btn lleno asc-agregar" type="submit" aria-label="Agregar">${ic("mas")}<span>Agregar</span></button>
        </div></form>
      <div class="asc-tabla"><table class="neg-movs-t"><thead><tr><th>Tipo</th><th>Categoría</th><th>Concepto</th><th class="num">Monto</th><th><span class="oculto">Acciones</span></th></tr></thead><tbody>
        ${movs.length ? movs.map(x => `<tr class="nt-${x.t}">
          <td><select data-acc-change="negCambia" data-arg="${x.id}|t" aria-label="Tipo">${TIPOS.map(([k, n]) => `<option value="${k}" ${k === x.t ? "selected" : ""}>${n}</option>`).join("")}</select></td>
          <td>${x.t === "gas" ? `<select data-acc-change="negCambia" data-arg="${x.id}|c" aria-label="Categoría">${CAT_GAS.map(([v, n]) => `<option value="${v}" ${v === (x.c || "otro") ? "selected" : ""}>${n}</option>`).join("")}</select>` : `<span class="suave">—</span>`}</td>
          <td><input value="${esc(x.n || "")}" maxlength="120" placeholder="Concepto" data-acc-change="negCambia" data-arg="${x.id}|n" aria-label="Concepto"></td>
          <td class="num"><input class="num" inputmode="decimal" value="${esc(numAsc(x.m))}" data-acc-change="negCambia" data-arg="${x.id}|m" aria-label="Monto"></td>
          <td class="acc-mov"><button class="rb" data-acc="negMovBorrar" data-arg="${x.id}" aria-label="Borrar" title="Borrar">${ic("borrar")}</button></td></tr>`).join("")
          : `<tr><td colspan="5" class="suave" style="padding:14px">Aún no hay movimientos este día. Anota el primero arriba: el tipo, el monto y listo.</td></tr>`}
      </tbody>${movs.length ? `<tfoot><tr><th colspan="3" scope="row">Utilidad del día</th><td class="num ${s.util < 0 ? "neg" : ""}">${plata(s.util)}</td><td></td></tr></tfoot>` : ""}</table></div>`, "neg-hoja") +
      (movs.length ? hoja(resultados(s, "Utilidad del día"), "neg-hoja") : "") +
      `<button class="hoja asc-sube" data-sel="${ir("m:" + ym)}"><span>Así va ${MESES[d.getMonth()]}</span><b class="${mes.util < 0 ? "neg" : ""}">${plata(mes.util)} de utilidad</b><small>Vendiste ${plata(mes.ven)} · salió ${plata(mes.cos + mes.gas + mes.inv + mes.pag)}</small>${ic("der")}</button>`;
  }

  /** La página según el lugar: "" (todos los años), "a:2026", "m:2026-11" o "d:2026-11-10". Devuelve { titulo, sub, nav, html }. */
  window.negocioVista = lugar => {
    const l = negocios(), a = actual();
    if (!a || estado.negCreando) return { titulo: "Mi negocio", sub: "Las cuentas de tu negocio, aparte de tu plata personal", nav: "",
      html: (a ? selector(l, a) : "") + hoja(`<div class="neg-bienvenida">${ic("bolsa")}<h3>${a ? "Otro negocio" : "¿Tienes un negocio?"}</h3>
        <p class="suave">Lleva sus cuentas aquí, aparte de tu plata personal: lo que vendes, lo que cuesta, lo que queda y lo que te pagas. Puedes llevar varios.</p></div>${formNegocio()}`, "neg-hoja") };
    const [t, v] = (lugar || "").split(/:(.*)/s), hoy = hoyIso(), aHoy = Number(hoy.slice(0, 4));
    const migas = partes => migasAsc([["Mi negocio", ir("")], ...partes]);
    if (t === "d" && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
      const d = deIso(v), A = d.getFullYear(), M = d.getMonth() + 1, ym = v.slice(0, 7);
      return { titulo: `${d.getDate()} de ${MESES[M - 1]}`, sub: `${esc(a.n)} · ${mayus(d.toLocaleDateString("es", { weekday: "long" }))} ${A}`,
        nav: navPeriodo(ir("d:" + sumarDias(v, -1)), ir("d:" + (v < hoy ? sumarDias(v, 1) : v)), `${d.getDate()} ${MES_C[M - 1]} ${A}`),
        html: selector(l, a) + migas([[String(A), ir("a:" + A)], [mayus(MESES[M - 1]), ir("m:" + ym)], [String(d.getDate()), ""]]) + dia(a, v) };
    }
    if (t === "m" && /^\d{4}-\d{2}$/.test(v)) {
      const [A, M] = v.split("-").map(Number), movs = movsMes(a.id, v), s = cifras(movs);
      const dias = [...new Set([...movs.map(x => x.f), ...(hoy.startsWith(v) ? [hoy] : [])])].sort();
      const filas = dias.map(f => { const d = deIso(f); return { etq: `${d.getDate()} · ${d.toLocaleDateString("es", { weekday: "short" })}`, corto: String(d.getDate()), sel: ir("d:" + f), s: Object.assign(cifras(de(a.id, f)), { n: de(a.id, f).length }), actual: f === hoy }; });
      return { titulo: `${mayus(MESES[M - 1])} ${A}`, sub: `${esc(a.n)} · el mes día a día`, nav: navPeriodo(ir("m:" + ymMas(v, -1)), ir("m:" + (v < ymHoy() ? ymMas(v, 1) : v)), `${mayus(MESES[M - 1])} ${A}`),
        html: selector(l, a) + migas([[String(A), ir("a:" + A)], [mayus(MESES[M - 1]), ""]]) +
          hoja(cabeza(a) + (movs.length ? resultados(s, "Utilidad del mes") : `<p class="suave neg-vacio">Nada anotado en ${MESES[M - 1]}. Toca un día para anotar tus ventas, costos y gastos.</p>`), "neg-hoja") +
          hoja(`<div class="cab-lista-btn"><h3 style="margin:0">Día a día</h3><span class="suave" style="font-size:13px">Toca un día para anotar o ver</span></div>${calendario(a.id, v)}${filas.length ? barras(filas) + tabla(filas, "Día", s) : ""}`, "neg-hoja") +
          hojaSalud(a.id, v) };
    }
    if (t === "a" && /^\d{4}$/.test(v)) {
      const A = Number(v), filas = [...Array(12).keys()].map(i => { const ym = `${A}-${pad2(i + 1)}`, xs = movsMes(a.id, ym); return { etq: mayus(MESES[i]), corto: MES_C[i], sel: ir("m:" + ym), s: Object.assign(cifras(xs), { n: xs.length }), actual: ym === ymHoy() }; });
      const s = cifras(de(a.id, String(A)));
      return { titulo: String(A), sub: `${esc(a.n)} · el año mes a mes`, nav: navPeriodo(ir("a:" + (A - 1)), ir("a:" + Math.min(aHoy, A + 1)), String(A)),
        html: selector(l, a) + migas([[String(A), ""]]) + hoja(cabeza(a) + resultados(s, `Utilidad de ${A}`), "neg-hoja") +
          hoja(`<div class="cab-lista-btn"><h3 style="margin:0">Mes a mes</h3><span class="suave" style="font-size:13px">Toca un mes para ver sus días</span></div>${barras(filas)}${tabla(filas, "Mes", s)}`, "neg-hoja") };
    }
    // Todos los años
    const xs = todos(a.id), anios = [...new Set([...xs.map(x => Number(x.f.slice(0, 4))), aHoy])].sort();
    const filas = anios.map(A => { const ys = xs.filter(x => x.f.startsWith(A + "-")); return { etq: String(A), corto: String(A), sel: ir("a:" + A), s: Object.assign(cifras(ys), { n: ys.length }), actual: A === aHoy }; });
    const rapido = `<div class="neg-rapido" role="group" aria-label="Anotar hoy">${TIPOS.map(([k, n, i]) => `<button class="neg-rap t-${k}" data-acc="negIrTipo" data-arg="${k}">${ic(i)}<span>${n}</span></button>`).join("")}</div>`;
    return { titulo: "Mi negocio", sub: "Las cuentas de tu negocio, aparte de tu plata personal", nav: "",
      html: selector(l, a) + migas([]).replace(/<button[^>]*>Mi negocio<\/button> › /, "") +
        hoja(cabeza(a) + rapido + (xs.length ? resultados(cifras(xs), "Utilidad de todos los años") : `<p class="suave neg-vacio">Empieza por hoy: toca «Venta» y anota lo que vendiste. Cada día suma al mes y cada mes al año.</p>`), "neg-hoja") +
        (xs.length ? hoja(`<div class="cab-lista-btn"><h3 style="margin:0">Año por año</h3><span class="suave" style="font-size:13px">Toca un año para ver sus meses</span></div>${anios.length > 1 ? barras(filas) : ""}${tabla(filas, "Año", cifras(xs))}`, "neg-hoja") : "") +
        hojaSalud(a.id, ymHoy()) + hojaBalance(a.id) +
        hoja(`<details class="neg-ajustes"><summary>${ic("editar")} Ajustes de «${esc(a.n)}»</summary>${formNegocio(a)}
          <p class="suave neg-nota">Borrar el negocio borra sus movimientos y su balance. Los pagos que te hiciste se quedan en tus finanzas personales.</p></details>`, "neg-hoja") };
  };

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
  const foco = () => setTimeout(() => document.querySelector('.neg-nuevo [name="monto"]')?.focus(), 50);

  Object.assign(ACC, {
    negElegir(el, id) { estado.negSel = id; estado.negCreando = false; pintarDetalle(); },
    negNuevo(el, arg) { estado.negCreando = arg !== "no"; pintarDetalle(); },
    negTipo(el, t) { estado.negTipo = t; pintarDetalle(); foco(); },
    negIrTipo(el, t) { estado.negTipo = t; elegir(ir("d:" + hoyIso())); foco(); },
    negBorrar(el, id) {
      const a = negocios().find(x => x.id === id); if (!a) return;
      const claves = [LISTA, claveBal(id), ...mesesDe(id).map(m => claveMes(id, m))]; deshacerCon(claves, `«${a.n}» borrado`);
      claves.slice(1).forEach(k => responder(ASC.WB, k, "")); guardarLista(negocios().filter(x => x.id !== id));
      estado.negSel = null; elegir(ir(""));
    },
    negCambia(el, arg) {
      const a = actual(), [id, campo] = arg.split("|"), r = a && buscarMov(a, id); if (!r) return;
      const x = { ...r.x }, v = el.value;
      if (campo === "m") { const m = Math.abs(montoFin(v)); if (!(m > 0)) { el.value = numAsc(r.x.m); return toast("Escribe el monto"); } x.m = m; }
      else if (campo === "n") { const n = v.trim().slice(0, 120); if (n) x.n = n; else delete x.n; }
      else if (campo === "c") x.c = v;
      else if (campo === "t") { x.t = v; if (v === "gas") x.c = x.c || "otro"; else delete x.c; }
      guardarMes(a.id, r.ym, movsMes(a.id, r.ym).map(y => y.id === id ? x : y)); puente(r.x, a.n, true); puente(x, a.n, false);
      if (campo === "t") pintarDetalle();
    },
    negMovBorrar(el, id) {
      const a = actual(), r = a && buscarMov(a, id); if (!r) return;
      deshacerCon([claveMes(a.id, r.ym), claveMov(r.x.f)], "Movimiento borrado");
      guardarMes(a.id, r.ym, movsMes(a.id, r.ym).filter(y => y.id !== id)); puente(r.x, a.n, true); pintarDetalle();
    },
    negBalCambia(el, arg) {
      const a = actual(), [lado, id, campo] = arg.split("|"); if (!a) return; const b = bal(a.id), x = b[lado].find(y => y.id === id); if (!x) return;
      if (campo === "m") x.m = Math.abs(montoFin(el.value)) || 0; else if (campo === "k") x.k = el.value;
      else { const n = el.value.trim().slice(0, 60); if (n) x.n = n; else delete x.n; }
      guardarBal(a.id, b); if (campo !== "n") pintarDetalle();
    },
    negBalBorrar(el, arg) {
      const a = actual(), [lado, id] = arg.split(":"); if (!a) return; const b = bal(a.id);
      deshacerCon([claveBal(a.id)], lado === "a" ? "Activo borrado" : "Pasivo borrado");
      b[lado] = b[lado].filter(y => y.id !== id); guardarBal(a.id, b); pintarDetalle();
    },
  });
  window.FORMULARIOS = Object.assign(window.FORMULARIOS || {}, {
    negocio(form, d) {
      const l = negocios(), id = form.dataset.arg, n = String(d.get("nombre") || "").trim().slice(0, 60), g = String(d.get("giro") || "").trim().slice(0, 80);
      if (!n) return;
      const x = { id: id || "n" + Date.now().toString(36), n, ...(g ? { g } : {}) }, i = l.findIndex(y => y.id === id);
      if (i >= 0) l[i] = x; else l.push(x);
      guardarLista(l); estado.negSel = x.id; estado.negCreando = false; pintarDetalle(); toast(id ? "Negocio guardado" : `«${n}» listo: anota tu primera venta`);
    },
    negMov(form, d) {
      const a = actual(); if (!a) return;
      const m = Math.abs(montoFin(d.get("monto"))); if (!(m > 0)) { toast("Escribe el monto"); return foco(); }
      const f = form.dataset.arg, t = estado.negTipo || "ven", n = String(d.get("nota") || "").trim();
      const x = { id: "v" + Date.now().toString(36), f, t, m, ...(t === "gas" ? { c: String(d.get("cat") || "otro") } : {}), ...(n ? { n } : {}) };
      const ym = f.slice(0, 7); guardarMes(a.id, ym, [...movsMes(a.id, ym), x]); puente(x, a.n, false);
      pintarDetalle(); foco();
      toast(t === "pag" ? "Pago anotado: también entró a tus finanzas personales" : `${tipo(t)[1]} de ${plata(m)} ${t === "ven" || t === "inv" ? "anotada" : "anotado"}`);
    },
    negBal(form, d) {
      const a = actual(); if (!a) return; const lado = String(form.dataset.arg).split(":")[0], b = bal(a.id);
      const m = Math.abs(montoFin(d.get("monto"))); if (!(m > 0)) return toast("Escribe el valor");
      b[lado].push({ id: "b" + Date.now().toString(36), k: String(d.get("tipo") || "otro"), m });
      guardarBal(a.id, b); pintarDetalle();
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
DET["finanzas.negocio"] = lugar => { if (window.finBloqueado?.()) return pantallaBloqueo();
  const v = negocioVista(lugar); return cab(avAsc(), v.titulo, v.sub, v.nav + ojoAsc()) + cuerpo(v.html, "max-width:980px"); };
