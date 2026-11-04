package com.rutaalacima.app.ui.coach

import com.rutaalacima.app.ui.theme.fondoPapel
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.remember
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.material.icons.filled.Hiking
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.outlined.DeleteSweep
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.rutaalacima.app.AppContainer
import com.rutaalacima.app.R
import com.rutaalacima.app.data.local.CoachMensajeEntity
import com.rutaalacima.app.ui.components.rutaViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class CoachViewModel(private val c: AppContainer) : ViewModel() {
    val mensajes: StateFlow<List<CoachMensajeEntity>> = c.coach.conversacion.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    var texto by mutableStateOf("")
    var pensando by mutableStateOf(false)
        private set
    val conIA: Boolean get() = c.coach.conIA
    /** Llegó al límite diario del plan gratuito: se ofrece conocer el Plan Cumbre. */
    val limite = c.coach.limiteAlcanzado
    /** Los controles: de qué se habla (propósito, metas o finanzas) y por qué la IA no respondió. */
    val tema = c.coach.tema
    val aviso = c.coach.aviso
    fun elegirTema(t: String) = c.coach.elegirTema(t)
    val reportados = c.coach.idsReportados
    fun reportar(id: Long, motivo: String, detalle: String, listo: (Boolean) -> Unit) = viewModelScope.launch { listo(c.coach.reportar(id, motivo, detalle)) }

    fun enviar(t: String = texto) {
        if (t.isBlank() || pensando) return
        texto = ""
        pensando = true
        viewModelScope.launch {
            runCatching { c.coach.enviar(t) }
            pensando = false
        }
    }

    fun borrar() = viewModelScope.launch { c.coach.borrar() }

    // ---------- Metas que propone el coach y se crean con un toque
    private val prefs = c.contexto.getSharedPreferences("coach_acciones", android.content.Context.MODE_PRIVATE)
    var creadas by mutableStateOf(prefs.getStringSet("creadas", emptySet()).orEmpty())
        private set

    fun crear(mensajeId: Long, a: com.rutaalacima.app.domain.model.AccionCoach) {
        if (mensajeId.toString() in creadas) return
        creadas = creadas + mensajeId.toString()
        prefs.edit().putStringSet("creadas", creadas).apply()
        val hoy = java.time.LocalDate.now()
        c.appScope.launch {
            when (a.tipo) {
                com.rutaalacima.app.domain.model.AccionCoach.Tipo.META_MES -> c.planAnual.guardarMetaMes(
                    com.rutaalacima.app.data.local.MetaMensualEntity(anio = hoy.year, mes = hoy.monthValue, orden = 99, texto = a.texto, eje = a.eje,
                        objetivoDias = a.dias.coerceAtMost(hoy.lengthOfMonth())))
                com.rutaalacima.app.domain.model.AccionCoach.Tipo.META_ANIO -> c.planificador.guardarMeta(
                    com.rutaalacima.app.data.local.MetaAnualEntity(anio = hoy.year, titulo = a.texto, eje = a.eje))
            }
        }
    }
}

/** Coach de IA: orienta a la persona con el método Ruta a la Cima y su información real. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CoachScreen(onBack: () -> Unit, onCoachVida: () -> Unit = {}, onPlan: () -> Unit = {}) {
    val vm = rutaViewModel { CoachViewModel(it) }
    val mensajes by vm.mensajes.collectAsStateWithLifecycle()
    val lista = rememberLazyListState()
    LaunchedEffect(mensajes.size, vm.pensando) { if (mensajes.isNotEmpty()) lista.animateScrollToItem(mensajes.size) }
    val tema by vm.tema.collectAsStateWithLifecycle()
    val reportados by vm.reportados.collectAsStateWithLifecycle()
    var reportando by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf<Long?>(null) }
    val ctx = androidx.compose.ui.platform.LocalContext.current
    reportando?.let { id ->
        DialogoReporteCoach(onCerrar = { reportando = null }) { motivo, detalle ->
            vm.reportar(id, motivo, detalle) { ok ->
                com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(if (ok) R.string.coach_rep_gracias else R.string.coach_rep_error))
            }
            reportando = null
        }
    }
    val aviso by vm.aviso.collectAsStateWithLifecycle()
    val sugerencias = when (tema) {
        "proposito" -> listOf(R.string.coach_sug_cumbre, R.string.coach_sug_proposito5, R.string.coach_sug_eje)
        "metas" -> listOf(R.string.coach_sug_dividir, R.string.coach_sug_semana, R.string.coach_sug_motivacion, R.string.coach_sug_atascada, R.string.coach_sug_habito)
        "finanzas" -> listOf(R.string.coach_sug_mochilas, R.string.coach_sug_deudas, R.string.coach_sug_emergencia, R.string.coach_sug_revisar_fin)
        else -> listOf(R.string.coach_sug_cumbre, R.string.coach_sug_dividir, R.string.coach_sug_motivacion,
            R.string.coach_sug_semana, R.string.coach_sug_eje, R.string.coach_sug_habito)
    }.map { stringResource(it) }
    val temas = listOf("" to R.string.coach_tema_general, "proposito" to R.string.coach_tema_proposito,
        "metas" to R.string.coach_tema_metas, "finanzas" to R.string.coach_tema_finanzas)

    Scaffold(
        modifier = Modifier.fondoPapel(),
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        topBar = {
            TopAppBar(
                colors = androidx.compose.material3.TopAppBarDefaults.topAppBarColors(containerColor = androidx.compose.ui.graphics.Color.Transparent),
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(com.rutaalacima.app.ui.components.IconosRuta.Coach, null, tint = MaterialTheme.colorScheme.secondary)
                        Spacer(Modifier.size(8.dp))
                        Column {
                            Text(stringResource(R.string.coach))
                            Text(
                                stringResource(if (vm.conIA) R.string.coach_con_ia else R.string.coach_sin_ia),
                                style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.volver)) } },
                actions = { IconButton(onClick = { vm.borrar() }) { Icon(Icons.Outlined.DeleteSweep, stringResource(R.string.borrar_conversacion)) } },
            )
        },
        bottomBar = {
            Surface(tonalElevation = 3.dp) {
                Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding()) {
                    val enLimite by vm.limite.collectAsStateWithLifecycle()
                    if (enLimite) androidx.compose.material3.TextButton(onClick = onPlan, modifier = Modifier.padding(horizontal = 8.dp)) {
                        Icon(Icons.Filled.Terrain, null, Modifier.size(18.dp))
                        Spacer(Modifier.size(6.dp))
                        Text(stringResource(R.string.coach_limite_plan))
                    }
                    Text(
                        stringResource(if (tema == "finanzas") R.string.coach_limites_finanzas else R.string.coach_limites_general),
                        style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                    LazyRow(contentPadding = PaddingValues(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(sugerencias) { s -> AssistChip(onClick = { vm.enviar(s) }, label = { Text(s, maxLines = 1) }) }
                    }
                    Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            vm.texto, { vm.texto = it }, placeholder = { Text(stringResource(R.string.escribe_al_coach)) },
                            modifier = Modifier.weight(1f), maxLines = 5, shape = RoundedCornerShape(24.dp),
                        )
                        IconButton(onClick = { vm.enviar() }, enabled = vm.texto.isNotBlank() && !vm.pensando) {
                            Icon(Icons.AutoMirrored.Filled.Send, stringResource(R.string.enviar), tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        },
    ) { padding ->
        LazyColumn(
            state = lista,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = padding.calculateTopPadding() + 8.dp, bottom = padding.calculateBottomPadding() + 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item {
                // Los controles: el tema decide qué aconseja el coach (y si ve las finanzas)
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 4.dp)) {
                    items(temas) { (k, n) ->
                        androidx.compose.material3.FilterChip(selected = tema == k, onClick = { vm.elegirTema(k) }, label = { Text(stringResource(n)) })
                    }
                }
            }
            item { Burbuja(stringResource(R.string.coach_bienvenida), deCoach = true) }
            if (mensajes.isEmpty()) item {
                androidx.compose.material3.TextButton(onClick = onCoachVida) {
                    Icon(Icons.Filled.Hiking, null, Modifier.size(18.dp))
                    Spacer(Modifier.size(6.dp))
                    Text(stringResource(R.string.coach_ia_persona))
                }
            }
            items(mensajes, key = { it.id }) { m ->
                if (m.rol == "assistant") {
                    val (texto, accion) = remember(m.texto) { com.rutaalacima.app.domain.model.AccionCoach.separar(m.texto) }
                    Burbuja(texto, deCoach = true)
                    val ya = m.id.toString() in reportados
                    androidx.compose.material3.IconButton(onClick = { if (!ya) reportando = m.id }, enabled = !ya, modifier = Modifier.padding(start = 2.dp).size(40.dp)) {
                        Icon(Icons.Outlined.Flag, stringResource(if (ya) R.string.coach_rep_hecho else R.string.coach_rep_titulo), Modifier.size(18.dp),
                            tint = if (ya) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
                    }
                    if (accion != null) AccionPropuesta(accion, creada = m.id.toString() in vm.creadas, onCrear = { vm.crear(m.id, accion) })
                } else Burbuja(m.texto, deCoach = false)
            }
            aviso?.let { a -> item {
                Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.Top) {
                    Icon(Icons.Outlined.Info, null, Modifier.size(18.dp).padding(top = 2.dp), tint = MaterialTheme.colorScheme.secondary)
                    Spacer(Modifier.size(8.dp))
                    Text(a, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } }
            if (vm.pensando) item { Box(Modifier.padding(8.dp)) { CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp) } }
        }
    }
}

@Composable
private fun Burbuja(texto: String, deCoach: Boolean) {
    Box(Modifier.fillMaxWidth(), contentAlignment = if (deCoach) Alignment.CenterStart else Alignment.CenterEnd) {
        Text(
            texto,
            style = MaterialTheme.typography.bodyLarge,
            color = if (deCoach) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier
                .widthIn(max = 320.dp)
                .background(
                    if (deCoach) MaterialTheme.colorScheme.surfaceContainerHigh else MaterialTheme.colorScheme.primary,
                    RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp, bottomStart = if (deCoach) 4.dp else 18.dp, bottomEnd = if (deCoach) 18.dp else 4.dp),
                )
                .padding(horizontal = 14.dp, vertical = 10.dp),
        )
    }
}


/** Botón bajo la respuesta del coach para crear la meta que propuso. */
@Composable
private fun AccionPropuesta(a: com.rutaalacima.app.domain.model.AccionCoach, creada: Boolean, onCrear: () -> Unit) {
    val etiqueta = stringResource(
        if (a.tipo == com.rutaalacima.app.domain.model.AccionCoach.Tipo.META_MES) R.string.coach_crear_meta_mes else R.string.coach_crear_meta_anio,
    )
    androidx.compose.material3.OutlinedCard(
        modifier = Modifier.padding(start = 8.dp, top = 2.dp).widthIn(max = 320.dp),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(etiqueta.uppercase(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
            Text(a.texto, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(vertical = 4.dp))
            if (creada) Text("✓ " + stringResource(R.string.coach_meta_creada), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            else androidx.compose.material3.FilledTonalButton(onClick = onCrear) { Text(stringResource(R.string.coach_crear)) }
        }
    }
}


/** Reportar una respuesta del coach: motivo y un detalle opcional. La revisa moderación. */
@Composable
private fun DialogoReporteCoach(onCerrar: () -> Unit, onEnviar: (String, String) -> Unit) {
    val motivos = listOf("ofensiva" to R.string.coach_rep_ofensiva, "peligrosa" to R.string.coach_rep_peligrosa,
        "equivocada" to R.string.coach_rep_equivocada, "otra" to R.string.coach_rep_otra)
    var motivo by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf("ofensiva") }
    var detalle by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf("") }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onCerrar,
        icon = { Icon(Icons.Outlined.Flag, null) },
        title = { Text(stringResource(R.string.coach_rep_titulo)) },
        text = {
            Column(Modifier.selectableGroup()) {
                Text(stringResource(R.string.coach_rep_explica), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.size(8.dp))
                motivos.forEach { (k, r) ->
                    Row(Modifier.fillMaxWidth().selectable(selected = motivo == k, onClick = { motivo = k }, role = androidx.compose.ui.semantics.Role.RadioButton).padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                        androidx.compose.material3.RadioButton(motivo == k, null)
                        Spacer(Modifier.size(8.dp))
                        Text(stringResource(r))
                    }
                }
                OutlinedTextField(detalle, { detalle = it.take(1000) }, label = { Text(stringResource(R.string.coach_rep_detalle)) },
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp), maxLines = 4)
            }
        },
        confirmButton = { androidx.compose.material3.TextButton(onClick = { onEnviar(motivo, detalle.trim()) }) { Text(stringResource(R.string.coach_rep_enviar)) } },
        dismissButton = { androidx.compose.material3.TextButton(onClick = onCerrar) { Text(stringResource(R.string.cancelar)) } },
    )
}

