package com.rutaalacima.app.ui.finanzas

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Reorder
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.rutaalacima.app.R
import com.rutaalacima.app.domain.model.Cuentas
import com.rutaalacima.app.domain.model.Cuentas.Tipo
import com.rutaalacima.app.domain.model.Fijos
import com.rutaalacima.app.ui.components.RutaCard
import com.rutaalacima.app.util.hoy
import java.time.YearMonth

/**
 * «¿Qué hiciste con lo que entró?» (igual que la web): una dona con gastos, ahorro, inversión, dar y lo que queda,
 * el porcentaje construido en el centro y cada porción con su nombre y su cifra al lado (el color nunca va solo).
 */
@Composable
fun DonaDestino(t: Cuentas.Suma, plata: (Double) -> String) {
    val libre = colorTipo(Tipo.ING).copy(alpha = 0.45f)
    val partes = buildList {
        add(Triple(stringResource(R.string.cu_gas), t.gas, colorTipo(Tipo.GAS)))
        add(Triple(nombreTipo(Tipo.AHO), t.aho, colorTipo(Tipo.AHO)))
        add(Triple(nombreTipo(Tipo.INV), t.inv, colorTipo(Tipo.INV)))
        add(Triple(nombreTipo(Tipo.GEN), t.gen, colorTipo(Tipo.GEN)))
        if (t.disponible > 0) add(Triple(stringResource(R.string.dona_disponible), t.disponible, libre))
    }
    val total = partes.sumOf { it.second }
    if (total <= 0) return
    val base = if (t.ing > 0) t.ing else total
    val desc = partes.joinToString(", ") { "${it.first} ${Math.round(it.second / base * 100)} %" }
    RutaCard {
        Text(stringResource(R.string.dona_titulo), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.dona_de, plata(t.ing)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        DonaGrafica(partes, total, desc, if (t.ing > 0) "${Math.round(t.construido / t.ing * 100)} %" else "—",
            stringResource(if (t.ing > 0) R.string.dona_construido else R.string.dona_sin_ing))
        partes.forEachIndexed { i, (n, v, c) ->
            if (i > 0) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(10.dp).clip(RoundedCornerShape(3.dp)).background(c))
                Spacer(Modifier.width(10.dp))
                Text(n, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                Text(plata(v), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Text("${Math.round(v / base * 100)} %", Modifier.width(48.dp), style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = androidx.compose.ui.text.style.TextAlign.End)
            }
        }
        if (t.disponible < 0) Text(stringResource(R.string.dona_falto, plata(-t.disponible)), style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 6.dp))
        Text(stringResource(R.string.dona_nota), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
    }
}

/** Los fijos, resumidos (igual que la web): cuánto entra y sale fijo cada mes y los más pesados; el detalle vive en «Mis cuentas fijas». */
@Composable
fun FijosResumen(libro: Libro, plata: (Double) -> String, onVer: () -> Unit) {
    val ym = YearMonth.from(hoy()).toString()
    val l = libro.fijos.filter { Fijos.activoEn(it, ym) }
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Repeat, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.cu_fijos_titulo), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            OutlinedButton(onClick = onVer) { Text(if (l.isEmpty()) stringResource(R.string.fr_ver_solo) else stringResource(R.string.fr_ver, l.size)) }
        }
        if (l.isEmpty()) { Text(stringResource(R.string.cu_fijos_vacio), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp)); return@RutaCard }
        val nRep = l.filter { it.id in Fijos.repetidos(l, ym) }.map { "${it.t}|${it.n.ifBlank { it.c }.trim().lowercase()}" }.distinct().size
        if (nRep > 0) Row(Modifier.fillMaxWidth().padding(top = 10.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.errorContainer).padding(10.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Info, null, tint = MaterialTheme.colorScheme.onErrorContainer); Spacer(Modifier.width(8.dp))
            Text(pluralStringResource(R.plurals.fr_repetidos, nRep, nRep), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onErrorContainer)
        }
        val suma = { t: Tipo -> l.filter { it.t == t.codigo }.sumOf { it.m } }
        val ent = suma(Tipo.ING); val sal = listOf(Tipo.GAS, Tipo.AHO, Tipo.INV, Tipo.GEN).map { it to suma(it) }
        val salT = sal.sumOf { it.second }; val queda = ent - salT; val escala = maxOf(ent, salT).coerceAtLeast(1.0)
        Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Cifra(stringResource(R.string.fr_entra), plata(ent), colorTipo(Tipo.ING), Modifier.weight(1f))
            Cifra(stringResource(R.string.fr_sale), plata(salT), colorTipo(Tipo.GAS), Modifier.weight(1f))
            Cifra(stringResource(if (queda >= 0) R.string.fr_queda else R.string.fr_falta), plata(kotlin.math.abs(queda)),
                if (queda < 0) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
        }
        val libreC = colorTipo(Tipo.ING).copy(alpha = 0.45f)
        Row(Modifier.fillMaxWidth().padding(top = 10.dp).height(12.dp).clip(RoundedCornerShape(50)).background(MaterialTheme.colorScheme.surfaceContainerHigh),
            horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            sal.filter { it.second > 0 }.forEach { (t, v) -> Box(Modifier.weight((v / escala).toFloat().coerceAtLeast(0.005f)).height(12.dp).background(colorTipo(t))) }
            if (queda > 0) Box(Modifier.weight((queda / escala).toFloat()).height(12.dp).background(libreC))
            val resto = 1.0 - (salT + maxOf(queda, 0.0)) / escala
            if (resto > 0.001) Spacer(Modifier.weight(resto.toFloat()))
        }
        val orden = listOf(Tipo.ING, Tipo.GAS, Tipo.AHO, Tipo.INV, Tipo.GEN).map { it.codigo }
        l.sortedWith(compareBy<Fijos.Fijo> { orden.indexOf(it.t) }.thenByDescending { it.m }).forEachIndexed { i, x ->   // todos: primero lo que entra
            if (i == 0) Spacer(Modifier.height(8.dp)) else HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            val t = Tipo.de(x.t)
            Row(Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(nombreTipo(t, plural = false), Modifier.clip(RoundedCornerShape(50)).background(colorTipo(t).copy(alpha = 0.14f)).padding(horizontal = 8.dp, vertical = 2.dp),
                    style = MaterialTheme.typography.labelSmall, color = colorTipo(t))
                Spacer(Modifier.width(10.dp))
                Text(x.n.ifBlank { nombreCategoria(t, x.c) }, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyMedium)
                Text(stringResource(R.string.cu_fijo_dia, x.dia), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.width(10.dp))
                Text(plata(x.m), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun Cifra(etq: String, valor: String, color: Color, modifier: Modifier) {
    Column(modifier.clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceContainer).padding(horizontal = 10.dp, vertical = 8.dp)) {
        Text(etq, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(valor, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = color, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** La dona: porciones (nombre, valor, color) sobre [total], con dos líneas en el centro. */
@Composable
fun DonaGrafica(partes: List<Triple<String, Double, Color>>, total: Double, desc: String, centro: String, centroSub: String, grande: Boolean = false) {
    val fondo = MaterialTheme.colorScheme.surfaceContainerHigh
    Box(Modifier.fillMaxWidth().padding(vertical = 14.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(232.dp).semantics { contentDescription = desc }) {
            val grosor = 22.dp.toPx(); val r = (size.minDimension - grosor) / 2
            val tl = Offset(center.x - r, center.y - r); val sz = Size(r * 2, r * 2)
            drawArc(fondo, 0f, 360f, false, tl, sz, style = Stroke(grosor))
            val visibles = partes.filter { it.second > 0 }
            val hueco = if (visibles.size > 1) 1.5f else 0f
            var ang = -90f
            visibles.forEach { (_, v, c) ->
                val barrido = (v / total * 360).toFloat()
                drawArc(c, ang + hueco / 2, (barrido - hueco).coerceAtLeast(0.5f), false, tl, sz, style = Stroke(grosor))
                ang += barrido
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(160.dp)) {
            Text(centro, style = if (centro.length > 6) MaterialTheme.typography.titleLarge else MaterialTheme.typography.displaySmall,
                fontWeight = FontWeight.SemiBold, maxLines = 1, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Text(centroSub, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Colores de las categorías (orden fijo, nunca rotan), igual que la web: 7 tonos de la marca y «Otras» en gris. */
@Composable
fun coloresCategorias(): List<Color> = if (MaterialTheme.colorScheme.background.let { 0.299f * it.red + 0.587f * it.green + 0.114f * it.blue } < 0.5f)
    listOf(0xFFE8A493, 0xFF9CC3E0, 0xFFE0BC74, 0xFF8CC796, 0xFFC9AEDB, 0xFFF0B48A, 0xFFA9C1CC, 0xFF7D848A).map { Color(it) }
    else listOf(0xFF7A2E1F, 0xFF2F5D7C, 0xFFB07D2B, 0xFF3E7A5A, 0xFF6A4A7E, 0xFFC0663A, 0xFF4F6D7A, 0xFF9AA0A6).map { Color(it) }

/** El nombre de cada tarjeta del balance (para ordenarlas). */
@Composable
private fun nombreSeccion(k: String): String = stringResource(when (k) {
    "salud" -> R.string.cu_salud; "cifras" -> R.string.org_cifras; "dona" -> R.string.dona_titulo; "meses" -> R.string.ult12_titulo
    "grafica" -> R.string.gr_titulo; "anios" -> R.string.cu_anio_por_anio; "metasfin" -> R.string.mf_titulo; "deudas" -> R.string.cu_deudas
    "fijos" -> R.string.cu_fijos_titulo; "mochilas" -> R.string.cu_mochilas; "categorias" -> R.string.cu_a_donde
    "privacidad" -> R.string.cu_privacidad; "moneda" -> R.string.cu_moneda; else -> R.string.org_cifras
})

/**
 * «Organizar el balance»: la lista de tarjetas con flechas para subir y bajar cada una (igual que el asa de la web).
 * El orden se guarda en el libro y viaja a la web.
 */
@Composable
fun OrganizarBalance(actual: List<String>, personalizado: Boolean, onGuardar: (List<String>) -> Unit) {
    var abierto by androidx.compose.runtime.saveable.rememberSaveable { androidx.compose.runtime.mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        androidx.compose.material3.TextButton(onClick = { abierto = true }) {
            Icon(Icons.Filled.Reorder, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.org_titulo))
        }
    }
    if (!abierto) return
    val lista = androidx.compose.runtime.remember(actual) { androidx.compose.runtime.mutableStateListOf(*actual.toTypedArray()) }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = { abierto = false },
        icon = { Icon(Icons.Filled.Reorder, null) },
        title = { Text(stringResource(R.string.org_titulo)) },
        text = {
            Column {
                Text(stringResource(R.string.org_ayuda), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                androidx.compose.foundation.lazy.LazyColumn(Modifier.height(360.dp)) {
                    items(lista.size, key = { lista[it] }) { i ->
                        val k = lista[i]
                        Row(Modifier.fillMaxWidth().padding(vertical = 2.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceContainer).padding(start = 12.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Text("${i + 1}", Modifier.width(24.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(nombreSeccion(k), Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            androidx.compose.material3.IconButton(onClick = { if (i > 0) { lista.removeAt(i); lista.add(i - 1, k) } }, enabled = i > 0) {
                                Icon(Icons.Filled.KeyboardArrowUp, stringResource(R.string.cu_subir))
                            }
                            androidx.compose.material3.IconButton(onClick = { if (i < lista.lastIndex) { lista.removeAt(i); lista.add(i + 1, k) } }, enabled = i < lista.lastIndex) {
                                Icon(Icons.Filled.KeyboardArrowDown, stringResource(R.string.cu_bajar))
                            }
                        }
                    }
                }
            }
        },
        confirmButton = { androidx.compose.material3.TextButton(onClick = { onGuardar(lista.toList()); abierto = false }) { Text(stringResource(R.string.guardar)) } },
        dismissButton = {
            Row {
                if (personalizado) androidx.compose.material3.TextButton(onClick = { onGuardar(emptyList()); abierto = false }) { Text(stringResource(R.string.org_original)) }
                androidx.compose.material3.TextButton(onClick = { abierto = false }) { Text(stringResource(R.string.cancelar)) }
            }
        },
    )
}
