package com.rutaalacima.app.ui.finanzas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.rutaalacima.app.R
import com.rutaalacima.app.domain.model.Cuentas.Tipo
import com.rutaalacima.app.domain.model.Deudas
import java.time.LocalDate
import java.time.YearMonth

// ====================================================================== Movimientos frecuentes

/** Un movimiento que se repite a mano (no es fijo): el mismo tipo, categoría y concepto, con su último monto. */
data class Frecuente(val t: String, val c: String, val n: String, val m: Double, val d: String?, val meta: String?, val veces: Int, val ultimo: String)

/** Lo que más anotas en los últimos 120 días (al menos 2 veces), igual que movsFrecuentes en la web. */
fun frecuentesDe(libro: Libro, hoy: LocalDate): List<Frecuente> {
    val hs = hoy.toString(); val desde = hoy.minusDays(120).toString()
    val g = linkedMapOf<String, Frecuente>()
    libro.dias.filterKeys { it in desde..hs }.toSortedMap().forEach { (f, xs) ->
        xs.forEach { x ->
            if (x.fx != null || x.agenda != null || x.virtual || x.prog || x.m <= 0) return@forEach
            val k = "${x.t}|${x.c}|${x.n.trim().lowercase()}"
            val antes = g[k]
            g[k] = Frecuente(x.t, x.c, x.n.trim(), x.m, x.d, x.meta, (antes?.veces ?: 0) + 1, f)
        }
    }
    return g.values.filter { it.veces >= 2 }.sortedWith(compareByDescending<Frecuente> { it.veces }.thenByDescending { it.ultimo }).take(6)
}

/** Fichas de un toque bajo «Nuevo movimiento»: anotan el frecuente en este día con su mismo monto. */
@Composable
fun FrecuentesFila(xs: List<Frecuente>, plata: (Double) -> String, onAnotar: (Frecuente, String) -> Unit) {
    if (xs.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(stringResource(R.string.fr_titulo), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.fr_ayuda), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(end = 8.dp)) {
            itemsIndexed(xs, key = { _, x -> "${x.t}|${x.c}|${x.n}" }) { _, x ->
                val tipo = Tipo.de(x.t)
                val nombre = x.n.ifBlank { nombreCategoria(tipo, x.c) }
                Surface(
                    onClick = { onAnotar(x, nombre) }, shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                    border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    modifier = Modifier.heightIn(min = 48.dp),
                ) {
                    Column(Modifier.padding(horizontal = 12.dp, vertical = 6.dp)) {
                        Text(nombre, style = MaterialTheme.typography.labelMedium, maxLines = 1,
                            overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 160.dp))
                        Text(plata(x.m), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = colorTipo(tipo))
                    }
                }
            }
        }
    }
}

// ====================================================================== Estado de cada deuda este mes

enum class EstadoDeudaK { PAGADA, AL_DIA, PARCIAL, PROGRAMADA, SIN_PAGO }
data class EstadoDeuda(val k: EstadoDeudaK, val dia: Int = 0)

/** Igual que estadoDeuda en la web: pagada, al día (pagó su cuota), pago parcial, programada (un pago más
 *  adelante este mes) o sin pago este mes. No dice «en mora»: SuRoute no conoce la fecha límite del banco. */
fun estadoDeuda(h: Deudas.Hoy, libro: Libro, hoy: LocalDate): EstadoDeuda {
    if (h.actual <= 0) return EstadoDeuda(EstadoDeudaK.PAGADA)
    val ym = YearMonth.from(hoy).toString(); val hs = hoy.toString(); val id = h.deuda.id
    val pagado = libro.dias.filterKeys { it.startsWith(ym) && it <= hs }.values.flatten().filter { it.d == id && !it.prog }.sumOf { it.m }
    val min = h.deuda.minimo
    if (pagado > 0 && pagado >= min - 0.5) return EstadoDeuda(EstadoDeudaK.AL_DIA)
    if (pagado > 0) return EstadoDeuda(EstadoDeudaK.PARCIAL)
    val futuros = (libro.programados.keys + libro.dias.keys).filter { it.startsWith(ym) && it > hs }.sorted()
    futuros.firstOrNull { f -> libro.movs(f).any { it.d == id } }?.let { return EstadoDeuda(EstadoDeudaK.PROGRAMADA, it.takeLast(2).toInt()) }
    return EstadoDeuda(EstadoDeudaK.SIN_PAGO)
}

/** La etiqueta del estado (con ícono: nunca solo color). */
@Composable
fun EstadoDeudaChip(e: EstadoDeuda, modifier: Modifier = Modifier) {
    val cs = MaterialTheme.colorScheme
    val verde = colorTipo(Tipo.ING)
    val (icono: ImageVector, texto: String) = when (e.k) {
        EstadoDeudaK.PAGADA -> Icons.Filled.Check to stringResource(R.string.cu_pagada)
        EstadoDeudaK.AL_DIA -> Icons.Filled.Check to stringResource(R.string.ed_al_dia)
        EstadoDeudaK.PARCIAL -> Icons.Filled.Schedule to stringResource(R.string.ed_parcial)
        EstadoDeudaK.PROGRAMADA -> Icons.Filled.Event to stringResource(R.string.ed_programada, e.dia)
        EstadoDeudaK.SIN_PAGO -> Icons.Filled.Alarm to stringResource(R.string.ed_sin_pago)
    }
    val (fondo, tinta) = when (e.k) {
        EstadoDeudaK.PAGADA, EstadoDeudaK.AL_DIA -> verde.copy(alpha = 0.14f) to verde
        EstadoDeudaK.PARCIAL, EstadoDeudaK.PROGRAMADA -> cs.secondaryContainer to cs.onSecondaryContainer
        EstadoDeudaK.SIN_PAGO -> cs.errorContainer to cs.onErrorContainer
    }
    Surface(shape = CircleShape, color = fondo, contentColor = tinta, modifier = modifier) {
        Row(Modifier.padding(start = 6.dp, end = 8.dp, top = 2.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icono, null, Modifier.size(14.dp))
            Spacer(Modifier.width(4.dp))
            Text(texto, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, maxLines = 1)
        }
    }
}
