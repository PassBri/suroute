package com.rutaalacima.app.ui.comunidad

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rutaalacima.app.R
import com.rutaalacima.app.RutaApp
import com.rutaalacima.app.data.local.diasMarcados
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * «Tu paso de hoy» encima de Comunidad: las metas del mes con un toque para marcar el paso del día.
 * Así lo social lleva a la acción en vez de reemplazarla. Desaparece en cuanto hay un paso dado hoy
 * (y no aparece si no hay metas del mes). Marca el día igual que «Paso de hoy» en Mi ruta.
 */
@Composable
fun FranjaPasoHoy(sobreOscuro: Boolean, modifier: Modifier = Modifier) {
    val c = (androidx.compose.ui.platform.LocalContext.current.applicationContext as RutaApp).container
    val mensuales by c.planAnual.todasMetasMes.collectAsStateWithLifecycle(emptyList())
    val anuales by c.planificador.todasLasMetas.collectAsStateWithLifecycle(emptyList())
    val hoy = com.rutaalacima.app.util.hoy()
    val metas = mensuales.filter { it.anio == hoy.year && it.mes == hoy.monthValue && !it.cumplida }
    val dado = metas.any { hoy.dayOfMonth in it.diasMarcados() }
    var celebrando by remember { mutableStateOf(false) }
    val alcance = rememberCoroutineScope()
    val haptico = androidx.compose.ui.platform.LocalHapticFeedback.current
    LaunchedEffect(celebrando) { if (celebrando) { delay(2200); celebrando = false } }
    val tinta = if (sobreOscuro) Color.White else MaterialTheme.colorScheme.onSurface
    val fondo = if (sobreOscuro) Color.White.copy(alpha = .12f) else MaterialTheme.colorScheme.surfaceContainerHigh
    val borde = if (sobreOscuro) Color.White.copy(alpha = .22f) else MaterialTheme.colorScheme.outlineVariant
    AnimatedVisibility(metas.isNotEmpty() && (!dado || celebrando), modifier, enter = fadeIn(tween(220)), exit = fadeOut(tween(220)) + shrinkVertically(tween(260))) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(fondo).border(1.dp, borde, RoundedCornerShape(20.dp))
            .padding(start = 12.dp, end = 6.dp, top = 6.dp, bottom = 6.dp).heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(com.rutaalacima.app.ui.components.IconosRuta.Huellas, null, tint = MaterialTheme.colorScheme.secondary.takeIf { !sobreOscuro } ?: Color(0xFFE8C77A), modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            if (celebrando) Text(stringResource(R.string.paso_hoy_dado), color = tinta, style = MaterialTheme.typography.labelLarge)
            else {
                Text(stringResource(R.string.paso_hoy_tu), color = tinta, style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.width(8.dp))
                Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    metas.forEach { m ->
                        val anual = anuales.firstOrNull { it.id == m.metaAnualId }
                        Row(Modifier.clip(RoundedCornerShape(50)).border(1.dp, borde, RoundedCornerShape(50))
                            .clickable {
                                haptico.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
                                alcance.launch { c.planAnual.alternarDia(m, hoy.dayOfMonth) }; celebrando = true
                            }.heightIn(min = 36.dp).padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            androidx.compose.foundation.layout.Box(Modifier.size(8.dp).clip(CircleShape).background(com.rutaalacima.app.ui.vision.colorEje(anual?.eje ?: "CON")))
                            Spacer(Modifier.width(6.dp))
                            Text(anual?.titulo ?: m.texto, color = tinta, style = MaterialTheme.typography.labelMedium, maxLines = 1,
                                overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 150.dp))
                            Spacer(Modifier.width(4.dp))
                            Icon(Icons.Filled.Check, stringResource(R.string.paso_hoy_marcar, anual?.titulo ?: m.texto), tint = tinta.copy(alpha = .7f), modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }
    }
}
