package com.rutaalacima.app.ui.comunidad

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.VideocamOff
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.rutaalacima.app.R
import com.rutaalacima.app.RutaApp
import com.rutaalacima.app.data.social.ConexionFogata
import com.rutaalacima.app.data.social.Fogata
import com.rutaalacima.app.ui.components.Luces
import com.rutaalacima.app.ui.components.Luz
import com.rutaalacima.app.ui.components.MontanaArte
import io.livekit.android.LiveKit
import io.livekit.android.events.RoomEvent
import io.livekit.android.events.collect
import io.livekit.android.renderer.TextureViewRenderer
import io.livekit.android.room.Room
import io.livekit.android.room.track.CameraPosition
import io.livekit.android.room.track.LocalVideoTrack
import io.livekit.android.room.track.Track
import io.livekit.android.room.track.VideoTrack
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

private val NOCHE = Color(0xFF07090E)
private val BRASA = listOf(Color(0xFFF6C46A), Color(0xFFE2763A), Color(0xFF9E2B1A), Color(0xFFF6C46A))
private val ORO_VIVO = Color(0xFFF6C46A)
private val APAGAR = Color(0xFF8E2F1D)

/* ---------------------------------------------------------------- La franja «En vivo ahora» */

/** Solo aparece si alguien está transmitiendo. [sobreNoche]: en Cimas (fondo oscuro) o en el muro (papel). */
@Composable
fun FranjaFogatas(lista: List<Fogata>, onAbrir: (Fogata) -> Unit, modifier: Modifier = Modifier, sobreNoche: Boolean = true) {
    if (lista.isEmpty()) return
    LazyRow(modifier, contentPadding = PaddingValues(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(lista, key = { it.id }) { f ->
            val vivo = stringResource(R.string.fg_vivo)
            Surface(
                onClick = { onAbrir(f) }, shape = RoundedCornerShape(50),
                color = if (sobreNoche) Color(0xFF0E121A).copy(alpha = 0.62f) else MaterialTheme.colorScheme.surface,
                contentColor = if (sobreNoche) Color.White else MaterialTheme.colorScheme.onSurface,
                border = if (sobreNoche) null else androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                modifier = Modifier.widthIn(max = 260.dp).heightIn(min = 48.dp).semantics { contentDescription = "$vivo: ${f.autor}, ${f.titulo}" },
            ) {
                Row(Modifier.padding(start = 5.dp, end = 14.dp, top = 5.dp, bottom = 5.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.size(40.dp).clip(CircleShape).background(Brush.sweepGradient(BRASA)).padding(2.dp)) { Avatar(f.autor, f.avatar, tamano = 36) }
                    Column(Modifier.weight(1f, fill = false)) {
                        EtiquetaVivo(if (sobreNoche) ORO_VIVO else MaterialTheme.colorScheme.primary)
                        Text(f.autor.substringBefore(' '), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, maxLines = 1)
                        Text(f.titulo, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.alpha(0.8f))
                    }
                }
            }
        }
    }
}

@Composable
private fun EtiquetaVivo(color: Color, fondo: Color = Color.Transparent) {
    val t = rememberInfiniteTransition(label = "vivo")
    val a by t.animateFloat(1f, 0.35f, infiniteRepeatable(tween(800), RepeatMode.Reverse), label = "pulso")
    Row(Modifier.clip(RoundedCornerShape(50)).background(fondo).padding(horizontal = if (fondo == Color.Transparent) 0.dp else 9.dp, vertical = if (fondo == Color.Transparent) 0.dp else 5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(7.dp).alpha(a).clip(CircleShape).background(color))
        Text(stringResource(R.string.fg_vivo).uppercase(), color = color, fontSize = 10.5.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.6.sp)
    }
}

/* ---------------------------------------------------------------- La entrada en Publicar */

@Composable
fun EntradaFogata(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(onClick = onClick, shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = modifier.fillMaxWidth()) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(Color(0xFF171B24)), contentAlignment = Alignment.Center) { Luz("fogata", Modifier.size(40.dp), animada = true) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(stringResource(R.string.fg_entrada_t), style = MaterialTheme.typography.titleMedium)
                Text(stringResource(R.string.fg_entrada_d), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/* ---------------------------------------------------------------- La sesión completa */

private sealed interface Fase {
    data object Encender : Fase
    data class Entrando(val f: Fogata) : Fase
    data class Vivo(val c: ConexionFogata) : Fase
    data class Llevo(val f: Fogata, val apagada: Boolean) : Fase
    data class Resumen(val f: Fogata, val minutos: Int, val luces: Int) : Fase
}

/** Encender una fogata ([ver] = null) o entrar a mirar una ([ver]); al terminar llama a [onCerrar]. */
@Composable
fun FogataSesion(ver: Fogata?, onCerrar: () -> Unit) {
    var fase by remember { mutableStateOf<Fase>(if (ver == null) Fase.Encender else Fase.Entrando(ver)) }
    val ctx = LocalContext.current
    val repo = remember { (ctx.applicationContext as RutaApp).container.fogatas }
    when (val x = fase) {
        Fase.Encender -> PantallaCompleta(onCerrar) { EncenderFogata(onCerrar, onEncendida = { fase = Fase.Vivo(it) }) }
        is Fase.Entrando -> PantallaCompleta(onCerrar) {
            var error by remember { mutableStateOf<String?>(null) }
            LaunchedEffect(x.f.id) {
                runCatching { repo.entrar(x.f) }.onSuccess { fase = Fase.Vivo(it) }.onFailure { error = it.message ?: ctx.getString(R.string.fg_error) }
            }
            Box(Modifier.fillMaxSize().background(NOCHE)) {
                MontanaArte("fogata-${x.f.id}", Modifier.fillMaxSize(), paleta = 3, bandera = false)
                Text(error ?: stringResource(R.string.fg_esperando), color = Color.White, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center,
                    modifier = Modifier.align(Alignment.Center).padding(24.dp))
                IconButton(onClick = onCerrar, Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(8.dp)) { Icon(Icons.Filled.Close, stringResource(R.string.fg_salir), tint = Color.White) }
            }
        }
        is Fase.Vivo -> PantallaCompleta(onCerrar = {}) {
            FogataVivo(x.c, onFin = { apagada, minutos, luces ->
                fase = if (x.c.anfitrion) Fase.Resumen(x.c.fogata, minutos, luces) else Fase.Llevo(x.c.fogata, apagada)
            })
        }
        is Fase.Llevo -> DialogoLlevo(x.f, x.apagada, onCerrar)
        is Fase.Resumen -> DialogoResumen(x.f, x.minutos, x.luces, onCerrar)
    }
}

@Composable
private fun PantallaCompleta(onCerrar: () -> Unit, contenido: @Composable () -> Unit) {
    Dialog(onDismissRequest = onCerrar, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false, dismissOnClickOutside = false)) {
        Box(Modifier.fillMaxSize().background(NOCHE)) { contenido() }
    }
}

/* ---------------------------------------------------------------- Encender */

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EncenderFogata(onCerrar: () -> Unit, onEncendida: (ConexionFogata) -> Unit) {
    val ctx = LocalContext.current
    val cont = remember { (ctx.applicationContext as RutaApp).container }
    val repo = cont.fogatas
    val perfil by cont.perfil.perfil.collectAsState(com.rutaalacima.app.data.local.PerfilEntity())
    val scope = rememberCoroutineScope()
    var titulo by remember { mutableStateOf("") }
    var eje by remember { mutableStateOf<String?>(null) }
    var puede by remember { mutableStateOf<Boolean?>(null) }
    var encendiendo by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { puede = repo.puedeEncender() }

    fun encender() {
        encendiendo = true; error = null
        scope.launch {
            runCatching { repo.encender(titulo.trim(), eje, perfil.nombre.ifBlank { "Senderista" }, perfil.fotoPerfilUrl) }
                .onSuccess(onEncendida).onFailure { error = it.message ?: ctx.getString(R.string.fg_error); encendiendo = false }
        }
    }
    val permisos = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { r ->
        if (r.values.all { it }) encender() else error = ctx.getString(R.string.fg_permiso)
    }
    fun pedirYEncender() {
        val faltan = listOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO).filter { ContextCompat.checkSelfPermission(ctx, it) != PackageManager.PERMISSION_GRANTED }
        if (faltan.isEmpty()) encender() else permisos.launch(faltan.toTypedArray())
    }

    Box(Modifier.fillMaxSize()) {
        MontanaArte("fogata-previa", Modifier.fillMaxSize(), paleta = 3, bandera = false)
        IconButton(onClick = onCerrar, Modifier.align(Alignment.TopStart).statusBarsPadding().padding(8.dp)) { Icon(Icons.Filled.Close, stringResource(R.string.cancelar), tint = Color.White) }
        Surface(Modifier.align(Alignment.BottomCenter).widthIn(max = 560.dp).fillMaxWidth(), shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp), color = MaterialTheme.colorScheme.surface) {
            Column(Modifier.navigationBarsPadding().imePadding().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.fg_encender_t), style = MaterialTheme.typography.headlineSmall)
                Text(stringResource(R.string.fg_encender_d), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedTextField(titulo, { titulo = it.take(90) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.fg_tema)) },
                    placeholder = { Text(stringResource(R.string.fg_tema_ej)) }, singleLine = true)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    FilterChip(eje == null, { eje = null }, { Text(stringResource(R.string.fg_sin_eje)) })
                    listOf("VOL", "MAE", "VOZ", "VAL", "EVO", "TRA").forEach { k ->
                        FilterChip(eje == k, { eje = k }, { Text(com.rutaalacima.app.ui.vision.nombreCodigo(k)) })
                    }
                }
                if (puede == false) Text(stringResource(R.string.fg_no_puede), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                error?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
                Button(onClick = ::pedirYEncender, enabled = puede == true && titulo.trim().length >= 3 && !encendiendo, modifier = Modifier.align(Alignment.End).heightIn(min = 48.dp)) {
                    Luz("fogata", Modifier.size(22.dp)); Spacer(Modifier.width(8.dp))
                    Text(stringResource(if (encendiendo) R.string.fg_encendiendo else R.string.fg_encender))
                }
            }
        }
    }
}

/* ---------------------------------------------------------------- En vivo */

private data class LuzSube(val id: Long, val k: String, val quien: String, val x: Float, val giro: Float)

@Composable
private fun FogataVivo(c: ConexionFogata, onFin: (apagada: Boolean, minutos: Int, luces: Int) -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext
    val repo = remember { (app as RutaApp).container.fogatas }
    val scope = rememberCoroutineScope()
    val room = remember { LiveKit.create(app) }
    val f = c.fogata
    val inicio = remember { System.currentTimeMillis() }
    var video by remember { mutableStateOf<VideoTrack?>(null) }
    var personas by remember { mutableIntStateOf(1) }
    var luces by remember { mutableIntStateOf(0) }
    val suben = remember { mutableStateListOf<LuzSube>() }
    var mic by remember { mutableStateOf(true) }
    var cam by remember { mutableStateOf(true) }
    var frente by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var preguntarApagar by remember { mutableStateOf(false) }
    var reportando by remember { mutableStateOf(false) }
    var cortando by remember { mutableStateOf(false) }
    var moderador by remember { mutableStateOf(false) }
    var terminado by remember { mutableStateOf(false) }

    fun minutos() = ((System.currentTimeMillis() - inicio) / 60000).toInt().coerceAtLeast(1)
    fun terminar(apagada: Boolean) { if (terminado) return; terminado = true; onFin(apagada, minutos(), luces) }
    fun subir(k: String, quien: String) {
        luces++
        suben += LuzSube(System.nanoTime(), k, quien, (Math.random() * 46 - 23).toFloat(), (Math.random() * 16 - 8).toFloat())
        if (suben.size > 24) suben.removeAt(0)
    }

    LaunchedEffect(room) {
        launch {
            room.events.collect { e ->
                when (e) {
                    is RoomEvent.TrackSubscribed -> (e.track as? VideoTrack)?.let { video = it }
                    is RoomEvent.TrackUnsubscribed -> if (e.track == video) video = null
                    is RoomEvent.DataReceived -> runCatching {
                        val o = JSONObject(String(e.data, Charsets.UTF_8))
                        if (o.optString("t") == "luz") subir(o.optString("k", "sol"), e.participant?.name.orEmpty().substringBefore(' '))
                    }
                    is RoomEvent.ParticipantConnected, is RoomEvent.ParticipantDisconnected -> personas = room.remoteParticipants.size + 1
                    is RoomEvent.Disconnected -> terminar(true)
                    else -> Unit
                }
            }
        }
        runCatching { room.connect(c.url, c.token) }.onFailure { error = ctx.getString(R.string.fg_error); return@LaunchedEffect }
        personas = room.remoteParticipants.size + 1
        moderador = !c.anfitrion && repo.soyModerador()
        if (c.anfitrion) {
            runCatching {
                room.localParticipant.setCameraEnabled(true)
                room.localParticipant.setMicrophoneEnabled(true)
                video = room.localParticipant.getTrackPublication(Track.Source.CAMERA)?.track as? VideoTrack
            }
            while (isActive) { delay(60_000); repo.latido(f.id, personas) }
        }
    }
    DisposableEffect(room) { onDispose { runCatching { room.disconnect() }; runCatching { room.release() } } }

    fun darLuz(k: String) {
        subir(k, "")
        Luces.recordar(ctx, k)
        scope.launch { runCatching { room.localParticipant.publishData(JSONObject().put("t", "luz").put("k", k).toString().toByteArray()) } }
    }

    Box(Modifier.fillMaxSize().background(NOCHE)) {
        MontanaArte("fogata-${f.id}", Modifier.fillMaxSize(), paleta = 3, bandera = false)
        video?.let { VideoLK(room, it, espejo = c.anfitrion && frente, Modifier.fillMaxSize().alpha(if (c.anfitrion && !cam) 0f else 1f)) }
        if (video == null) Text(error ?: stringResource(R.string.fg_esperando), color = Color.White, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center,
            modifier = Modifier.align(Alignment.Center).padding(24.dp))
        // Sombra arriba y abajo para leer encima del video
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color.Black.copy(alpha = 0.5f), 0.22f to Color.Transparent, 0.62f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.62f))))
        // Las luces suben por la pantalla
        Box(Modifier.align(Alignment.BottomEnd).padding(end = 18.dp, bottom = 150.dp).width(90.dp).fillMaxHeight(0.6f)) {
            suben.forEach { s -> key(s.id) { LuzQueSube(s) { suben.remove(s) } } }
        }

        Row(Modifier.fillMaxWidth().statusBarsPadding().padding(start = 16.dp, end = 8.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(40.dp).clip(CircleShape).border(2.dp, ORO_VIVO, CircleShape)) { Avatar(f.autor, f.avatar, tamano = 40) }
            Column(Modifier.weight(1f)) {
                Text(f.autor, color = Color.White, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                Text(f.titulo + (f.eje?.let { " · " + com.rutaalacima.app.ui.vision.nombreCodigo(it) } ?: ""), color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            EtiquetaVivo(ORO_VIVO, Color.Black.copy(alpha = 0.4f))
            Row(Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.4f)).padding(horizontal = 10.dp, vertical = 5.dp)
                .semantics { contentDescription = ctx.getString(R.string.fg_personas) + ": $personas" },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Icon(Icons.Filled.Visibility, null, tint = Color.White, modifier = Modifier.size(16.dp))
                Text("$personas", color = Color.White, style = MaterialTheme.typography.labelMedium)
            }
            IconCirculo(Icons.Filled.Close, stringResource(if (c.anfitrion) R.string.fg_apagar else R.string.fg_salir)) {
                if (c.anfitrion) preguntarApagar = true else { runCatching { room.disconnect() }; terminar(false) }
            }
        }

        Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding().padding(start = 12.dp, end = 12.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally)) {
                Luces.IDS.forEach { k ->
                    val nombre = Luces.nombre(ctx, k)
                    Column(Modifier.width(56.dp).clip(RoundedCornerShape(16.dp)).clickable(onClickLabel = nombre) { darLuz(k) }.padding(vertical = 6.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Luz(k, Modifier.size(34.dp))
                        Text(nombre, color = Color.White.copy(alpha = 0.88f), fontSize = 9.5.sp, lineHeight = 11.sp, textAlign = TextAlign.Center, maxLines = 2)
                    }
                }
            }
            Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally)) {
                if (c.anfitrion) {
                    IconCirculo(if (mic) Icons.Filled.Mic else Icons.Filled.MicOff, stringResource(R.string.fg_mic), activo = !mic) {
                        mic = !mic; scope.launch { runCatching { room.localParticipant.setMicrophoneEnabled(mic) } }
                    }
                    IconCirculo(if (cam) Icons.Filled.Videocam else Icons.Filled.VideocamOff, stringResource(R.string.fg_cam), activo = !cam) {
                        cam = !cam; scope.launch { runCatching { room.localParticipant.setCameraEnabled(cam) } }
                    }
                    IconCirculo(Icons.Filled.Cameraswitch, stringResource(R.string.fg_girar)) {
                        frente = !frente
                        runCatching { (room.localParticipant.getTrackPublication(Track.Source.CAMERA)?.track as? LocalVideoTrack)?.switchCamera(position = if (frente) CameraPosition.FRONT else CameraPosition.BACK) }
                    }
                    Button(onClick = { preguntarApagar = true }, colors = ButtonDefaults.buttonColors(containerColor = APAGAR, contentColor = Color.White), modifier = Modifier.heightIn(min = 48.dp)) {
                        Text(stringResource(R.string.fg_apagar))
                    }
                } else {
                    Text(if (luces > 0) stringResource(R.string.lz_total, luces) else "", color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                    IconCirculo(Icons.Filled.Flag, stringResource(R.string.fg_reportar)) { reportando = true }
                    if (moderador) Button(onClick = { cortando = true }, colors = ButtonDefaults.buttonColors(containerColor = APAGAR, contentColor = Color.White), modifier = Modifier.heightIn(min = 48.dp)) {
                        Text(stringResource(R.string.fg_cortar))
                    }
                }
            }
        }
    }

    if (preguntarApagar) AlertDialog(
        onDismissRequest = { preguntarApagar = false },
        title = { Text(stringResource(R.string.fg_apagar_t)) }, text = { Text(stringResource(R.string.fg_apagar_d)) },
        confirmButton = { TextButton(onClick = { preguntarApagar = false; scope.launch { runCatching { repo.apagar(f.id) }; runCatching { room.disconnect() }; terminar(false) } }) { Text(stringResource(R.string.fg_apagar_si)) } },
        dismissButton = { TextButton(onClick = { preguntarApagar = false }) { Text(stringResource(R.string.fg_seguir)) } },
    )
    if (cortando) AlertDialog(
        onDismissRequest = { cortando = false },
        title = { Text(stringResource(R.string.fg_cortar)) }, text = { Text(stringResource(R.string.fg_cortar_d)) },
        confirmButton = { TextButton(onClick = { cortando = false; scope.launch { runCatching { repo.apagar(f.id) }; runCatching { room.disconnect() }; terminar(true) } }) { Text(stringResource(R.string.fg_cortar)) } },
        dismissButton = { TextButton(onClick = { cortando = false }) { Text(stringResource(R.string.cancelar)) } },
    )
    if (reportando) {
        var texto by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { reportando = false },
            title = { Text(stringResource(R.string.fg_reportar)) },
            text = { OutlinedTextField(texto, { texto = it.take(600) }, Modifier.fillMaxWidth(), placeholder = { Text(stringResource(R.string.fg_reportar_ph)) }, minLines = 3) },
            confirmButton = { TextButton(enabled = texto.isNotBlank(), onClick = {
                reportando = false
                scope.launch { runCatching { repo.reportar(f, texto.trim()) }; com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.fg_reporte_ok)) }
            }) { Text(stringResource(R.string.enviar)) } },
            dismissButton = { TextButton(onClick = { reportando = false }) { Text(stringResource(R.string.cancelar)) } },
        )
    }
}

@Composable
private fun IconCirculo(icono: androidx.compose.ui.graphics.vector.ImageVector, descripcion: String, activo: Boolean = false, onClick: () -> Unit) {
    Box(Modifier.size(48.dp).clip(CircleShape).background(if (activo) Color.White.copy(alpha = 0.9f) else Color.Black.copy(alpha = 0.32f))
        .clickable(onClickLabel = descripcion, onClick = onClick).semantics { contentDescription = descripcion }, contentAlignment = Alignment.Center) {
        Icon(icono, null, tint = if (activo) Color(0xFF1A1A1A) else Color.White)
    }
}

@Composable
private fun LuzQueSube(s: LuzSube, alTerminar: () -> Unit) {
    val p = remember { Animatable(0f) }
    val ctxL = LocalContext.current
    val alto = with(LocalDensity.current) { 260.dp.toPx() }
    val desplazar = with(LocalDensity.current) { s.x.dp.toPx() }
    val reducir = remember { android.provider.Settings.Global.getFloat(ctxL.contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f) }
    LaunchedEffect(s.id) { p.animateTo(1f, tween(3100, easing = FastOutSlowInEasing)); alTerminar() }
    Column(
        Modifier.fillMaxSize().wrapContentSize(Alignment.BottomCenter).graphicsLayer {
            val v = p.value
            alpha = when { v < 0.12f -> v / 0.12f; else -> 1f - (v - 0.12f) / 0.88f }
            if (reducir != 0f) { translationY = -alto * v; translationX = desplazar * v; rotationZ = s.giro * v; scaleX = 0.6f + 0.4f * minOf(1f, v * 8); scaleY = scaleX }
        },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Luz(s.k, Modifier.size(40.dp))
        if (s.quien.isNotBlank()) Text(s.quien, color = Color.White, fontSize = 10.sp)
    }
}

/** El video de LiveKit dentro de Compose. */
@Composable
private fun VideoLK(room: Room, track: VideoTrack, espejo: Boolean, modifier: Modifier) {
    var vista by remember { mutableStateOf<TextureViewRenderer?>(null) }
    AndroidView(
        factory = { c -> TextureViewRenderer(c).also { room.initVideoRenderer(it); it.setScalingType(livekit.org.webrtc.RendererCommon.ScalingType.SCALE_ASPECT_FILL); vista = it } },
        update = { it.setMirror(espejo) },
        modifier = modifier,
        onRelease = { runCatching { it.release() } },
    )
    DisposableEffect(track, vista) {
        val v = vista
        if (v != null) track.addRenderer(v)
        onDispose { if (v != null) runCatching { track.removeRenderer(v) } }
    }
}

/* ---------------------------------------------------------------- Al salir */

@Composable
private fun DialogoLlevo(f: Fogata, apagada: Boolean, onCerrar: () -> Unit) {
    val ctx = LocalContext.current
    val repo = remember { (ctx.applicationContext as RutaApp).container.fogatas }
    val scope = rememberCoroutineScope()
    var texto by remember { mutableStateOf("") }
    val nombre = f.autor.substringBefore(' ')
    AlertDialog(
        onDismissRequest = onCerrar,
        title = { Text(stringResource(if (apagada) R.string.fg_apagada else R.string.fg_llevo_t)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.fg_llevo_d, nombre))
                OutlinedTextField(texto, { texto = it.take(280) }, Modifier.fillMaxWidth(), placeholder = { Text(stringResource(R.string.fg_llevo_ph)) }, minLines = 2)
                Text(stringResource(R.string.fg_llevo_nota, nombre), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        confirmButton = { TextButton(enabled = texto.isNotBlank(), onClick = {
            scope.launch {
                runCatching { repo.llevo(f.id, texto.trim()) }
                    .onSuccess { com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.fg_llevo_ok)) }
                    .onFailure { com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.fg_error)) }
                onCerrar()
            }
        }) { Text(stringResource(R.string.fg_llevo_btn)) } },
        dismissButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.fg_ahora_no)) } },
    )
}

@Composable
private fun DialogoResumen(f: Fogata, minutos: Int, luces: Int, onCerrar: () -> Unit) {
    val ctx = LocalContext.current
    val repo = remember { (ctx.applicationContext as RutaApp).container.fogatas }
    var llevaron by remember { mutableStateOf<List<Pair<String, String>>?>(null) }
    LaunchedEffect(f.id) { delay(1500); llevaron = repo.llevaron(f.id) }
    AlertDialog(
        onDismissRequest = onCerrar,
        title = { Text(stringResource(R.string.fg_resumen_t)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.fg_resumen_d, minutos, luces))
                Text(stringResource(R.string.fg_llevaron), style = MaterialTheme.typography.titleSmall)
                val l = llevaron
                when {
                    l == null -> LinearProgressIndicator(Modifier.fillMaxWidth())
                    l.isEmpty() -> Text(stringResource(R.string.fg_llevaron_vacio), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    else -> l.forEach { (quien, t) -> Text("$quien: $t", style = MaterialTheme.typography.bodyMedium) }
                }
            }
        },
        confirmButton = { TextButton(onClick = onCerrar) { Text(stringResource(R.string.listo)) } },
    )
}
