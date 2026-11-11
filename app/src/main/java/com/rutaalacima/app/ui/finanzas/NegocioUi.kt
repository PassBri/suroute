package com.rutaalacima.app.ui.finanzas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rutaalacima.app.R
import com.rutaalacima.app.domain.model.Finanzas
import com.rutaalacima.app.domain.model.Negocio
import com.rutaalacima.app.ui.components.RutaCard
import com.rutaalacima.app.ui.planner.nombreMes
import com.rutaalacima.app.ui.theme.AvisoGlobal
import com.rutaalacima.app.util.hoy
import java.time.LocalDate
import java.time.YearMonth

/* Mi negocio (igual que la web, web/js/58-negocio.js): las cuentas de cada negocio, aparte de las personales. */

private fun iconoTipo(t: String): ImageVector = when (t) {
    "ven" -> Icons.Filled.AttachMoney; "cos" -> Icons.Filled.ShoppingBag; "gas" -> Icons.AutoMirrored.Filled.ReceiptLong
    "inv" -> Icons.AutoMirrored.Filled.TrendingUp; else -> Icons.Filled.AccountCircle
}
@Composable private fun nombreTipo(t: String) = stringResource(when (t) { "ven" -> R.string.ng_t_ven; "cos" -> R.string.ng_t_cos; "gas" -> R.string.ng_t_gas; "inv" -> R.string.ng_t_inv; else -> R.string.ng_t_pag })
@Composable private fun ayudaTipo(t: String) = stringResource(when (t) { "ven" -> R.string.ng_a_ven; "cos" -> R.string.ng_a_cos; "gas" -> R.string.ng_a_gas; "inv" -> R.string.ng_a_inv; else -> R.string.ng_a_pag })
@Composable private fun nombreCat(c: String?) = stringResource(when (c) {
    "arriendo" -> R.string.ng_c_arriendo; "servicios" -> R.string.ng_c_servicios; "nomina" -> R.string.ng_c_nomina; "publicidad" -> R.string.ng_c_publicidad
    "transporte" -> R.string.ng_c_transporte; "impuestos" -> R.string.ng_c_impuestos; "bancos" -> R.string.ng_c_bancos; else -> R.string.ng_otro })
@Composable private fun nombrePartida(k: String) = stringResource(when (k) {
    "caja" -> R.string.ng_k_caja; "cobrar" -> R.string.ng_k_cobrar; "inventario" -> R.string.ng_k_inventario; "equipo" -> R.string.ng_k_equipo; "local" -> R.string.ng_k_local
    "proveedores" -> R.string.ng_k_proveedores; "corto" -> R.string.ng_k_corto; "impuestos" -> R.string.ng_k_impuestos; "largo" -> R.string.ng_k_largo; else -> R.string.ng_otro })
private fun texto(m: Double) = if (m == 0.0) "" else if (m % 1.0 == 0.0) m.toLong().toString() else m.toString()
private fun nuevoId(p: String) = p + System.currentTimeMillis().toString(36)

/** La página «Mi negocio» por niveles, como el ascenso personal: todos los años › año › mes › día.
 *  [lugar]: "" · "a:2026" · "m:2026-11" · "d:2026-11-10". En el día se anota en la misma página. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun NegocioPantalla(libro: Libro, plata: (Double) -> String, vm: CuentasViewModel) {
    val r = libro.respuestas; val lista = Negocio.lista(r)
    var sel by rememberSaveable { mutableStateOf<String?>(null) }
    var lugar by rememberSaveable { mutableStateOf("") }
    var dlgNeg by rememberSaveable { mutableStateOf<String?>(null) }      // "nuevo" o el id
    var dlgMov by rememberSaveable { mutableStateOf<String?>(null) }      // id del movimiento a editar
    var dlgBal by rememberSaveable { mutableStateOf<String?>(null) }      // "a:" / "p:" + id (vacío = nuevo)
    var tipo by rememberSaveable { mutableStateOf("ven") }
    val a = lista.firstOrNull { it.id == sel } ?: lista.firstOrNull()
    val hoyF = hoy(); val ymHoy = YearMonth.from(hoyF)
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        if (a == null) {
            RutaCard {
                Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(64.dp).clip(CircleShape).background(MaterialTheme.colorScheme.secondaryContainer), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.ShoppingBag, null, Modifier.size(32.dp), tint = MaterialTheme.colorScheme.primary) }
                    Text(stringResource(R.string.ng_bienvenida_t), Modifier.padding(top = 12.dp), style = MaterialTheme.typography.titleLarge, fontFamily = FontFamily.Serif)
                    Text(stringResource(R.string.ng_bienvenida), Modifier.padding(vertical = 8.dp), style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
                    Button(onClick = { dlgNeg = "nuevo" }) { Icon(Icons.Filled.Add, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.ng_crear)) }
                }
            }
        } else {
            val (t, v) = lugar.split(":", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
            val todos = Negocio.meses(r, a.id).flatMap { Negocio.movs(r, a.id, it) }
            fun de(pref: String) = if (pref.length >= 7) Negocio.movs(r, a.id, pref.take(7)).filter { it.f.startsWith(pref) } else todos.filter { it.f.startsWith(pref) }
            // Los negocios: uno por chip, y «+ Negocio»
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                lista.forEach { x -> FilterChip(selected = x.id == a.id, onClick = { sel = x.id }, label = { Text(x.n) }, leadingIcon = { Icon(Icons.Filled.ShoppingBag, null, Modifier.size(18.dp)) }) }
                androidx.compose.material3.AssistChip(onClick = { dlgNeg = "nuevo" }, label = { Text(stringResource(R.string.ng_negocio)) }, leadingIcon = { Icon(Icons.Filled.Add, null, Modifier.size(18.dp)) })
            }
            // Migas y ‹ periodo ›
            val dia = if (t == "d") runCatching { LocalDate.parse(v) }.getOrNull() else null
            val mes = if (t == "m") runCatching { YearMonth.parse(v) }.getOrNull() else null
            val anio = if (t == "a") v.toIntOrNull() else null
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), verticalAlignment = Alignment.CenterVertically) {
                @Composable fun miga(txt: String, l: String?) = if (l == null) Text(txt, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                    else { TextButton(onClick = { lugar = l }) { Text(txt) }; Text("›", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                val y = dia?.year ?: mes?.year ?: anio
                miga(stringResource(R.string.ng_titulo), if (lugar.isEmpty()) null else "")
                if (y != null) miga("$y", if (anio != null) null else "a:$y")
                val m = dia?.let { YearMonth.from(it) } ?: mes
                if (m != null) miga(nombreMes(m.monthValue), if (mes != null) null else "m:$m")
                if (dia != null) miga("${dia.dayOfMonth}", null)
            }
            if (dia != null || mes != null || anio != null) Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                val (titulo, antes, despues) = when {
                    dia != null -> Triple(dia.format(java.time.format.DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.FULL)), "d:${dia.minusDays(1)}", if (dia < hoyF) "d:${dia.plusDays(1)}" else null)
                    mes != null -> Triple("${nombreMes(mes.monthValue)} ${mes.year}", "m:${mes.minusMonths(1)}", if (mes < ymHoy) "m:${mes.plusMonths(1)}" else null)
                    else -> Triple("$anio", "a:${anio!! - 1}", if (anio < hoyF.year) "a:${anio + 1}" else null)
                }
                IconButton(onClick = { lugar = antes }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.ng_mes_ant)) }
                Text(titulo, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, fontFamily = FontFamily.Serif, textAlign = TextAlign.Center)
                IconButton(onClick = { despues?.let { lugar = it } }, enabled = despues != null) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.ng_mes_sig)) }
            }

            when {
                dia != null -> {
                    val f = dia.toString(); val movs = de(f)
                    RutaCard {
                        // Anotar en la misma página, como en las finanzas personales
                        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Negocio.TIPOS.forEach { k -> FilterChip(selected = tipo == k, onClick = { tipo = k }, label = { Text(nombreTipo(k)) }, leadingIcon = { Icon(iconoTipo(k), null, Modifier.size(18.dp)) }) }
                        }
                        Text(ayudaTipo(tipo), Modifier.padding(vertical = 4.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        var m by rememberSaveable(f) { mutableStateOf("") }
                        var n by rememberSaveable(f) { mutableStateOf("") }
                        var c by rememberSaveable { mutableStateOf("otro") }
                        val monto = kotlin.math.abs(Finanzas.monto(m))
                        val notaPago = stringResource(R.string.ng_pago_de, a.n); val avisoPago = stringResource(R.string.ng_pago_ok)
                        val agregar = {
                            if (monto > 0) {
                                val x = Negocio.Mov(nuevoId("v"), f, tipo, monto, if (tipo == "gas") c else null, n.trim().ifBlank { null })
                                vm.negMov(a.id, null, x, notaPago + (x.n?.let { " · $it" } ?: "")); m = ""; n = ""
                                if (tipo == "pag") AvisoGlobal.mostrar(avisoPago)
                            }
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(m, { m = it.filter { ch -> ch.isDigit() || ch == '.' || ch == ',' }.take(15) }, label = { Text(stringResource(R.string.ng_monto)) }, singleLine = true,
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                            Button(onClick = agregar, enabled = monto > 0, modifier = Modifier.padding(top = 6.dp).heightIn(min = 48.dp)) {
                                Icon(Icons.Filled.Add, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text(stringResource(R.string.ng_agregar)) }
                        }
                        if (tipo == "gas") FlowRow(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Negocio.CAT_GAS.forEach { k -> FilterChip(selected = c == k, onClick = { c = k }, label = { Text(nombreCat(k)) }) }
                        }
                        OutlinedTextField(n, { n = it.take(120) }, label = { Text(stringResource(R.string.ng_concepto)) }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(top = 4.dp))
                        // Lo del día
                        if (movs.isEmpty()) Text(stringResource(R.string.ng_vacio_dia), Modifier.padding(top = 12.dp), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        else {
                            Spacer(Modifier.height(10.dp))
                            movs.forEach { x -> FilaMovNeg(x, plata, onEditar = { dlgMov = x.id }, onBorrar = { vm.negMov(a.id, x, null, "") }) }
                            FilaCifra(stringResource(R.string.ng_util_dia), Negocio.cifras(movs).util, plata, total = true)
                        }
                    }
                    if (movs.isNotEmpty()) RutaCard { Resultados(Negocio.cifras(movs), stringResource(R.string.ng_util_dia), plata) }
                    val ym = YearMonth.from(dia); val sm = Negocio.cifras(Negocio.movs(r, a.id, ym.toString()))
                    RutaCard(onClick = { lugar = "m:$ym" }) {
                        Text(stringResource(R.string.ng_asi_va, nombreMes(ym.monthValue)), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(stringResource(R.string.ng_de_utilidad, plata(sm.util)), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                            color = if (sm.util < 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                    }
                }
                mes != null -> {
                    val movs = Negocio.movs(r, a.id, mes.toString()); val s = Negocio.cifras(movs)
                    RutaCard {
                        Cabeza(a, onHoy = { lugar = "d:$hoyF" })
                        if (movs.isEmpty()) Text(stringResource(R.string.ng_vacio_mes, nombreMes(mes.monthValue)), Modifier.padding(top = 8.dp), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        else Resultados(s, stringResource(R.string.ng_er_util), plata)
                    }
                    RutaCard {
                        Text(stringResource(R.string.ng_dia_a_dia), style = MaterialTheme.typography.titleMedium)
                        CalendarioNeg(mes, movs.map { it.f }.toSet(), hoyF) { lugar = "d:$it" }
                        movs.groupBy { it.f }.toSortedMap().forEach { (f, xs) ->
                            val d = LocalDate.parse(f)
                            FilaPeriodo("${d.dayOfMonth} · ${d.dayOfWeek.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.getDefault())}", Negocio.cifras(xs), plata) { lugar = "d:$f" }
                        }
                    }
                    SaludNeg(r, a.id, mes, plata)
                }
                anio != null -> {
                    val s = Negocio.cifras(de("$anio"))
                    RutaCard { Cabeza(a, onHoy = { lugar = "d:$hoyF" }); Resultados(s, stringResource(R.string.ng_util_anio, anio), plata) }
                    RutaCard {
                        Text(stringResource(R.string.ng_mes_a_mes), style = MaterialTheme.typography.titleMedium)
                        (1..12).forEach { k -> val ym = YearMonth.of(anio, k)
                            FilaPeriodo(nombreMes(k), Negocio.cifras(Negocio.movs(r, a.id, ym.toString())), plata, actual = ym == ymHoy) { lugar = "m:$ym" } }
                    }
                }
                else -> {
                    RutaCard {
                        Cabeza(a, onHoy = { lugar = "d:$hoyF" })
                        // Anotar hoy: un toque por tipo
                        Row(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Negocio.TIPOS.forEach { k ->
                                Column(Modifier.weight(1f).heightIn(min = 64.dp).clip(RoundedCornerShape(14.dp)).border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(14.dp))
                                    .clickable(role = Role.Button) { tipo = k; lugar = "d:$hoyF" }.padding(vertical = 10.dp, horizontal = 2.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(iconoTipo(k), null, Modifier.size(22.dp), tint = if (k == "ven") ST_OK else MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(nombreTipo(k), Modifier.padding(top = 4.dp), style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                }
                            }
                        }
                        if (todos.isEmpty()) Text(stringResource(R.string.ng_empieza), Modifier.padding(top = 10.dp), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        else Resultados(Negocio.cifras(todos), stringResource(R.string.ng_util_todo), plata)
                    }
                    if (todos.isNotEmpty()) RutaCard {
                        Text(stringResource(R.string.ng_anio_a_anio), style = MaterialTheme.typography.titleMedium)
                        (todos.map { it.f.take(4).toInt() } + hoyF.year).distinct().sorted().forEach { y ->
                            FilaPeriodo("$y", Negocio.cifras(todos.filter { it.f.startsWith("$y-") }), plata, actual = y == hoyF.year) { lugar = "a:$y" } }
                    }
                    SaludNeg(r, a.id, ymHoy, plata)
                    BalanceNeg(Negocio.bal(r, a.id), plata) { dlgBal = it }
                    TextButton(onClick = { dlgNeg = a.id }) { Icon(Icons.Filled.Edit, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.ng_ajustes)) }
                }
            }

            // Editar un movimiento (anotar es en la página) y el balance
            dlgMov?.let { e ->
                val viejo = Negocio.meses(r, a.id).asReversed().firstNotNullOfOrNull { m -> Negocio.movs(r, a.id, m).firstOrNull { it.id == e } }
                if (viejo != null) {
                    val notaPago = stringResource(R.string.ng_pago_de, a.n)
                    DialogoMovNeg(viejo, viejo.t, a.n, viejo.f,
                        onGuardar = { x -> vm.negMov(a.id, viejo, x, notaPago + (x.n?.let { " · $it" } ?: "")); dlgMov = null },
                        onBorrar = { vm.negMov(a.id, viejo, null, ""); dlgMov = null }, onCerrar = { dlgMov = null })
                }
            }
            dlgBal?.let { e ->
                val b = Negocio.bal(r, a.id)
                val (lado, id) = e.split(":", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
                val l = if (lado == "a") b.a else b.p
                val x = l.firstOrNull { it.id == id } ?: Negocio.Partida(nuevoId("b"), if (lado == "a") "caja" else "proveedores")
                DialogoPartida(lado, x, nuevo = id.isEmpty(),
                    onGuardar = { y -> val nl = if (l.any { it.id == y.id }) l.map { if (it.id == y.id) y else it } else l + y
                        vm.negBal(a.id, if (lado == "a") b.copy(a = nl) else b.copy(p = nl)); dlgBal = null },
                    onBorrar = { val nl = l.filter { it.id != x.id }; vm.negBal(a.id, if (lado == "a") b.copy(a = nl) else b.copy(p = nl)); dlgBal = null },
                    onCerrar = { dlgBal = null })
            }
        }
    }
    dlgNeg?.let { e ->
        val x = lista.firstOrNull { it.id == e }
        DialogoNegocio(x, onGuardar = { n, g -> val y = Negocio.Neg(x?.id ?: nuevoId("n"), n, g)
                vm.negLista(if (x != null) lista.map { if (it.id == y.id) y else it } else lista + y); sel = y.id; dlgNeg = null },
            onBorrar = { x?.let { vm.negBorrar(it.id) }; sel = null; lugar = ""; dlgNeg = null }, onCerrar = { dlgNeg = null })
    }
}

@Composable
private fun Cabeza(a: Negocio.Neg, onHoy: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(a.n, style = MaterialTheme.typography.titleMedium)
            a.g?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        Button(onClick = onHoy) { Icon(Icons.Filled.Add, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text(stringResource(R.string.ng_registrar_hoy)) }
    }
}

@Composable
private fun FilaCifra(nombre: String, v: Double, plata: (Double) -> String, fuerte: Boolean = false, menos: Boolean = false, total: Boolean = false) {
    if (total) HorizontalDivider(thickness = 2.dp, color = MaterialTheme.colorScheme.onSurface)
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp)) {
        val estilo = if (total) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyMedium
        val color = if (menos) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
        Text(nombre, Modifier.weight(1f), style = estilo, color = color, fontWeight = if (fuerte || total) FontWeight.SemiBold else null)
        Text(plata(v), style = estilo, fontWeight = if (menos) FontWeight.Medium else FontWeight.Bold, color = if (!menos && v < 0) MaterialTheme.colorScheme.primary else color)
    }
    if (!total) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}

/** Estado de resultados: ventas − costos = bruta − gastos = utilidad (y lo que queda en caja). */
@Composable
private fun Resultados(s: Negocio.Cifras, titulo: String, plata: (Double) -> String) {
    Column(Modifier.padding(top = 6.dp)) {
        FilaCifra(stringResource(R.string.ng_er_ventas), s.ven, plata); FilaCifra(stringResource(R.string.ng_er_costo), s.cos, plata, menos = true)
        FilaCifra(stringResource(R.string.ng_er_bruta), s.bruta, plata, fuerte = true); FilaCifra(stringResource(R.string.ng_er_gastos), s.gas, plata, menos = true)
        FilaCifra(titulo, s.util, plata, total = true)
        if (s.inv > 0) FilaCifra(stringResource(R.string.ng_er_inv), s.inv, plata, menos = true)
        if (s.pag > 0) FilaCifra(stringResource(R.string.ng_er_pag), s.pag, plata, menos = true)
        if (s.inv > 0 || s.pag > 0) FilaCifra(stringResource(R.string.ng_er_caja), s.caja, plata, fuerte = true)
    }
}

/** Una fila de periodo (año, mes o día): ventas y utilidad; se toca para abrirlo. */
@Composable
private fun FilaPeriodo(etq: String, s: Negocio.Cifras, plata: (Double) -> String, actual: Boolean = false, onClick: () -> Unit) {
    val vacio = s.ven == 0.0 && s.cos == 0.0 && s.gas == 0.0 && s.inv == 0.0 && s.pag == 0.0
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onClick).padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(etq, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = if (actual) FontWeight.SemiBold else null,
            color = if (actual) MaterialTheme.colorScheme.primary else if (vacio) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
        if (!vacio) Column(horizontalAlignment = Alignment.End) {
            Text(stringResource(R.string.ng_vendiste, plata(s.ven)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(plata(s.util), fontWeight = FontWeight.SemiBold, color = if (s.util < 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
        } else Text("—", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}

/** El calendario del mes: cada día abre su registro; dorado si tiene movimientos. */
@Composable
private fun CalendarioNeg(ym: YearMonth, con: Set<String>, hoyF: LocalDate, onDia: (LocalDate) -> Unit) {
    val ini = ym.atDay(1).dayOfWeek.value - 1
    val celdas = List(ini) { null } + (1..ym.lengthOfMonth()).map { ym.atDay(it) }
    Column(Modifier.padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row { java.time.DayOfWeek.values().forEach { d -> Text(d.getDisplayName(java.time.format.TextStyle.NARROW, java.util.Locale.getDefault()), Modifier.weight(1f),
            style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center) } }
        celdas.chunked(7).forEach { sem ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (0 until 7).forEach { i -> val d = sem.getOrNull(i)
                    Box(Modifier.weight(1f).height(44.dp).clip(RoundedCornerShape(12.dp)).then(
                        if (d == null) Modifier else Modifier.background(if (d.toString() in con) MaterialTheme.colorScheme.secondaryContainer else androidx.compose.ui.graphics.Color.Transparent)
                            .then(if (d == hoyF) Modifier.border(2.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(12.dp)) else Modifier)
                            .clickable(enabled = d <= hoyF, role = Role.Button) { onDia(d) }), contentAlignment = Alignment.Center) {
                        if (d != null) Text("${d.dayOfMonth}", style = MaterialTheme.typography.bodyMedium, fontWeight = if (d.toString() in con) FontWeight.SemiBold else null,
                            color = when { d > hoyF -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = .45f); d.toString() in con -> MaterialTheme.colorScheme.primary; else -> MaterialTheme.colorScheme.onSurface })
                    }
                }
            }
        }
    }
}

@Composable
private fun FilaMovNeg(x: Negocio.Mov, plata: (Double) -> String, onEditar: () -> Unit, onBorrar: () -> Unit) {
    val ven = x.t == "ven"
    Row(Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onEditar).padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(40.dp).clip(CircleShape).background(when { ven -> ST_OK.copy(alpha = .14f); x.t == "pag" -> MaterialTheme.colorScheme.secondaryContainer
            else -> MaterialTheme.colorScheme.surfaceContainerHigh }), contentAlignment = Alignment.Center) {
            Icon(iconoTipo(x.t), null, Modifier.size(20.dp), tint = if (ven) ST_OK else if (x.t == "pag") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            val cat = if (x.t == "gas") nombreCat(x.c) else null
            Text(x.n ?: cat ?: nombreTipo(x.t), style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(listOfNotNull(nombreTipo(x.t), cat.takeIf { x.n != null }).joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text((if (ven) "+" else "−") + plata(x.m), fontWeight = FontWeight.SemiBold, color = if (ven) ST_OK else MaterialTheme.colorScheme.onSurface)
        IconButton(onClick = onBorrar) { Icon(Icons.Filled.Delete, stringResource(R.string.borrar)) }
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
}

/** Salud del negocio: los mismos medidores de la salud financiera (últimos 12 meses). */
@Composable
private fun SaludNeg(r: Map<String, String>, id: String, ym: YearMonth, plata: (Double) -> String) {
    val salud = Negocio.salud(r, id, ym); if (salud.ind.isEmpty()) return
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.MonitorHeart, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.ng_salud), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            Text(pluralStringResource(R.plurals.ng_ultimos, salud.meses, salud.meses), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            salud.ind.forEach { i ->
                val (nombre, ayuda, valor) = when (i.clave) {
                    "nmargen" -> Triple(R.string.ng_i_margen, stringResource(R.string.ng_i_margen_d), pctNeg(i.valor))
                    "nneto" -> Triple(R.string.ng_i_neto, stringResource(R.string.ng_i_neto_d), pctNeg(i.valor))
                    "npe" -> Triple(R.string.ng_i_pe, stringResource(R.string.ng_i_pe_d, plata(Math.round(salud.ventasMes).toDouble())), stringResource(R.string.ng_al_mes, plata(Math.round(i.valor).toDouble())))
                    "nroa" -> Triple(R.string.ng_i_roa, stringResource(R.string.ng_i_roa_d), pctNeg(i.valor))
                    "nrot" -> Triple(R.string.ng_i_rot, stringResource(R.string.ng_i_rot_d), numNeg(i.valor))
                    "nliq" -> Triple(R.string.ng_i_liq, stringResource(R.string.ng_i_liq_d), numNeg(i.valor))
                    else -> Triple(R.string.ng_i_endeuda, stringResource(R.string.ng_i_endeuda_d), pctNeg(i.valor))
                }
                Medidor(i, stringResource(nombre), ayuda, valor)
            }
        }
        Text(stringResource(R.string.ng_nota_salud), Modifier.padding(top = 12.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Lo que tiene y lo que debe. */
@Composable
private fun BalanceNeg(b: Negocio.Bal, plata: (Double) -> String, abrir: (String) -> Unit) {
    val act = Negocio.sumaBal(b.a, Negocio.ACTIVOS); val pas = Negocio.sumaBal(b.p, Negocio.PASIVOS)
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.SwapVert, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.ng_bal), style = MaterialTheme.typography.titleMedium)
        }
        listOf(Triple("a", b.a, act), Triple("p", b.p, pas)).forEach { (lado, l, total) ->
            Row(Modifier.fillMaxWidth().padding(top = 14.dp, bottom = 4.dp)) {
                Text(stringResource(if (lado == "a") R.string.ng_activos else R.string.ng_pasivos), Modifier.weight(1f), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(plata(total), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            }
            HorizontalDivider(thickness = 2.dp, color = MaterialTheme.colorScheme.onSurface)
            if (l.isEmpty()) Text(stringResource(if (lado == "a") R.string.ng_vacio_a else R.string.ng_vacio_p), Modifier.padding(vertical = 8.dp),
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            l.forEach { x ->
                Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button) { abrir("$lado:${x.id}") }.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(x.n ?: nombrePartida(x.k), style = MaterialTheme.typography.bodyMedium)
                        Text(nombrePartida(x.k), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(plata(x.m), fontWeight = FontWeight.SemiBold)
                }
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            }
            OutlinedButton(onClick = { abrir("$lado:") }, modifier = Modifier.padding(top = 8.dp)) {
                Icon(Icons.Filled.Add, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text(stringResource(if (lado == "a") R.string.ng_activo else R.string.ng_pasivo)) }
        }
        if (act > 0 || pas > 0) Row(Modifier.fillMaxWidth().padding(top = 14.dp)) {
            Text(stringResource(R.string.ng_patrimonio), Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Text(plata(act - pas), fontWeight = FontWeight.Bold, color = if (act - pas < 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
        }
    }
}

private fun pctNeg(v: Double) = java.text.NumberFormat.getNumberInstance().apply { maximumFractionDigits = 1 }.format(v * 100) + " %"
private fun numNeg(v: Double) = java.text.NumberFormat.getNumberInstance().apply { maximumFractionDigits = 2 }.format(v)

@Composable
private fun DialogoNegocio(x: Negocio.Neg?, onGuardar: (String, String?) -> Unit, onBorrar: () -> Unit, onCerrar: () -> Unit) {
    var n by rememberSaveable { mutableStateOf(x?.n ?: "") }
    var g by rememberSaveable { mutableStateOf(x?.g ?: "") }
    AlertDialog(onDismissRequest = onCerrar, icon = { Icon(Icons.Filled.ShoppingBag, null) },
        title = { Text(stringResource(if (x == null) R.string.ng_nuevo else R.string.ng_tu)) },
        text = { Column(Modifier.verticalScroll(rememberScrollState())) {
            OutlinedTextField(n, { n = it.take(60) }, label = { Text(stringResource(R.string.ng_nombre)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(g, { g = it.take(80) }, label = { Text(stringResource(R.string.ng_giro)) }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
            if (x != null) {
                Text(stringResource(R.string.ng_borrar_aviso), Modifier.padding(top = 12.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = onBorrar) { Text(stringResource(R.string.borrar), color = MaterialTheme.colorScheme.error) }
            }
        } },
        confirmButton = { TextButton(enabled = n.isNotBlank(), onClick = { onGuardar(n.trim(), g.trim().ifBlank { null }) }) { Text(stringResource(R.string.guardar)) } },
        dismissButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.cancelar)) } })
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun DialogoMovNeg(x: Negocio.Mov?, tipo0: String, negocio: String, fecha0: String, onGuardar: (Negocio.Mov) -> Unit, onBorrar: () -> Unit, onCerrar: () -> Unit) {
    var t by rememberSaveable { mutableStateOf(x?.t ?: tipo0.ifBlank { "ven" }) }
    var m by rememberSaveable { mutableStateOf(texto(x?.m ?: 0.0)) }
    var f by rememberSaveable { mutableStateOf(x?.f ?: fecha0) }
    var c by rememberSaveable { mutableStateOf(x?.c ?: "otro") }
    var n by rememberSaveable { mutableStateOf(x?.n ?: "") }
    val fechaOk = runCatching { LocalDate.parse(f) }.getOrNull()?.let { it <= hoy() } == true
    val monto = kotlin.math.abs(Finanzas.monto(m))
    AlertDialog(onDismissRequest = onCerrar, icon = { Icon(iconoTipo(t), null) },
        title = { Text(if (x == null) stringResource(R.string.ng_anotar_en, negocio) else stringResource(R.string.ng_editar_mov)) },
        text = { Column(Modifier.verticalScroll(rememberScrollState())) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Negocio.TIPOS.forEach { v -> FilterChip(selected = t == v, onClick = { t = v }, label = { Text(nombreTipo(v)) }, leadingIcon = { Icon(iconoTipo(v), null, Modifier.size(18.dp)) }) }
            }
            Text(ayudaTipo(t), Modifier.padding(vertical = 4.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(m, { m = it.filter { ch -> ch.isDigit() || ch == '.' || ch == ',' }.take(15) }, label = { Text(stringResource(R.string.ng_monto)) }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
            OutlinedTextField(f, { f = it.take(10) }, label = { Text(stringResource(R.string.ng_fecha)) }, singleLine = true, isError = !fechaOk,
                supportingText = { Text("AAAA-MM-DD") }, modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
            if (t == "gas") FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Negocio.CAT_GAS.forEach { v -> FilterChip(selected = c == v, onClick = { c = v }, label = { Text(nombreCat(v)) }) }
            }
            OutlinedTextField(n, { n = it.take(120) }, label = { Text(stringResource(R.string.ng_nota)) }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
            if (x != null) TextButton(onClick = onBorrar, modifier = Modifier.padding(top = 6.dp)) { Text(stringResource(R.string.borrar), color = MaterialTheme.colorScheme.error) }
        } },
        confirmButton = { TextButton(enabled = monto > 0 && fechaOk, onClick = {
            onGuardar(Negocio.Mov(x?.id ?: nuevoId("v"), f, t, monto, if (t == "gas") c else null, n.trim().ifBlank { null })) }) { Text(stringResource(R.string.guardar)) } },
        dismissButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.cancelar)) } })
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DialogoPartida(lado: String, x: Negocio.Partida, nuevo: Boolean, onGuardar: (Negocio.Partida) -> Unit, onBorrar: () -> Unit, onCerrar: () -> Unit) {
    var k by rememberSaveable { mutableStateOf(x.k) }
    var n by rememberSaveable { mutableStateOf(x.n ?: "") }
    var m by rememberSaveable { mutableStateOf(texto(x.m)) }
    val tabla = if (lado == "a") Negocio.ACTIVOS else Negocio.PASIVOS
    AlertDialog(onDismissRequest = onCerrar,
        title = { Text(stringResource(when { lado == "a" && nuevo -> R.string.ng_nuevo_activo; lado == "a" -> R.string.ng_editar_activo; nuevo -> R.string.ng_nuevo_pasivo; else -> R.string.ng_editar_pasivo })) },
        text = { Column(Modifier.verticalScroll(rememberScrollState())) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) { tabla.forEach { (v, _) -> FilterChip(selected = k == v, onClick = { k = v }, label = { Text(nombrePartida(v)) }) } }
            Text(stringResource(if (tabla.firstOrNull { it.first == k }?.second == true) (if (lado == "a") R.string.ng_corr_a else R.string.ng_corr_p) else R.string.ng_no_corr),
                Modifier.padding(vertical = 4.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(n, { n = it.take(60) }, label = { Text(stringResource(R.string.ng_nombre_opc)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(m, { m = it.filter { ch -> ch.isDigit() || ch == '.' || ch == ',' }.take(15) }, label = { Text(stringResource(if (lado == "a") R.string.ng_vale else R.string.ng_debe)) },
                singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
            if (!nuevo) TextButton(onClick = onBorrar, modifier = Modifier.padding(top = 6.dp)) { Text(stringResource(R.string.borrar), color = MaterialTheme.colorScheme.error) }
        } },
        confirmButton = { TextButton(onClick = { onGuardar(x.copy(k = k, n = n.trim().ifBlank { null }, m = kotlin.math.abs(Finanzas.monto(m)))) }) { Text(stringResource(R.string.guardar)) } },
        dismissButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.cancelar)) } })
}
