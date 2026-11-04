package com.rutaalacima.app.ui.finanzas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Flight
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Hiking
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.rutaalacima.app.R
import com.rutaalacima.app.domain.model.Hitos
import com.rutaalacima.app.domain.model.Hitos.Hito
import com.rutaalacima.app.ui.components.RutaCard
import com.rutaalacima.app.util.hoy
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit

/* Hitos del ascenso financiero (igual que la web, web/js/56-hitos.js). */

private fun iconoHito(k: String): ImageVector = when (k) {
    "casa" -> Icons.Filled.Home; "viaje" -> Icons.Filled.Flight; "carro" -> Icons.Filled.DirectionsCar; "estudio" -> Icons.Filled.School
    "deuda" -> Icons.Filled.CreditCard; "negocio" -> Icons.Filled.Storefront; "ahorro" -> Icons.Filled.Savings; "familia" -> Icons.Filled.People
    else -> Icons.Filled.Hiking
}

@Composable
private fun nombreTipoHito(k: String) = stringResource(when (k) {
    "casa" -> R.string.hi_t_casa; "viaje" -> R.string.hi_t_viaje; "carro" -> R.string.hi_t_carro; "estudio" -> R.string.hi_t_estudio
    "deuda" -> R.string.hi_t_deuda; "negocio" -> R.string.hi_t_negocio; "ahorro" -> R.string.hi_t_ahorro; "familia" -> R.string.hi_t_familia
    else -> R.string.hi_t_otro
})

private fun fechaLarga(f: String) = runCatching { LocalDate.parse(f).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)) }.getOrDefault(f)

/** «faltan 2 meses» / «es hoy» para un hito planeado. */
@Composable
private fun falta(f: String): String {
    val dias = runCatching { ChronoUnit.DAYS.between(hoy(), LocalDate.parse(f)) }.getOrDefault(0L).toInt()
    return when {
        dias == 0 -> stringResource(R.string.hi_es_hoy)
        dias < 0 -> stringResource(R.string.hi_atrasado)
        dias < 60 -> pluralStringResource(R.plurals.hi_faltan_dias, dias, dias)
        else -> pluralStringResource(R.plurals.hi_faltan_meses, (dias / 30), dias / 30)
    }
}

/** Una fila de hito: el ícono en su sello dorado (punteado si es plan), el título, la fecha y lo que costó. */
@Composable
private fun FilaHito(h: Hito, plata: (Double) -> String, onLogrado: () -> Unit, onEditar: () -> Unit) {
    val oro = MaterialTheme.colorScheme.secondaryContainer
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(44.dp).clip(CircleShape).then(if (h.ok) Modifier.background(oro) else Modifier.border(2.dp, MaterialTheme.colorScheme.outline, CircleShape)),
            contentAlignment = Alignment.Center) {
            Icon(iconoHito(h.k), null, Modifier.size(22.dp), tint = if (h.ok) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(h.t, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
            val detalle = buildList {
                add(if (h.ok) stringResource(R.string.hi_logrado_el, fechaLarga(h.f)) else stringResource(R.string.hi_planeado_para, fechaLarga(h.f)) + " · " + falta(h.f))
                h.m?.takeIf { it > 0 }?.let { add(plata(it)) }; h.n?.takeIf { it.isNotBlank() }?.let { add(it) }
            }.joinToString(" · ")
            Text(detalle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (!h.ok) Button(onClick = onLogrado, modifier = Modifier.padding(top = 6.dp)) {
                Icon(Icons.Filled.Flag, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.hi_lo_logre))
            }
        }
        IconButton(onClick = onEditar) { Icon(Icons.Filled.Edit, stringResource(R.string.hi_editar, h.t)) }
    }
}

/** Los hitos de un periodo ("2026", "2026-11" o "2026-11-04"). */
@Composable
fun HitosCard(libro: Libro, pref: String, titulo: String, plata: (Double) -> String, vm: CuentasViewModel) {
    var editando by rememberSaveable { mutableStateOf<String?>(null) }
    val l = libro.hitos.filter { it.f.startsWith(pref) }.sortedBy { it.f }
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Flag, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(titulo, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = { editando = "nuevo:" + (if (pref.length == 10) pref else "") }) { Icon(Icons.Filled.Add, null, Modifier.size(18.dp)); Text(stringResource(R.string.hi_hito)) }
        }
        l.forEachIndexed { i, h ->
            if (i > 0) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            FilaHito(h, plata, { vm.hitoLogrado(h.id) }) { editando = h.id }
        }
    }
    DialogoHitoSiHace(editando, libro, vm) { editando = null }
}

/** El botón para marcar un hito en un día que todavía no tiene. */
@Composable
fun MarcarHito(f: String, vm: CuentasViewModel) {
    var editando by rememberSaveable { mutableStateOf<String?>(null) }
    TextButton(onClick = { editando = "nuevo:$f" }) { Icon(Icons.Filled.Flag, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.hi_marcar_dia)) }
    DialogoHitoSiHace(editando, null, vm) { editando = null }
}

/** En el balance: el recuerdo («hace 1 año»), lo que viene y la línea de tiempo de lo logrado. */
@Composable
fun HitosBalance(libro: Libro, plata: (Double) -> String, vm: CuentasViewModel) {
    var editando by rememberSaveable { mutableStateOf<String?>(null) }
    val l = libro.hitos
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Flag, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.hi_tus), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            Button(onClick = { editando = "nuevo:" }) { Icon(Icons.Filled.Add, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text(stringResource(R.string.hi_nuevo)) }
        }
        if (l.isEmpty()) Text(stringResource(R.string.hi_vacio), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
        // Recuerdo: un hito logrado esta semana de un año anterior
        hitosRecuerdos(libro).forEach { h -> Recuerdo(h) }
        val planes = l.filter { !it.ok }.sortedBy { it.f }; val logros = l.filter { it.ok }.sortedByDescending { it.f }
        if (planes.isNotEmpty()) {
            Text(stringResource(R.string.hi_viene), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 16.dp))
            planes.forEach { h -> FilaHito(h, plata, { vm.hitoLogrado(h.id) }) { editando = h.id } }
        }
        if (logros.isNotEmpty()) {
            Text(stringResource(R.string.hi_lograste), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 16.dp))
            logros.groupBy { it.f.take(4) }.forEach { (anio, hs) ->
                Text(anio, Modifier.padding(top = 10.dp), style = MaterialTheme.typography.titleSmall, fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
                hs.forEach { h -> FilaHito(h, plata, { }) { editando = h.id } }
            }
        }
    }
    DialogoHitoSiHace(editando, libro, vm) { editando = null }
}

/** Los hitos logrados que cumplen años esta semana (de años anteriores). */
fun hitosRecuerdos(libro: Libro): List<Hito> { val d0 = hoy()
    return libro.hitos.filter { h -> h.ok && (h.f.take(4).toIntOrNull() ?: d0.year) < d0.year && runCatching {
        ChronoUnit.DAYS.between(d0, LocalDate.parse(d0.year.toString() + h.f.drop(4))) in 0..6 }.getOrDefault(false) } }

/** En el balance, solo la semana del aniversario: el recuerdo, con el camino a «Mis hitos». */
@Composable
fun HitosRecuerdo(libro: Libro, onVer: () -> Unit) {
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Flag, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.hi_recuerdo_t), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = onVer) { Text(stringResource(R.string.hi_mis)) }
        }
        hitosRecuerdos(libro).forEach { Recuerdo(it) }
    }
}

@Composable
private fun Recuerdo(h: Hito) {
    val n = hoy().year - h.f.take(4).toInt()
    Row(Modifier.fillMaxWidth().padding(top = 12.dp).clip(RoundedCornerShape(16.dp))
        .background(Brush.linearGradient(listOf(MaterialTheme.colorScheme.secondaryContainer, MaterialTheme.colorScheme.surfaceContainer))).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Icon(iconoHito(h.k), null, Modifier.size(28.dp), tint = MaterialTheme.colorScheme.primary); Spacer(Modifier.width(12.dp))
        Column {
            Text(pluralStringResource(R.plurals.hi_hace_anios, n, n), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(h.t, style = MaterialTheme.typography.titleMedium, fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** Abre el diálogo si [editando] es "nuevo:fecha" o el id de un hito. */
@Composable
private fun DialogoHitoSiHace(editando: String?, libro: Libro?, vm: CuentasViewModel, onCerrar: () -> Unit) {
    val e = editando ?: return
    val h = if (e.startsWith("nuevo:")) { val f = e.removePrefix("nuevo:").ifBlank { hoy().toString() }
        Hito(id = "h" + System.currentTimeMillis().toString(36), t = "", f = f, ok = f <= hoy().toString()) }
        else vm.libro.value.hitos.firstOrNull { it.id == e } ?: return
    DialogoHito(h, nuevo = e.startsWith("nuevo:"), onGuardar = { vm.hitoGuardar(it); onCerrar() }, onBorrar = { vm.hitoBorrar(h.id); onCerrar() }, onCerrar = onCerrar)
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun DialogoHito(h: Hito, nuevo: Boolean, onGuardar: (Hito) -> Unit, onBorrar: () -> Unit, onCerrar: () -> Unit) {
    var t by rememberSaveable { mutableStateOf(h.t) }
    var k by rememberSaveable { mutableStateOf(h.k) }
    var ok by rememberSaveable { mutableStateOf(h.ok) }
    var f by rememberSaveable { mutableStateOf(h.f) }
    var m by rememberSaveable { mutableStateOf(h.m?.let { if (it % 1.0 == 0.0) it.toLong().toString() else it.toString() } ?: "") }
    var n by rememberSaveable { mutableStateOf(h.n ?: "") }
    val fechaOk = Regex("\\d{4}-\\d{2}-\\d{2}").matches(f) && runCatching { LocalDate.parse(f) }.isSuccess
    AlertDialog(
        onDismissRequest = onCerrar,
        icon = { Icon(Icons.Filled.Flag, null) },
        title = { Text(stringResource(if (nuevo) R.string.hi_nuevo else R.string.hi_editar_t)) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                OutlinedTextField(t, { t = it.take(80) }, label = { Text(stringResource(R.string.hi_que)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(10.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Hitos.TIPOS.forEach { v -> FilterChip(selected = k == v, onClick = { k = v }, label = { Text(nombreTipoHito(v)) }, leadingIcon = { Icon(iconoHito(v), null, Modifier.size(18.dp)) }) }
                }
                Spacer(Modifier.height(8.dp))
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    SegmentedButton(selected = ok, onClick = { ok = true }, shape = SegmentedButtonDefaults.itemShape(0, 2)) { Text(stringResource(R.string.hi_lo_logre_s)) }
                    SegmentedButton(selected = !ok, onClick = { ok = false }, shape = SegmentedButtonDefaults.itemShape(1, 2)) { Text(stringResource(R.string.hi_lo_planeo)) }
                }
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(f, { f = it.take(10) }, label = { Text(stringResource(R.string.hi_fecha)) }, singleLine = true, isError = !fechaOk,
                    supportingText = { Text("AAAA-MM-DD") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(m, { m = it.filter { c -> c.isDigit() || c == '.' || c == ',' }.take(15) }, label = { Text(stringResource(R.string.hi_monto)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                OutlinedTextField(n, { n = it.take(140) }, label = { Text(stringResource(R.string.hi_nota)) }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(top = 6.dp))
                if (!nuevo) TextButton(onClick = onBorrar, modifier = Modifier.padding(top = 6.dp)) { Text(stringResource(R.string.borrar), color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = {
            TextButton(enabled = t.isNotBlank() && fechaOk, onClick = {
                onGuardar(h.copy(t = t.trim(), k = k, ok = ok, f = f, m = m.replace(',', '.').toDoubleOrNull()?.takeIf { it > 0 }, n = n.trim().ifBlank { null }))
            }) { Text(stringResource(R.string.guardar)) }
        },
        dismissButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.cancelar)) } },
    )
}
