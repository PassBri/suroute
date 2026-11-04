package com.rutaalacima.app.ui.finanzas

import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.filled.Print
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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

/** El ícono que se ve: el que eligió la persona o, si no eligió, el de su tipo. */
private fun iconoDe(h: Hito): ImageVector = iconoHitoClave(h.i) ?: iconoHito(h.k)

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
private fun FilaHito(h: Hito, plata: (Double) -> String, onLogrado: () -> Unit, soloVer: Boolean = false, onEditar: () -> Unit) {
    val oro = MaterialTheme.colorScheme.secondaryContainer
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(44.dp).clip(CircleShape).then(if (h.ok) Modifier.background(oro) else Modifier.border(2.dp, MaterialTheme.colorScheme.outline, CircleShape)),
            contentAlignment = Alignment.Center) {
            Icon(iconoDe(h), null, Modifier.size(22.dp), tint = if (h.ok) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(h.t, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
            val detalle = buildList {
                add(if (h.ok) stringResource(R.string.hi_logrado_el, fechaLarga(h.f)) else stringResource(R.string.hi_planeado_para, fechaLarga(h.f)) + " · " + falta(h.f))
                h.m?.takeIf { it > 0 }?.let { add(plata(it)) }; h.n?.takeIf { it.isNotBlank() }?.let { add(it) }
            }.joinToString(" · ")
            Text(detalle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (!h.ok && !soloVer) Button(onClick = onLogrado, modifier = Modifier.padding(top = 6.dp)) {
                Icon(Icons.Filled.Flag, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.hi_lo_logre))
            }
        }
        if (!soloVer) IconButton(onClick = onEditar) { Icon(Icons.Filled.Edit, stringResource(R.string.hi_editar, h.t)) }
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
            if (l.isNotEmpty()) BotonImprimirHitos(libro, plata)
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
        Icon(iconoDe(h), null, Modifier.size(28.dp), tint = MaterialTheme.colorScheme.primary); Spacer(Modifier.width(12.dp))
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
    var ico by rememberSaveable { mutableStateOf(h.i) }
    var eligiendo by rememberSaveable { mutableStateOf(false) }
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
                // El ícono: por defecto el del tipo; se puede elegir cualquiera de la lista de Material
                Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.secondaryContainer), contentAlignment = Alignment.Center) {
                        Icon(iconoHitoClave(ico) ?: iconoHito(k), null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.onSecondaryContainer) }
                    Spacer(Modifier.width(10.dp))
                    Text(stringResource(if (ico == null) R.string.hi_icono_auto else R.string.hi_icono_propio), Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                    TextButton(onClick = { eligiendo = !eligiendo }) { Text(stringResource(if (eligiendo) R.string.hi_icono_listo else R.string.hi_icono_elegir)) }
                }
                if (eligiendo) FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    FilterChip(selected = ico == null, onClick = { ico = null; eligiendo = false }, label = { Text(stringResource(R.string.hi_icono_auto)) },
                        leadingIcon = { Icon(iconoHito(k), null, Modifier.size(18.dp)) }, modifier = Modifier.padding(end = 4.dp))
                    ICONOS_HITO.forEachIndexed { i, (clave, v) ->
                        val sel = ico == clave; val desc = stringResource(R.string.hi_icono_n, i + 1)
                        IconButton(onClick = { ico = clave; eligiendo = false }, modifier = Modifier.size(48.dp)) {
                            Box(Modifier.size(38.dp).clip(CircleShape).background(if (sel) MaterialTheme.colorScheme.primary else androidx.compose.ui.graphics.Color.Transparent), contentAlignment = Alignment.Center) {
                                Icon(v, desc, Modifier.size(22.dp), tint = if (sel) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant) }
                        }
                    }
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
                onGuardar(h.copy(t = t.trim(), k = k, ok = ok, f = f, m = m.replace(',', '.').toDoubleOrNull()?.takeIf { it > 0 }, n = n.trim().ifBlank { null }, i = ico))
            }) { Text(stringResource(R.string.guardar)) }
        },
        dismissButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.cancelar)) } },
    )
}


/* ---------------------------------------------------------------- Imprimir: «Mis hitos» en PDF (como el documento de la web) */

private class FilaPdf(val f: String, val ok: Boolean, val t: String, val meta: String, val nota: String?)
private class TextosHitosPdf(val titulo: String, val sub: String, val marca: String, val fecha: String, val logrados: String, val camino: String,
    val puesto: String, val porVenir: String, val viene: String, val logre: String, val pie: String)

/** El botón de imprimir: guarda «Mis hitos» como PDF (A4) para imprimirlo o compartirlo. */
@Composable
private fun BotonImprimirHitos(libro: Libro, plata: (Double) -> String) {
    val imprimir = rememberImprimirHitos(libro, plata)
    IconButton(onClick = imprimir) { Icon(Icons.Filled.Print, stringResource(R.string.hi_imprimir)) }
}

/** La acción de imprimir «Mis hitos» (abre el selector para guardar el PDF); la usan la tarjeta y la barra lateral. */
@Composable
fun rememberImprimirHitos(libro: Libro, plata: (Double) -> String): () -> Unit {
    val ctx = LocalContext.current
    val l = libro.hitos
    // Los textos se arman aquí (necesitan recursos y plurales); el PDF se dibuja fuera de la composición
    val filas = l.sortedBy { it.f }.map { h ->
        val partes = buildList {
            add(nombreTipoHito(h.k))
            add(if (h.ok) stringResource(R.string.hi_logrado_el, fechaLarga(h.f)) else stringResource(R.string.hi_planeado_para, fechaLarga(h.f)) + " · " + falta(h.f))
            h.m?.takeIf { it > 0 }?.let { add(plata(it)) }
        }
        FilaPdf(h.f, h.ok, h.t, partes.joinToString(" · "), h.n?.takeIf { it.isNotBlank() })
    }
    val textos = TextosHitosPdf(stringResource(R.string.hi_pdf_titulo), stringResource(R.string.hi_pdf_sub), stringResource(R.string.hi_mis),
        fechaLarga(hoy().toString()), stringResource(R.string.hi_pdf_logrados), stringResource(R.string.hi_pdf_camino), stringResource(R.string.hi_pdf_puesto),
        stringResource(R.string.hi_pdf_por_venir), stringResource(R.string.hi_viene), stringResource(R.string.hi_pdf_logre), stringResource(R.string.hi_pdf_pie))
    val invertido = l.filter { it.ok }.sumOf { it.m ?: 0.0 }; val porVenir = l.filter { !it.ok }.sumOf { it.m ?: 0.0 }
    val cifras = buildList {
        add(l.count { it.ok }.toString() to textos.logrados)
        l.count { !it.ok }.takeIf { it > 0 }?.let { add(it.toString() to textos.camino) }
        if (invertido > 0) add(plata(invertido) to textos.puesto)
        if (porVenir > 0) add(plata(porVenir) to textos.porVenir)
    }
    val guardar = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        if (uri != null) runCatching { ctx.contentResolver.openOutputStream(uri)?.use { pdfHitos(it, filas, cifras, textos) } }
            .onSuccess { com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.hi_pdf_ok)) }
    }
    return { guardar.launch("mis-hitos-${hoy()}.pdf") }
}

/** Dibuja el PDF: la banda burdeos con la marca, el título, las cifras y la línea de tiempo (lo que viene y lo logrado por año). */
private fun pdfHitos(out: java.io.OutputStream, filas: List<FilaPdf>, cifras: List<Pair<String, String>>, t: TextosHitosPdf) {
    val doc = PdfDocument(); val ancho = 595; val alto = 842; val margen = 44f
    val burdeos = 0xFF6B2A1A.toInt(); val oro = 0xFF86683A.toInt(); val tinta = 0xFF1D2427.toInt(); val suave = 0xFF5A666B.toInt(); val linea = 0xFFE4D9C3.toInt()
    val serif = Typeface.create(Typeface.SERIF, Typeface.BOLD)
    fun tp(tam: Float, color: Int, tf: Typeface? = null) = TextPaint().apply { isAntiAlias = true; textSize = tam; this.color = color; tf?.let { typeface = it } }
    val tituloP = tp(24f, tinta, serif); val subP = tp(11f, suave); val secP = tp(15f, burdeos, serif); val anioP = tp(16f, oro, serif)
    val hitoP = tp(12.5f, tinta, serif); val metaP = tp(9.5f, suave); val notaP = tp(10.5f, 0xFF3D4A4F.toInt(), Typeface.create(Typeface.SERIF, Typeface.ITALIC))
    val diaP = tp(15f, tinta, serif).apply { textAlign = Paint.Align.RIGHT }; val mesP = tp(7.5f, suave).apply { textAlign = Paint.Align.RIGHT; letterSpacing = .1f }
    var n = 0; var pagina: PdfDocument.Page? = null; var y = 0f
    fun cv() = pagina!!.canvas
    fun nueva() { pagina?.let { doc.finishPage(it) }; n++; pagina = doc.startPage(PdfDocument.PageInfo.Builder(ancho, alto, n).create()); y = margen }
    fun lay(s: String, p: TextPaint, w: Float) = StaticLayout.Builder.obtain(s, 0, s.length, p, w.toInt()).setAlignment(Layout.Alignment.ALIGN_NORMAL).build()
    fun espacio(h: Float) { if (pagina == null || y + h > alto - margen) nueva() }
    fun dibujar(l: StaticLayout, x: Float, yy: Float) { cv().save(); cv().translate(x, yy); l.draw(cv()); cv().restore() }

    // Portada: la banda con la marca
    nueva()
    cv().drawRect(0f, 0f, ancho.toFloat(), 72f, Paint().apply { color = burdeos })
    cv().drawText("SUROUTE", margen, 42f, tp(17f, 0xFFF3EDE0.toInt()).apply { letterSpacing = .12f })
    cv().drawText("SUMMIT ROUTE", margen, 55f, tp(6.5f, 0xFFF3EDE0.toInt()).apply { letterSpacing = .2f })
    val der = tp(8f, 0xFFF3EDE0.toInt()).apply { textAlign = Paint.Align.RIGHT; letterSpacing = .08f }
    cv().drawText(t.marca.uppercase(), ancho - margen, 34f, der); cv().drawText(t.fecha.uppercase(), ancho - margen, 46f, der)
    y = 108f
    val lt = lay(t.titulo, tituloP, ancho - 2 * margen); dibujar(lt, margen, y); y += lt.height + 4f
    val ls = lay(t.sub, subP, ancho - 2 * margen); dibujar(ls, margen, y); y += ls.height + 14f
    // Las cifras en pastillas de papel
    var x = margen; val cifraP = tp(14f, burdeos, serif); val etqP = tp(8.5f, suave)
    cifras.forEach { (v, e) ->
        val w = maxOf(cifraP.measureText(v), etqP.measureText(e)) + 20f
        if (x + w > ancho - margen) { x = margen; y += 48f }
        cv().drawRoundRect(x, y, x + w, y + 40f, 7f, 7f, Paint().apply { isAntiAlias = true; color = 0xFFF7F3EA.toInt() })
        cv().drawText(v, x + 10f, y + 18f, cifraP); cv().drawText(e, x + 10f, y + 31f, etqP); x += w + 8f
    }
    y += 52f
    cv().drawLine(0f, y, ancho.toFloat(), y, Paint().apply { color = 0xFFDCE2E4.toInt() }); y += 10f

    val xTxt = margen + 92f; val wTxt = ancho - margen - xTxt; val cx = margen + 68f
    val mesF = DateTimeFormatter.ofPattern("MMM")
    fun item(h: FilaPdf) {
        val l1 = lay(h.t, hitoP, wTxt); val l2 = lay(h.meta, metaP, wTxt); val l3 = h.nota?.let { lay("«$it»", notaP, wTxt) }
        val alto1 = maxOf(40f, l1.height + 2f + l2.height + (l3?.let { it.height + 5f } ?: 0f)) + 12f
        espacio(alto1)
        val d = runCatching { LocalDate.parse(h.f) }.getOrNull()
        if (d != null) { cv().drawText("${d.dayOfMonth}", margen + 40f, y + 17f, diaP); cv().drawText(d.format(mesF).uppercase().trimEnd('.'), margen + 40f, y + 28f, mesP) }
        val circ = Paint().apply { isAntiAlias = true; color = oro }
        if (h.ok) { cv().drawCircle(cx, y + 15f, 13f, circ); cv().drawCircle(cx, y + 15f, 4.5f, Paint().apply { isAntiAlias = true; color = 0xFFFFFFFF.toInt() }) }
        else cv().drawCircle(cx, y + 15f, 12f, circ.apply { style = Paint.Style.STROKE; strokeWidth = 1.6f; pathEffect = DashPathEffect(floatArrayOf(3.5f, 2.5f), 0f) })
        var yy = y + 3f; dibujar(l1, xTxt, yy); yy += l1.height + 2f; dibujar(l2, xTxt, yy); yy += l2.height + 5f; l3?.let { dibujar(it, xTxt, yy) }
        y += alto1
    }
    fun seccion(s: String) { espacio(70f); y += 14f; dibujar(lay(s, secP, ancho - 2 * margen), margen, y); y += 26f }
    val planes = filas.filter { !it.ok }; val logros = filas.filter { it.ok }.sortedByDescending { it.f }
    if (planes.isNotEmpty()) { seccion(t.viene); planes.forEach(::item) }
    if (logros.isNotEmpty()) {
        seccion(t.logre)
        logros.groupBy { it.f.take(4) }.forEach { (anio, hs) ->
            espacio(64f); y += 6f
            cv().drawText(anio, margen, y + 14f, anioP)
            val fin = margen + anioP.measureText(anio) + 10f
            cv().drawLine(fin, y + 9f, ancho - margen, y + 9f, Paint().apply { color = linea; strokeWidth = 1f }); y += 26f
            hs.forEach(::item)
        }
    }
    espacio(30f); y += 12f
    cv().drawLine(margen, y, ancho - margen, y, Paint().apply { color = 0xFFDCE2E4.toInt() }); y += 8f
    dibujar(lay(t.pie, tp(8.5f, suave), ancho - 2 * margen), margen, y)
    pagina?.let { doc.finishPage(it) }
    doc.writeTo(out); doc.close()
}


/* ---------------------------------------------------------------- Fuera de Ascenso financiero (igual que la web)
 * Los hitos se crean y se editan solo en Ascenso. Afuera aparecen en tres puntos, solo para ver y con el camino a «Mis hitos»:
 * la banderita en los años de Mi vida en años, la lista corta en el año (Mi ruta) y el recuerdo en Hoy la semana del aniversario.
 * Con el Ascenso bloqueado no se ve nada afuera; con los montos ocultos, no van montos. */

/** Los hitos que se pueden mostrar fuera del Ascenso (ninguno si está bloqueado). */
@Composable
private fun hitosDeFuera(): Pair<List<Hito>, Libro> {
    val vm = com.rutaalacima.app.ui.components.rutaViewModel { CuentasViewModel(it) }
    val libro by vm.libro.collectAsStateWithLifecycle()
    val cerrado = libro.bloqueo && System.currentTimeMillis() > vm.abiertoHasta
    return (if (cerrado) emptyList() else libro.hitos) to libro
}

/** Los años con hitos logrados y cuántos tiene cada uno (para Mi vida en años). */
@Composable
fun aniosConHitos(): Map<Int, Int> = hitosDeFuera().first.filter { it.ok }.groupingBy { it.f.take(4).toIntOrNull() ?: 0 }.eachCount()

/** El chip «N con hitos» bajo Mi vida en años: lleva a «Mis hitos». */
@Composable
fun ChipHitosVida(n: Int) {
    if (n == 0) return
    val abrir = irACuentas()
    androidx.compose.material3.AssistChip(onClick = { abrir("hitos") }, label = { Text(stringResource(R.string.hi_anios_con, n)) },
        leadingIcon = { Icon(Icons.Filled.Flag, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.secondary) })
}

/** En el año (Mi ruta): sus hitos financieros, solo para ver, con el botón a «Mis hitos». */
@Composable
fun HitosAnioRuta(anio: Int) {
    val (todos, libro) = hitosDeFuera()
    val l = todos.filter { it.f.startsWith("$anio") }.sortedBy { it.f }
    if (l.isEmpty()) return
    val abrir = irACuentas()
    val plata: (Double) -> String = { if (libro.ocultarFuera || com.rutaalacima.app.seguridad.Discreto.activo) "•••••" else com.rutaalacima.app.domain.model.Cuentas.formato(it, libro.moneda) }
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Flag, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.hi_de_tu_ascenso), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = { abrir("hitos") }) { Text(stringResource(R.string.hi_mis)) }
        }
        l.forEach { h -> FilaHito(h, plata, {}, soloVer = true) {} }
    }
}

/** En Hoy: el recuerdo del aniversario (solo esa semana), con el camino a «Mis hitos». */
@Composable
fun HitosRecuerdoHoy() {
    val (todos, _) = hitosDeFuera()
    val d0 = hoy()
    val r = todos.filter { h -> h.ok && (h.f.take(4).toIntOrNull() ?: d0.year) < d0.year && runCatching {
        ChronoUnit.DAYS.between(d0, LocalDate.parse(d0.year.toString() + h.f.drop(4))) in 0..6 }.getOrDefault(false) }
    if (r.isEmpty()) return
    val abrir = irACuentas()
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Flag, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.hi_recuerdo_t), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            TextButton(onClick = { abrir("hitos") }) { Text(stringResource(R.string.hi_ver_mis)) }
        }
        r.forEach { Recuerdo(it) }
    }
}
