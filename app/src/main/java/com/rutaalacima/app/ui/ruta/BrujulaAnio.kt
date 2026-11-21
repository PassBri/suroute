package com.rutaalacima.app.ui.ruta

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.rutaalacima.app.R
import com.rutaalacima.app.data.local.MetaAnualEntity
import com.rutaalacima.app.data.local.VisionCasillaEntity
import com.rutaalacima.app.data.vision.LibroMetas
import com.rutaalacima.app.domain.model.Mandala
import com.rutaalacima.app.domain.model.MetodoCima
import com.rutaalacima.app.ui.components.RutaCard
import com.rutaalacima.app.ui.planner.PlanMeta
import com.rutaalacima.app.ui.vision.colorCampamento
import com.rutaalacima.app.ui.vision.nombreCodigo

/**
 * El año es su Brújula (igual que la web): la cumbre de ese año y sus 8 campamentos, cada uno con su meta,
 * sus sub-metas (los pasos, con su casilla de ganado y su porcentaje de avance) y cuántas actividades lleva su plan de acción.
 */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
internal fun BrujulaAnioCard(
    anio: Int, casillas: List<VisionCasillaEntity>, anuales: List<MetaAnualEntity>, mandala: Map<String, String>,
    onGanado: (Long, Int) -> Unit, onPct: (Long, Int, Int) -> Unit = { _, _, _ -> }, onAbrirBrujula: () -> Unit, onMeta: (MetaAnualEntity) -> Unit, onCopiar: () -> Unit = {},
) {
    val delAnio = casillas.filter { Mandala.anioDeOrigen(it.origen) == anio }
    val hayGeneral = casillas.any { Mandala.anioDeOrigen(it.origen) == null }
    var confirmar by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf(false) }
    var abierto by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<Pair<Long, Int>?>(null) }
    if (confirmar) androidx.compose.material3.AlertDialog(onDismissRequest = { confirmar = false },
        text = { Text(stringResource(R.string.bja_reemplazar, anio)) },
        confirmButton = { androidx.compose.material3.TextButton(onClick = { confirmar = false; onCopiar() }) { Text(stringResource(R.string.bja_copiar)) } },
        dismissButton = { androidx.compose.material3.TextButton(onClick = { confirmar = false }) { Text(stringResource(R.string.cancelar)) } })
    RutaCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.bja_titulo, anio), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.Bold)
                val (cumbre, _) = Mandala.repartir(delAnio, { it.origen }, { it.eje })
                Text(cumbre?.afirmacion?.ifBlank { cumbre.titulo } ?: stringResource(R.string.bja_sin_brujula, anio),
                    style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
            }
            OutlinedButton(onClick = onAbrirBrujula) {
                Icon(Icons.Filled.Explore, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp))
                Text(stringResource(if (delAnio.isEmpty()) R.string.bja_crear else R.string.bja_abrir))
            }
        }
        if (hayGeneral) androidx.compose.material3.TextButton(onClick = { if (delAnio.isEmpty()) onCopiar() else confirmar = true }) {
            Icon(Icons.Filled.ContentCopy, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.bja_copiar))
        }
        if (delAnio.isEmpty()) return@RutaCard
        val (_, camps) = Mandala.repartir(delAnio, { it.origen }, { it.eje })
        Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Mandala.CAMPAMENTOS_FIJOS.forEachIndexed { i, cod ->
                val c = camps.getOrNull(i) ?: return@forEachIndexed
                val color = colorCampamento(cod)
                val eje = if (cod == "CON") null else cod
                val meta = anuales.filter { it.anio == anio && it.eje == eje }.minByOrNull { it.id }
                val pasos = (0 until Mandala.PASOS).map { p -> p to mandala[Mandala.clave(c.id, p)].orEmpty().trim() }.filter { it.second.isNotEmpty() }
                val ganados = (0 until Mandala.PASOS).count { !mandala[Mandala.claveHecho(c.id, it)].isNullOrBlank() }
                val total = (0 until Mandala.PASOS).sumOf { MetodoCima.avance(MetodoCima.leer(c.id, it, mandala), MetodoCima.DIFICULTAD_INICIAL).toDouble() }.toFloat() / Mandala.PASOS
                Surface(shape = RoundedCornerShape(16.dp), color = color.copy(alpha = .06f), border = BorderStroke(1.dp, color.copy(alpha = .25f))) {
                    Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(nombreCodigo(cod), style = MaterialTheme.typography.labelMedium, color = color, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            Text("$ganados/8 · ${Math.round(total * 100)} %", style = MaterialTheme.typography.labelMedium.copy(fontFeatureSettings = "tnum"), color = color, fontWeight = FontWeight.Bold)
                        }
                        Text(meta?.titulo ?: c.afirmacion.ifBlank { c.titulo }, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(enabled = meta != null) { meta?.let(onMeta) })
                        LinearProgressIndicator(progress = { total }, modifier = Modifier.fillMaxWidth().height(4.dp), color = color, trackColor = color.copy(alpha = .14f))
                        pasos.forEach { (p, t) ->
                            val x = MetodoCima.leer(c.id, p, mandala)
                            val ganado = x.cumplido
                            val v = if (ganado) 100 else Math.round(MetodoCima.avance(x, MetodoCima.DIFICULTAD_INICIAL) * 100)
                            val abiertoAqui = abierto == (c.id to p)
                            Row(Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
                                Row(Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp)).clickable { onGanado(c.id, p) },
                                    verticalAlignment = Alignment.CenterVertically) {
                                    Box(Modifier.size(24.dp).clip(CircleShape).background(if (ganado) color else Color.Transparent)
                                        .border(2.dp, if (ganado) color else color.copy(alpha = .5f), CircleShape), contentAlignment = Alignment.Center) {
                                        if (ganado) Icon(Icons.Filled.Check, null, Modifier.size(14.dp), tint = Color.White)
                                    }
                                    Spacer(Modifier.width(10.dp))
                                    Column(Modifier.weight(1f)) {
                                        Text(t, style = MaterialTheme.typography.bodyMedium,
                                            textDecoration = if (ganado) TextDecoration.LineThrough else null,
                                            color = if (ganado) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                                        if (!ganado && v > 0) LinearProgressIndicator(progress = { v / 100f }, modifier = Modifier.padding(top = 3.dp).fillMaxWidth().height(2.dp),
                                            color = color, trackColor = color.copy(alpha = .14f), drawStopIndicator = {}, gapSize = 0.dp)
                                    }
                                }
                                Spacer(Modifier.width(8.dp))
                                // La píldora del avance: abre el deslizador y los atajos (igual que la web)
                                val desc = stringResource(R.string.bja_avance_de, t, v)
                                Surface(onClick = { abierto = if (abiertoAqui) null else c.id to p }, shape = RoundedCornerShape(50),
                                    color = if (v in 1..99) color.copy(alpha = .10f) else Color.Transparent,
                                    border = if (ganado) null else BorderStroke(1.dp, if (v > 0) color.copy(alpha = .45f) else MaterialTheme.colorScheme.outlineVariant),
                                    modifier = Modifier.heightIn(min = 36.dp).widthIn(min = 56.dp).semantics { contentDescription = desc }) {
                                    Box(contentAlignment = Alignment.Center, modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp)) {
                                        Text("$v %", style = MaterialTheme.typography.labelLarge.copy(fontFeatureSettings = "tnum"),
                                            color = if (v > 0) androidx.compose.ui.graphics.lerp(color, MaterialTheme.colorScheme.onSurface, .35f) else MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                            }
                            androidx.compose.animation.AnimatedVisibility(abiertoAqui) {
                                var deslizando by androidx.compose.runtime.remember(v) { androidx.compose.runtime.mutableFloatStateOf(v.toFloat()) }
                                Column(Modifier.fillMaxWidth().padding(start = 34.dp, bottom = 6.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        androidx.compose.material3.Slider(value = deslizando, onValueChange = { deslizando = it }, valueRange = 0f..100f, steps = 19,
                                            onValueChangeFinished = { onPct(c.id, p, Math.round(deslizando)) }, modifier = Modifier.weight(1f),
                                            colors = androidx.compose.material3.SliderDefaults.colors(thumbColor = color, activeTrackColor = color, inactiveTrackColor = color.copy(alpha = .18f),
                                                activeTickColor = Color.Transparent, inactiveTickColor = Color.Transparent))
                                        Text("${Math.round(deslizando)} %", style = MaterialTheme.typography.labelLarge.copy(fontFeatureSettings = "tnum"),
                                            modifier = Modifier.padding(start = 8.dp).widthIn(min = 44.dp))
                                    }
                                    androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        listOf(0, 25, 50, 75, 100).forEach { n ->
                                            androidx.compose.material3.FilterChip(selected = v == n, onClick = { onPct(c.id, p, n); if (n == 100) abierto = null },
                                                label = { Text(if (n == 100) stringResource(R.string.foco_ganada) else "$n %") })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
