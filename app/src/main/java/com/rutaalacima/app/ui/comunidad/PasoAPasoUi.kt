package com.rutaalacima.app.ui.comunidad

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Stairs
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rutaalacima.app.R
import com.rutaalacima.app.data.social.PasoAPaso
import com.rutaalacima.app.data.social.PasoP
import com.rutaalacima.app.data.social.Post
import java.time.YearMonth
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/* =====================================================================================
 * Paso a paso (igual que la web, web/js/57-paso-a-paso.js): el recorrido de una meta lograda,
 * como la hoja de controles de una carrera de orientación: la salida (triángulo), los controles
 * numerados y la meta (doble círculo), en el magenta de los mapas de orientación.
 * ===================================================================================== */

/** El magenta de la orientación, según el papel claro u oscuro. */
@Composable
fun magentaRuta(): Color = if (MaterialTheme.colorScheme.surface.luminance() < .5f) Color(0xFFE07AB8) else Color(0xFFB5307E)

private fun mesCorto(f: String): String = runCatching {
    val ym = YearMonth.parse(f.take(7))
    val dia = f.drop(8).toIntOrNull()
    (if (dia != null) "$dia " else "") + ym.month.getDisplayName(TextStyle.SHORT, Locale.getDefault()).trimEnd('.') + " " + ym.year
}.getOrDefault("")

private enum class Marca { SALIDA, CONTROL, CUMBRE }

/** El ícono de la hoja de controles: triángulo, círculo numerado o doble círculo. */
@Composable
private fun MarcaRuta(tipo: Marca, n: Int, lado: Dp, color: Color) {
    val papel = MaterialTheme.colorScheme.surface
    Box(Modifier.size(lado), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(lado)) {
            val w = size.width; val g = w * .08f
            when (tipo) {
                Marca.SALIDA -> drawPath(Path().apply { moveTo(w / 2, g); lineTo(w - g, w - g * 1.5f); lineTo(g, w - g * 1.5f); close() }, papel).also {
                    drawPath(Path().apply { moveTo(w / 2, g); lineTo(w - g, w - g * 1.5f); lineTo(g, w - g * 1.5f); close() }, color, style = Stroke(g)) }
                Marca.CONTROL -> { drawCircle(papel, w / 2 - g / 2); drawCircle(color, w / 2 - g / 2, style = Stroke(g)) }
                Marca.CUMBRE -> { drawCircle(papel, w / 2 - g / 2); drawCircle(color, w / 2 - g / 2, style = Stroke(g)); drawCircle(color, w / 2 - g * 2.6f, style = Stroke(g)) }
            }
        }
        if (tipo == Marca.CONTROL) Text("$n", color = color, fontWeight = FontWeight.SemiBold, fontSize = (lado.value * .4f).sp)
    }
}

/** Una fila del recorrido: la marca a la izquierda (con la línea hacia la siguiente) y el texto. */
@Composable
private fun FilaRuta(tipo: Marca, n: Int, lado: Dp, color: Color, ultima: Boolean, contenido: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
        Box(Modifier.width(lado).fillMaxHeight().drawBehind {
            if (!ultima) drawLine(color.copy(alpha = .55f), Offset(size.width / 2, lado.toPx()), Offset(size.width / 2, size.height), strokeWidth = 2.dp.toPx())
        }) { MarcaRuta(tipo, n, lado, color) }
        Spacer(Modifier.width(10.dp))
        Box(Modifier.weight(1f).padding(bottom = 10.dp)) { contenido() }
    }
}

/**
 * El recorrido: la meta arriba, la salida, los pasos y la cumbre.
 * [max]: cuántos pasos mostrar (el resto queda en «Ver los N pasos»); [conDetalle]: mostrar fecha y detalle.
 */
@Composable
fun RecorridoPasos(r: PasoAPaso, modifier: Modifier = Modifier, max: Int = PasoAPaso.MAX, conDetalle: Boolean = true, conCumbre: Boolean = true, onVerTodo: (() -> Unit)? = null) {
    val mag = magentaRuta(); val n = r.pasos.size; val ver = r.pasos.take(max); val lado = if (conDetalle) 34.dp else 28.dp
    val desc = pluralStringResource(R.plurals.pap_n, n, n)
    Column(modifier.semantics(mergeDescendants = false) { contentDescription = "${r.meta} · $desc" }) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 8.dp)) {
            Icon(Icons.Filled.Stairs, null, tint = mag, modifier = Modifier.size(22.dp)); Spacer(Modifier.width(10.dp))
            Text(r.meta.ifBlank { stringResource(R.string.pap_como) }, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium,
                fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold)
            Text(desc, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        FilaRuta(Marca.SALIDA, 0, lado, mag, false) {
            Text(stringResource(R.string.pap_salida), Modifier.padding(top = 6.dp), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        ver.forEachIndexed { i, p ->
            val ultima = !conCumbre && i == ver.lastIndex && n <= max
            FilaRuta(Marca.CONTROL, i + 1, lado, mag, ultima) {
                Column(Modifier.padding(top = 5.dp)) {
                    Text(p.t, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, maxLines = if (conDetalle) 4 else 2, overflow = TextOverflow.Ellipsis)
                    val sub = if (conDetalle) listOf(mesCorto(p.f), p.d).filter { it.isNotBlank() }.joinToString(" · ") else ""
                    if (sub.isNotBlank()) Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        if (n > max && onVerTodo != null) Row {
            Spacer(Modifier.width(lado + 4.dp))
            TextButton(onClick = onVerTodo) { Text(stringResource(R.string.pap_ver_todos, n), color = mag) }
        }
        if (conCumbre) FilaRuta(Marca.CUMBRE, 0, lado, mag, true) {
            Text(if (r.meta.isBlank()) stringResource(R.string.pap_cumbre_sola) else stringResource(R.string.pap_cumbre, r.meta), Modifier.padding(top = 6.dp),
                style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** En el muro: el recorrido en su hoja de papel (hasta 4 pasos). */
@Composable
fun PasoAPasoTarjeta(post: Post, modifier: Modifier = Modifier) {
    val r = post.pasoAPaso ?: return
    if (com.rutaalacima.app.data.social.ComunidadViva.estaSellada(post)) return
    var hoja by remember { mutableStateOf(false) }
    Surface(modifier, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
        RecorridoPasos(r, Modifier.padding(14.dp), max = 4, onVerTodo = { hoja = true })
    }
    if (hoja) PasoAPasoHoja(post) { hoja = false }
}

/** La hoja con el recorrido completo y lo que le diría a quien empieza. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PasoAPasoHoja(post: Post, onCerrar: () -> Unit) {
    val r = post.pasoAPaso ?: return
    ModalBottomSheet(onDismissRequest = onCerrar) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp).navigationBarsPadding()) {
            Text(stringResource(R.string.pap_de, post.autorNombre), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 10.dp))
            RecorridoPasos(r)
            if (post.texto.isNotBlank()) Text(post.texto, Modifier.padding(top = 12.dp), style = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic))
            TextButton(onClick = onCerrar, modifier = Modifier.align(Alignment.End)) { Text(stringResource(R.string.audio_cerrar_corto)) }
        }
    }
}

/** En Cimas sin foto: el recorrido sobre el mapa de orientación. */
@Composable
fun PasoAPasoFondo(post: Post, modifier: Modifier = Modifier) {
    val r = post.pasoAPaso ?: return
    var hoja by remember { mutableStateOf(false) }
    Box(modifier) {
        com.rutaalacima.app.ui.components.MapaOrientacion(Modifier.matchParentSize(), conRuta = false)
        Box(Modifier.fillMaxWidth().padding(start = 16.dp, end = 80.dp, top = 116.dp), contentAlignment = Alignment.TopStart) {
            Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface.copy(alpha = .96f), shadowElevation = 6.dp) {
                RecorridoPasos(r, Modifier.padding(12.dp), max = 2, conDetalle = false, conCumbre = false, onVerTodo = { hoja = true })
            }
        }
    }
    if (hoja) PasoAPasoHoja(post) { hoja = false }
}

/** En Cimas con foto: la píldora para ver el recorrido. */
@Composable
fun PasoAPasoChip(post: Post) {
    val r = post.pasoAPaso ?: return
    if (com.rutaalacima.app.data.social.ComunidadViva.estaSellada(post)) return
    var hoja by remember { mutableStateOf(false) }
    Row(Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.16f)).border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(50))
        .clickable { hoja = true }.padding(horizontal = 12.dp, vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Stairs, null, tint = Color.White, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(6.dp))
        Text(stringResource(R.string.pap_ver_su) + " · " + pluralStringResource(R.plurals.pap_n, r.pasos.size, r.pasos.size), color = Color.White, style = MaterialTheme.typography.labelMedium)
    }
    if (hoja) PasoAPasoHoja(post) { hoja = false }
}

/* ---------------------------------------------------------------- En «Publicar» */

/** ¿Qué publicar? Un momento (lo de siempre) o el paso a paso de una meta lograda. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModoPublicar(vm: PublicarViewModel) {
    androidx.compose.material3.SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        listOf(false to R.string.pap_un_momento, true to R.string.pap_titulo).forEachIndexed { i, (v, t) ->
            androidx.compose.material3.SegmentedButton(selected = vm.modoPasos == v,
                onClick = { vm.modoPasos = v; if (v) vm.tipo = com.rutaalacima.app.data.social.TipoPost.LOGRO },
                shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(i, 2),
                icon = { Icon(if (v) Icons.Filled.Stairs else Icons.Filled.Add, null, Modifier.size(18.dp)) }) { Text(stringResource(t)) }
        }
    }
}

/** El editor del recorrido: la meta, traer los pasos de una meta propia y cada paso con su mes y su detalle. */
@Composable
fun EditorPasoAPaso(vm: PublicarViewModel) {
    val mag = magentaRuta()
    var menu by remember { mutableStateOf(false) }
    var eligiendoMes by remember { mutableStateOf<Int?>(null) }
    val ctx = androidx.compose.ui.platform.LocalContext.current
    Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.pap_ayuda), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(vm.pasoMeta, { vm.pasoMeta = it.take(PasoAPaso.MAX_META) }, Modifier.fillMaxWidth(), singleLine = true,
                label = { Text(stringResource(R.string.pap_que_lograste)) }, placeholder = { Text(stringResource(R.string.pap_que_lograste_ej)) })
            if (vm.fuentesPasos.isNotEmpty()) Box {
                OutlinedButton(onClick = { menu = true }) { Icon(Icons.Filled.CalendarMonth, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text(stringResource(R.string.pap_traer)) }
                DropdownMenu(menu, { menu = false }) {
                    vm.fuentesPasos.forEachIndexed { i, (a, _) ->
                        DropdownMenuItem(text = { Text("${a.titulo} · ${a.anio}", maxLines = 2) }, onClick = {
                            menu = false; val n = vm.traerPasos(i)
                            com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.resources.getQuantityString(R.plurals.pap_traidos, n, n, a.titulo))
                        })
                    }
                }
            }
            vm.pasos.forEachIndexed { i, p ->
                Row(verticalAlignment = Alignment.Top) {
                    Box(Modifier.padding(top = 14.dp)) { MarcaRuta(Marca.CONTROL, i + 1, 30.dp, mag) }
                    Spacer(Modifier.width(8.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        OutlinedTextField(p.t, { vm.pasos[i] = p.copy(t = it.take(PasoAPaso.MAX_T)) }, Modifier.fillMaxWidth(),
                            label = { Text(stringResource(R.string.pap_paso_n, i + 1)) }, placeholder = { Text(stringResource(R.string.pap_paso_ej)) })
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            TextButton(onClick = { eligiendoMes = i }) {
                                Icon(Icons.Filled.CalendarMonth, null, Modifier.size(16.dp)); Spacer(Modifier.width(4.dp))
                                Text(mesCorto(p.f).ifBlank { stringResource(R.string.pap_mes) })
                            }
                            OutlinedTextField(p.d, { vm.pasos[i] = p.copy(d = it.take(PasoAPaso.MAX_D)) }, Modifier.weight(1f), singleLine = true,
                                placeholder = { Text(stringResource(R.string.pap_detalle)) }, textStyle = MaterialTheme.typography.bodyMedium)
                        }
                    }
                    Column {
                        IconButton(onClick = { if (i > 0) { val x = vm.pasos[i - 1]; vm.pasos[i - 1] = vm.pasos[i]; vm.pasos[i] = x } }, enabled = i > 0) {
                            Icon(Icons.Filled.KeyboardArrowUp, stringResource(R.string.pap_subir, i + 1)) }
                        IconButton(onClick = { vm.pasos.removeAt(i) }) { Icon(Icons.Filled.Delete, stringResource(R.string.pap_quitar, i + 1)) }
                    }
                }
            }
            if (vm.pasos.size < PasoAPaso.MAX) TextButton(onClick = { vm.pasos.add(PasoP("")) }) {
                Icon(Icons.Filled.Add, null); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.pap_agregar)) }
        }
    }
    eligiendoMes?.let { i -> MesDialogo(vm.pasos.getOrNull(i)?.f.orEmpty(), onListo = { f -> vm.pasos.getOrNull(i)?.let { vm.pasos[i] = it.copy(f = f) }; eligiendoMes = null }) { eligiendoMes = null } }
}

/** Elegir el mes de un paso (se guarda "aaaa-mm"). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MesDialogo(actual: String, onListo: (String) -> Unit, onCancelar: () -> Unit) {
    val inicial = runCatching { YearMonth.parse(actual.take(7)).atDay(1) }.getOrElse { java.time.LocalDate.now() }
    val estado = rememberDatePickerState(initialSelectedDateMillis = inicial.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli())
    DatePickerDialog(onDismissRequest = onCancelar, confirmButton = {
        TextButton(onClick = {
            val ms = estado.selectedDateMillis ?: return@TextButton onCancelar()
            onListo(java.time.Instant.ofEpochMilli(ms).atZone(ZoneOffset.UTC).toLocalDate().format(DateTimeFormatter.ofPattern("yyyy-MM")))
        }) { Text(stringResource(android.R.string.ok)) }
    }, dismissButton = { TextButton(onClick = onCancelar) { Text(stringResource(android.R.string.cancel)) } }) { DatePicker(estado) }
}
