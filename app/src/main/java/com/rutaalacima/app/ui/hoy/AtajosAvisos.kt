package com.rutaalacima.app.ui.hoy

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AddCircleOutline
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.FormatQuote
import androidx.compose.material.icons.filled.Landscape
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.rutaalacima.app.AppContainer
import com.rutaalacima.app.R
import com.rutaalacima.app.data.local.MetaMensualEntity
import com.rutaalacima.app.data.local.avance
import com.rutaalacima.app.data.local.diasMarcados
import com.rutaalacima.app.ui.Rutas
import com.rutaalacima.app.ui.components.IconosRuta
import com.rutaalacima.app.ui.components.rutaViewModel
import com.rutaalacima.app.util.hoy
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.YearMonth
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

// ====================================================================== Lo que más haces

/** Los atajos que se pueden poner en Hoy (los mismos ids que ATAJOS en la web: libro "hoy", clave "atajos"). */
object Atajos {
    const val WB = "hoy"
    const val CLAVE = "atajos"
    data class Atajo(val id: String, val nombre: Int, val icono: ImageVector, val ruta: () -> String)
    val TODOS: List<Atajo> by lazy {
        listOf(
            Atajo("gasto", R.string.at_gasto, IconosRuta.Finanzas) { Rutas.finanzas("d:" + hoy()) },
            Atajo("brujula", R.string.ruta_brujula, Icons.Filled.Explore) { Rutas.VISION },
            Atajo("publicar", R.string.at_publicar, Icons.Filled.AddCircleOutline) { Rutas.publicar() },
            Atajo("coach", R.string.coach, IconosRuta.Coach) { Rutas.COACH },
            Atajo("frase", R.string.at_frase, Icons.Filled.FormatQuote) { Rutas.FRASES },
            Atajo("dia", R.string.at_dia, IconosRuta.Huellas) { Rutas.planificador(1, hoy()) },
            Atajo("metas", R.string.at_metas, Icons.Filled.Flag) { Rutas.planificador(0) },
            Atajo("bienestar", R.string.at_bienestar, Icons.Filled.SelfImprovement) { Rutas.BIENESTAR },
            Atajo("alto", R.string.alto_titulo, Icons.Filled.Landscape) { Rutas.ALTO },
            Atajo("comunidad", R.string.tab_comunidad, IconosRuta.Fogata) { Rutas.COMUNIDAD },
            Atajo("mensajes", R.string.mensajes, IconosRuta.Radio) { Rutas.MENSAJES },
            Atajo("aprende", R.string.tab_aprende, IconosRuta.MapaRuta) { Rutas.APRENDE },
        )
    }
    val BASE = listOf("gasto", "brujula", "publicar", "coach")
    fun elegidos(v: String?): List<String> =
        v?.split(",")?.filter { id -> TODOS.any { it.id == id } }?.take(4)?.takeIf { it.isNotEmpty() } ?: BASE
}

class AtajosViewModel(private val c: AppContainer) : ViewModel() {
    val elegidos: StateFlow<List<String>> = c.respuestas.observar(Atajos.WB).map { Atajos.elegidos(it[Atajos.CLAVE]) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, Atajos.BASE)
    fun guardar(l: List<String>) = viewModelScope.launch { c.respuestas.guardar(Atajos.WB, Atajos.CLAVE, l.joinToString(",")) }
}

/** «Lo que más haces»: 4 atajos que la persona elige; con Editar se cambian (como en la banca móvil). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LoQueMasHaces(onIrA: (String) -> Unit) {
    val vm = rutaViewModel { AtajosViewModel(it) }
    val sel by vm.elegidos.collectAsStateWithLifecycle()
    var editar by rememberSaveable { mutableStateOf(false) }
    val minimo = stringResource(R.string.lqh_min); val maximo = stringResource(R.string.lqh_max)
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.lqh_titulo), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            TextButton(onClick = { editar = !editar }) { Text(stringResource(if (editar) R.string.lqh_listo else R.string.lqh_editar)) }
        }
        if (editar) {
            Text(stringResource(R.string.lqh_ayuda), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Atajos.TODOS.forEach { a ->
                    val pos = sel.indexOf(a.id)
                    FilterChip(
                        selected = pos >= 0,
                        onClick = {
                            when {
                                pos >= 0 && sel.size == 1 -> com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(minimo)
                                pos >= 0 -> vm.guardar(sel - a.id)
                                sel.size >= 4 -> com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(maximo)
                                else -> vm.guardar(sel + a.id)
                            }
                        },
                        label = { Text(stringResource(a.nombre)) },
                        leadingIcon = {
                            if (pos >= 0) Box(Modifier.size(20.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary), contentAlignment = Alignment.Center) {
                                Text("${pos + 1}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onPrimary, fontWeight = FontWeight.Bold)
                            } else Icon(a.icono, null, Modifier.size(18.dp))
                        },
                    )
                }
            }
        } else {
            Row(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                sel.mapNotNull { id -> Atajos.TODOS.firstOrNull { it.id == id } }.forEach { a ->
                    val nombre = stringResource(a.nombre)
                    Column(
                        Modifier.weight(1f).clip(RoundedCornerShape(14.dp)).clickable { onIrA(a.ruta()) }.padding(vertical = 6.dp)
                            .semantics(mergeDescendants = true) {},
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Surface(
                            shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerLowest,
                            modifier = Modifier.size(56.dp).shadow(3.dp, CircleShape, clip = false),
                        ) {
                            Box(contentAlignment = Alignment.Center) { Icon(a.icono, null, Modifier.size(26.dp), tint = MaterialTheme.colorScheme.primary) }
                        }
                        Spacer(Modifier.height(6.dp))
                        Text(nombre, style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center, maxLines = 2,
                            overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                repeat(4 - sel.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

// ====================================================================== Avisos del día

private data class Aviso(val icono: ImageVector, val titulo: String, val texto: String, val ruta: String, val pronto: Boolean = false)

/**
 * Los avisos del día en un carrusel (1 de 3, pausa y flechas, como la banca): el trámite o pago más cercano,
 * una deuda sin pago este mes, el Alto en el camino del mes y la meta del mes que más falta. Igual que la web.
 * Pasa solo cada 7 segundos, salvo con «Quitar animaciones» del sistema o al pausar.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AvisosCarrusel(metasMes: List<MetaMensualEntity>, onIrA: (String) -> Unit) {
    val ctx = LocalContext.current
    val tramites by rutaViewModel { com.rutaalacima.app.ui.tramites.TramitesViewModel(it) }.todos.collectAsStateWithLifecycle()
    val libro by rutaViewModel { com.rutaalacima.app.ui.finanzas.CuentasViewModel(it) }.libro.collectAsStateWithLifecycle()
    val alto by rutaViewModel { com.rutaalacima.app.ui.alto.AltoViewModel(it) }.respuestas.collectAsStateWithLifecycle()
    val h = hoy(); val ym = YearMonth.from(h)
    val mes = ym.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault()).lowercase(Locale.getDefault())

    val avisos = buildList {
        // Trámite o pago más cercano
        tramites.mapNotNull { t -> com.rutaalacima.app.ui.tramites.Plazos.proximo(t, h)?.takeIf { !it.isBefore(h) }?.let { t to it } }
            .minByOrNull { it.second }?.let { (t, p) ->
                val q = ChronoUnit.DAYS.between(h, p).toInt()
                val texto = if (t.mensual) when (q) { 0 -> ctx.getString(R.string.av_pago_hoy); 1 -> ctx.getString(R.string.av_pago_manana); else -> ctx.getString(R.string.av_pago_dias, q) }
                else when (q) { 0 -> ctx.getString(R.string.av_vence_hoy); 1 -> ctx.getString(R.string.av_vence_manana); else -> ctx.getString(R.string.av_vence_dias, q) }
                add(Aviso(Icons.Filled.Alarm, t.n, texto, Rutas.planificador(1, p), q <= 3))
            }
        // Una deuda sin pago este mes (si el módulo no está cerrado con huella)
        if (!libro.bloqueo) libro.deudas.firstOrNull { com.rutaalacima.app.ui.finanzas.estadoDeuda(it, libro, h).k == com.rutaalacima.app.ui.finanzas.EstadoDeudaK.SIN_PAGO }?.let {
            add(Aviso(Icons.Filled.CreditCard, ctx.getString(R.string.av_deuda_t, it.deuda.nombre), ctx.getString(R.string.av_deuda_d), Rutas.finanzas("deudas"), true))
        }
        // Alto en el camino del mes
        val n = (0 until 9).count { !alto[com.rutaalacima.app.ui.alto.Alto.clave(ym, it)].isNullOrBlank() }
        if (n < 9) add(Aviso(Icons.Filled.Landscape, ctx.getString(R.string.alto_titulo),
            if (n == 0) ctx.getString(R.string.av_alto_0, mes) else ctx.getString(R.string.av_alto_n, n, mes), Rutas.ALTO))
        // La meta del mes que más le falta
        metasMes.filter { it.avance() < 1f }.minByOrNull { it.avance() }?.let {
            add(Aviso(Icons.Filled.Flag, ctx.getString(R.string.av_meta_t), ctx.getString(R.string.av_meta_d, it.texto, it.diasMarcados().size, it.objetivoDias), Rutas.planificador(0)))
        }
    }
    if (avisos.isEmpty()) return

    val n = avisos.size
    val estado = rememberPagerState { n }
    val sinAnimar = remember {
        runCatching { android.provider.Settings.Global.getFloat(ctx.contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE) == 0f }.getOrDefault(false)
    }
    var pausa by rememberSaveable { mutableStateOf(sinAnimar) }
    val alcance = rememberCoroutineScope()
    LaunchedEffect(pausa, estado.currentPage, n, estado.isScrollInProgress) {
        if (pausa || n < 2 || estado.isScrollInProgress) return@LaunchedEffect
        delay(7000)
        estado.animateScrollToPage((estado.currentPage + 1) % n)
    }
    val descripcion = stringResource(R.string.av_titulo)
    Column(Modifier.semantics { contentDescription = descripcion }) {
        HorizontalPager(state = estado, pageSpacing = 10.dp, modifier = Modifier.fillMaxWidth()) { i ->
            val a = avisos[i]
            Surface(
                onClick = { onIrA(a.ruta) }, shape = RoundedCornerShape(16.dp),
                color = if (a.pronto) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest, modifier = Modifier.size(42.dp)) {
                        Box(contentAlignment = Alignment.Center) { Icon(a.icono, null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary) }
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(a.titulo, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(a.texto, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        if (n > 1) Row(Modifier.fillMaxWidth().padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainer) {
                Text(stringResource(R.string.av_de, estado.currentPage + 1, n), style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 3.dp).semantics { liveRegion = LiveRegionMode.Polite })
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { pausa = !pausa }) {
                Icon(if (pausa) Icons.Filled.PlayArrow else Icons.Filled.Pause, stringResource(if (pausa) R.string.av_reanudar else R.string.av_pausar))
            }
            IconButton(onClick = { alcance.launch { estado.animateScrollToPage((estado.currentPage - 1 + n) % n) } }) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.av_anterior))
            }
            IconButton(onClick = { alcance.launch { estado.animateScrollToPage((estado.currentPage + 1) % n) } }) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.av_siguiente))
            }
        }
    }
}
