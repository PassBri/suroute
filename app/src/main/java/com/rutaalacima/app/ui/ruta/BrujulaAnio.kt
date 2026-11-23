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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
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
/** El % puesto a mano a un campamento con sub-metas (null = manda el de las sub-metas). Igual que la web (vision:mano). */
internal fun manoCamp(id: Long, vision: Map<String, String>): Int? = vision["vision:mano:$id"]?.trim()?.takeIf { it.isNotEmpty() }?.toFloatOrNull()?.let { Math.round(it).coerceIn(0, 100) }

/** Avance (0–1) de un campamento, el mismo en Mi ruta y en la Brújula: con sub-metas, lo puesto a mano o su promedio; sin ellas, lo marcado en la casilla. */
internal fun avanceCamp(id: Long, mandala: Map<String, String>, vision: Map<String, String>, dif: Int): Float {
    val pasos = (0 until Mandala.PASOS).map { MetodoCima.leer(id, it, mandala) }
    if (pasos.any { it.escrito }) return manoCamp(id, vision)?.let { it / 100f } ?: (pasos.sumOf { MetodoCima.avance(it, dif).toDouble() }.toFloat() / Mandala.PASOS)
    if (vision["vision:estado:$id"] == "LOGRADA") return 1f
    return ((vision["vision:pct:$id"]?.toFloatOrNull() ?: 0f) / 100f).coerceIn(0f, 1f)
}

@Composable
internal fun BrujulaAnioCard(
    anio: Int, casillas: List<VisionCasillaEntity>, anuales: List<MetaAnualEntity>, mandala: Map<String, String>,
    onGanado: (Long, Int) -> Unit, onPct: (Long, Int, Int) -> Unit = { _, _, _ -> },
    vision: Map<String, String> = emptyMap(), onMano: (Long, Int?) -> Unit = { _, _ -> }, onAbrirBrujula: () -> Unit, onMeta: (MetaAnualEntity) -> Unit, onCopiar: () -> Unit = {},
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
        // Cabecera centrada: la cumbre del año, su avance general y las acciones (igual que la web)
        val (cumbre, campsCab) = Mandala.repartir(delAnio, { it.origen }, { it.eje })
        // La misma dificultad con la que la Brújula cuenta las jornadas: así los porcentajes coinciden en los dos lados
        val dif = androidx.compose.runtime.remember(campsCab, mandala) {
            MetodoCima.calcular(MetodoCima.pasosDe(campsCab.map { it?.id }, mandala), java.time.LocalDate.now()).dificultad }
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.bja_titulo, anio), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.Bold)
            Text(cumbre?.afirmacion?.ifBlank { cumbre.titulo } ?: stringResource(R.string.bja_sin_brujula, anio),
                style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center, fontWeight = FontWeight.SemiBold)
            if (delAnio.isNotEmpty()) {
                var ganadasAnio = 0
                campsCab.forEach { c -> if (c != null) for (p in 0 until Mandala.PASOS) if (MetodoCima.leer(c.id, p, mandala).cumplido) ganadasAnio++ }
                val totalAnio = campsCab.sumOf { c -> (c?.let { avanceCamp(it.id, mandala, vision, dif) } ?: 0f).toDouble() }.toFloat() / Mandala.CAMPAMENTOS_FIJOS.size
                Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.secondary.copy(alpha = .08f),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.secondary.copy(alpha = .3f)), modifier = Modifier.padding(top = 4.dp).widthIn(max = 420.dp).fillMaxWidth()) {
                    Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text(stringResource(R.string.bja_avance_anio), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                            Text("${Math.round(totalAnio * 100)} %", style = MaterialTheme.typography.headlineSmall.copy(fontFeatureSettings = "tnum"), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                        }
                        LinearProgressIndicator(progress = { totalAnio }, modifier = Modifier.fillMaxWidth().height(4.dp), color = MaterialTheme.colorScheme.primary, trackColor = MaterialTheme.colorScheme.primary.copy(alpha = .14f))
                        Text(stringResource(R.string.bja_ganadas_anio, ganadasAnio), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(onClick = onAbrirBrujula) {
                    Icon(Icons.Filled.Explore, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp))
                    Text(stringResource(if (delAnio.isEmpty()) R.string.bja_crear else R.string.bja_abrir))
                }
                if (hayGeneral) androidx.compose.material3.TextButton(onClick = { if (delAnio.isEmpty()) onCopiar() else confirmar = true }) {
                    Icon(Icons.Filled.ContentCopy, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.bja_copiar))
                }
            }
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
                val total = avanceCamp(c.id, mandala, vision, dif)
                val mano = manoCamp(c.id, vision)
                val porPasosPct = Math.round((0 until Mandala.PASOS).sumOf { MetodoCima.avance(MetodoCima.leer(c.id, it, mandala), dif).toDouble() }.toFloat() / Mandala.PASOS * 100)
                val ajustando = abierto == (c.id to -1)
                Surface(shape = RoundedCornerShape(16.dp), color = color.copy(alpha = .06f), border = BorderStroke(1.dp, color.copy(alpha = .25f))) {
                    Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(nombreCodigo(cod), style = MaterialTheme.typography.labelMedium, color = color, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            // Tocar el avance del campamento abre su barra para ponerlo a mano (el mismo dato que la casilla de la Brújula)
                            val descCamp = stringResource(R.string.bja_ajustar_camp, Math.round(total * 100))
                            Text("$ganados/8 · ${Math.round(total * 100)} %", style = MaterialTheme.typography.labelMedium.copy(fontFeatureSettings = "tnum"), color = color, fontWeight = FontWeight.Bold,
                                modifier = Modifier.clip(RoundedCornerShape(50)).clickable { abierto = if (ajustando) null else c.id to -1 }
                                    .heightIn(min = 36.dp).padding(horizontal = 8.dp, vertical = 8.dp).semantics { contentDescription = descCamp })
                        }
                        Text(meta?.titulo ?: c.afirmacion.ifBlank { c.titulo }, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(enabled = meta != null) { meta?.let(onMeta) })
                        LinearProgressIndicator(progress = { total }, modifier = Modifier.fillMaxWidth().height(4.dp), color = color, trackColor = color.copy(alpha = .14f))
                        if (mano != null || ajustando) Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(if (mano != null) stringResource(R.string.bja_mano_info, porPasosPct) else stringResource(R.string.bja_por_submetas, porPasosPct),
                                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                            if (mano != null) androidx.compose.material3.TextButton(onClick = { onMano(c.id, null) }) { Text(stringResource(R.string.bja_usar_submetas)) }
                        }
                        androidx.compose.animation.AnimatedVisibility(ajustando) {
                            val v = Math.round(total * 100)
                            var deslizando by androidx.compose.runtime.remember(v) { androidx.compose.runtime.mutableFloatStateOf(v.toFloat()) }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                androidx.compose.material3.IconButton(onClick = { onMano(c.id, (v - 1).coerceAtLeast(0)) }, enabled = v > 0) { Icon(Icons.Filled.Remove, stringResource(R.string.bja_menos_uno)) }
                                androidx.compose.material3.Slider(value = deslizando, onValueChange = { deslizando = Math.round(it).toFloat() }, valueRange = 0f..100f,
                                    onValueChangeFinished = { onMano(c.id, Math.round(deslizando)) }, modifier = Modifier.weight(1f),
                                    colors = androidx.compose.material3.SliderDefaults.colors(thumbColor = color, activeTrackColor = color, inactiveTrackColor = color.copy(alpha = .18f)))
                                androidx.compose.material3.IconButton(onClick = { onMano(c.id, (v + 1).coerceAtMost(100)) }, enabled = v < 100) { Icon(Icons.Filled.Add, stringResource(R.string.bja_mas_uno)) }
                                Text("${Math.round(deslizando)} %", style = MaterialTheme.typography.labelLarge.copy(fontFeatureSettings = "tnum"), modifier = Modifier.widthIn(min = 44.dp))
                            }
                        }
                        pasos.forEach { (p, t) ->
                            val x = MetodoCima.leer(c.id, p, mandala)
                            val ganado = x.cumplido
                            val v = if (ganado) 100 else Math.round(MetodoCima.avance(x, dif) * 100)
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
                                Column(Modifier.fillMaxWidth().padding(start = 22.dp, bottom = 6.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        // − y + mueven de a 1 % para llegar a cualquier número (67 %, por ejemplo)
                                        androidx.compose.material3.IconButton(onClick = { onPct(c.id, p, (v - 1).coerceAtLeast(0)) }, enabled = v > 0) {
                                            Icon(Icons.Filled.Remove, stringResource(R.string.bja_menos_uno)) }
                                        androidx.compose.material3.Slider(value = deslizando, onValueChange = { deslizando = Math.round(it).toFloat() }, valueRange = 0f..100f,
                                            onValueChangeFinished = { onPct(c.id, p, Math.round(deslizando)) }, modifier = Modifier.weight(1f),
                                            colors = androidx.compose.material3.SliderDefaults.colors(thumbColor = color, activeTrackColor = color, inactiveTrackColor = color.copy(alpha = .18f),
                                                activeTickColor = Color.Transparent, inactiveTickColor = Color.Transparent))
                                        androidx.compose.material3.IconButton(onClick = { onPct(c.id, p, (v + 1).coerceAtMost(100)) }, enabled = v < 100) {
                                            Icon(Icons.Filled.Add, stringResource(R.string.bja_mas_uno)) }
                                        Text("${Math.round(deslizando)} %", style = MaterialTheme.typography.labelLarge.copy(fontFeatureSettings = "tnum"),
                                            modifier = Modifier.padding(start = 8.dp).widthIn(min = 44.dp))
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
