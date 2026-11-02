package com.rutaalacima.app.ui.comunidad

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rutaalacima.app.AppContainer
import com.rutaalacima.app.R
import com.rutaalacima.app.RutaApp
import com.rutaalacima.app.data.social.ExpedicionEventos
import com.rutaalacima.app.data.social.PasoCompartido
import com.rutaalacima.app.data.social.Post
import com.rutaalacima.app.domain.model.Eje
import com.rutaalacima.app.domain.model.Mandala
import com.rutaalacima.app.domain.model.MetodoCima
import com.rutaalacima.app.ui.theme.asColor
import com.rutaalacima.app.ui.vision.nombreCodigo
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/*
 * Comunidad como cuaderno de expedición (igual que la web, web/js/53-expedicion.js). El diseño de Cimas no cambia;
 * se suman: la pausa de cumbre cada 7 cimas, «Me lo llevo» (mochila o paso de la Brújula), la tarjeta de paso con la
 * mini-Brújula 9×9 y el aviso al ganar un paso (o un campamento, o la cumbre) para compartirlo.
 */

private val ORO = Color(0xFFD9B068)
private val PASO_FOCO = Color(0xFFF6C46A)

/** Color de cada campamento fijo de la Brújula (los 6 ejes, Confluencia y Campamento Base). */
fun colorCampamento(i: Int): Color = when (val cod = Mandala.CAMPAMENTOS_FIJOS.getOrNull(i)) {
    "CON" -> Color(0xFF7A4A6B); "CAM" -> Color(0xFF4A5E7A)
    else -> Eje.fromCodigo(cod)?.color?.asColor() ?: Color(0xFF7A4A6B)
}

/** Qué se enciende en la mini-Brújula: un paso, un campamento entero o la cumbre. */
sealed interface FocoBrujula {
    data class Paso(val i: Int, val p: Int) : FocoBrujula
    data class Campamento(val i: Int) : FocoBrujula
    data object Cumbre : FocoBrujula
}

fun focoDe(pa: PasoCompartido): FocoBrujula = when (pa.hito) {
    "CUMBRE" -> FocoBrujula.Cumbre
    "CAMPAMENTO" -> FocoBrujula.Campamento(pa.i)
    else -> FocoBrujula.Paso(pa.i, pa.p)
}

/** El mapa de 64 pasos de una publicación; las viejas (sin mapa) reciben uno estable a partir de sus pasos ganados. */
fun mapaDe(p: Post): String {
    val c = p.camino ?: return ""
    if (c.mapa.length == 64) return c.mapa
    if (c.ganados <= 0) return ""
    var h = 0L; for (ch in p.id) h = (h * 31 + ch.code) and 0xFFFFFFFFL
    val orden = (0 until 64).sortedBy { ((it * 2654435761L + h) and 0xFFFFFFFFL) % 997 }
    val m = CharArray(64) { '0' }; orden.take(minOf(64, c.ganados)).forEach { m[it] = '1' }
    return String(m)
}

/** La Brújula 9×9 en miniatura: la cumbre al centro, los 8 campamentos y sus 64 pasos (los ganados con su color). */
@Composable
fun MiniBrujula(mapa: String, foco: FocoBrujula?, modifier: Modifier = Modifier, vacio: Color = Color.White) {
    val m = mapa.padEnd(64, '0')
    Canvas(modifier) {
        val u = size.minDimension / 68f
        for (f in 0 until 9) for (c in 0 until 9) {
            val cel = Mandala.celda(f, c)
            val x = (c * 7 + (c / 3) * 2) * u; val y = (f * 7 + (f / 3) * 2) * u
            var color = vacio; var alfa = 0.16f; var brilla = false
            when (cel.tipo) {
                Mandala.Tipo.CUMBRE -> { color = ORO; alfa = 1f }
                Mandala.Tipo.CAMPAMENTO -> { color = colorCampamento(cel.campamento); alfa = 1f }
                else -> {
                    val hecho = m[cel.campamento * 8 + cel.paso] == '1'
                    if (hecho) { color = colorCampamento(cel.campamento); alfa = 0.92f }
                    when (foco) {
                        is FocoBrujula.Paso -> if (foco.i == cel.campamento && foco.p == cel.paso) { color = PASO_FOCO; alfa = 1f; brilla = true }
                        is FocoBrujula.Campamento -> if (foco.i == cel.campamento && hecho) alfa = 1f
                        else -> Unit
                    }
                }
            }
            drawRoundRect(color.copy(alpha = alfa), Offset(x, y), Size(6 * u, 6 * u), CornerRadius(1.2f * u))
            if (brilla) drawRoundRect(PASO_FOCO.copy(alpha = 0.6f), Offset(x - u, y - u), Size(8 * u, 8 * u), CornerRadius(2f * u), style = Stroke(u * 0.8f))
        }
    }
}

/** La tarjeta de paso en Cimas: el cielo del momento, la mini-Brújula con la casilla encendida, el título y el texto. */
@Composable
fun TarjetaPaso(post: Post, modifier: Modifier = Modifier) {
    val pa = post.camino?.paso ?: return
    val nombre = nombreCodigo(pa.cod.ifBlank { Mandala.CAMPAMENTOS_FIJOS.getOrElse(pa.i) { "CON" } })
    val titulo = when (pa.hito) {
        "CUMBRE" -> stringResource(R.string.ex_tarjeta_cumbre)
        "CAMPAMENTO" -> stringResource(R.string.ex_hito_camp_t, nombre)
        else -> stringResource(R.string.ex_tarjeta_paso, pa.n, nombre)
    }
    val sombra = Shadow(Color.Black.copy(alpha = 0.5f), blurRadius = 10f)
    com.rutaalacima.app.ui.components.CieloVivo(modifier, horizonte = 0.72f, lectura = false, instante = post.creadoEn) {
        Column(Modifier.fillMaxSize().padding(start = 32.dp, end = 76.dp, top = 110.dp, bottom = 200.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically)) {
            MiniBrujula(mapaDe(post), focoDe(pa), Modifier.size(150.dp).clip(RoundedCornerShape(18.dp)).background(Color(0x8C060A12))
                .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(18.dp)).padding(10.dp))
            Text(titulo, color = if (pa.hito == null) Color(0xFFF6D99A) else Color.White, textAlign = TextAlign.Center,
                style = if (pa.hito == null) MaterialTheme.typography.titleSmall.copy(shadow = sombra)
                else MaterialTheme.typography.headlineSmall.copy(fontFamily = FontFamily.Serif, shadow = sombra))
            if (post.texto.isNotBlank()) Text(post.texto, color = Color.White, textAlign = TextAlign.Center, maxLines = 3, overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.titleMedium.copy(fontFamily = FontFamily.Serif, fontWeight = FontWeight.Normal, shadow = sombra))
        }
    }
}

/* ---------------------------------------------------------------- 1A. Pausa de cumbre */

private data class Sugerido(val i: Int, val texto: String, val jornadas: Int, val req: Int, val hoy: Boolean)

/** Tu paso más cerca de ganarse: escrito, sin ganar y con más jornadas. */
private suspend fun pasoSugerido(c: AppContainer): Sugerido? = runCatching {
    val r = c.respuestas.cargar(Mandala.WORKBOOK)
    val generales = c.db.visionDao().todas().filter { Mandala.anioDeOrigen(it.origen) == null }
    val camps = Mandala.repartir(generales, { it.origen }, { it.eje }).second
    var mejor: Sugerido? = null
    val hoy = java.time.LocalDate.now()
    camps.forEachIndexed { i, cas -> cas ?: return@forEachIndexed
        for (p in 0 until Mandala.PASOS) {
            val t = r[Mandala.clave(cas.id, p)].orEmpty().trim(); if (t.isEmpty()) continue
            val x = MetodoCima.leer(cas.id, p, r); if (x.cumplido) continue
            if (mejor == null || x.jornadas.size > mejor!!.jornadas)
                mejor = Sugerido(i, t, x.jornadas.size, x.requeridas ?: MetodoCima.DIFICULTAD_INICIAL, hoy in x.jornadas)
        }
    }
    mejor
}.getOrNull()

/** La pausa: cada 7 cimas, el feed se detiene en tu propio paso de hoy. */
@Composable
fun PausaCumbre(onBrujula: () -> Unit, onSeguir: () -> Unit, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    var s by remember { mutableStateOf<Sugerido?>(null) }
    var listo by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { s = pasoSugerido((ctx.applicationContext as RutaApp).container); listo = true }
    Box(modifier.fillMaxSize().background(Color(0xB3060A12)).clickable(enabled = false) {}, contentAlignment = Alignment.Center) {
        Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surface, shadowElevation = 12.dp, modifier = Modifier.padding(20.dp).widthIn(max = 420.dp)) {
            Column(Modifier.padding(horizontal = 22.dp, vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(painterResource(R.drawable.logo_suroute), null, Modifier.size(40.dp), tint = MaterialTheme.colorScheme.primary)
                val x = s
                Text(stringResource(if (x?.hoy == true) R.string.ex_pausa_hecho_t else R.string.ex_pausa_t), style = MaterialTheme.typography.headlineSmall.copy(fontFamily = FontFamily.Serif), textAlign = TextAlign.Center)
                if (!listo) LinearProgressIndicator(Modifier.width(120.dp))
                else if (x == null) {
                    Text(stringResource(R.string.ex_pausa_vacio), textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyMedium)
                    Button(onClick = onBrujula, modifier = Modifier.heightIn(min = 48.dp)) { Text(stringResource(R.string.ex_abrir_brujula)) }
                } else {
                    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(colorCampamento(x.i)))
                            val nombre = nombreCodigo(Mandala.CAMPAMENTOS_FIJOS[x.i])
                            Text(if (x.hoy) stringResource(R.string.ex_jornadas, nombre, x.jornadas, x.req) else stringResource(R.string.ex_pausa_hoy, nombre),
                                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text(x.texto, style = MaterialTheme.typography.titleMedium.copy(fontFamily = FontFamily.Serif))
                    }
                    if (x.hoy) Text(stringResource(R.string.ex_pausa_hecho_d), textAlign = TextAlign.Center, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    else Button(onClick = onBrujula, modifier = Modifier.heightIn(min = 48.dp)) { Text(stringResource(R.string.ex_darlo)) }
                }
                TextButton(onClick = onSeguir) {
                    Icon(Icons.Filled.KeyboardArrowUp, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text(stringResource(R.string.ex_seguir))
                }
            }
        }
    }
}

/* ---------------------------------------------------------------- 1B. Me lo llevo */

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun HojaLlevo(post: Post, guardado: Boolean, onGuardar: () -> Unit, onBrujula: () -> Unit, onCerrar: () -> Unit) {
    val ctx = LocalContext.current
    val c = remember { (ctx.applicationContext as RutaApp).container }
    val scope = rememberCoroutineScope()
    // Campamentos con una casilla libre: (posición, id de la casilla, primer paso vacío)
    var libres by remember { mutableStateOf<List<Triple<Int, Long, Int>>?>(null) }
    var elegido by remember { mutableStateOf<Int?>(null) }
    var texto by remember { mutableStateOf(post.texto.take(140)) }
    LaunchedEffect(post.id) {
        libres = runCatching {
            val r = c.respuestas.cargar(Mandala.WORKBOOK)
            val generales = c.db.visionDao().todas().filter { Mandala.anioDeOrigen(it.origen) == null }
            Mandala.repartir(generales, { it.origen }, { it.eje }).second.mapIndexedNotNull { i, cas ->
                cas ?: return@mapIndexedNotNull null
                val p = (0 until Mandala.PASOS).firstOrNull { r[Mandala.clave(cas.id, it)].isNullOrBlank() } ?: return@mapIndexedNotNull null
                Triple(i, cas.id, p)
            }
        }.getOrDefault(emptyList())
        elegido = libres?.firstOrNull { Mandala.CAMPAMENTOS_FIJOS[it.first] == post.eje }?.first ?: libres?.firstOrNull()?.first
    }
    val nombresCamp = Mandala.CAMPAMENTOS_FIJOS.map { nombreCodigo(it) }
    ModalBottomSheet(onDismissRequest = onCerrar) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp).navigationBarsPadding().imePadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.ex_llevo_t), style = MaterialTheme.typography.titleLarge)
            Text(stringResource(R.string.ex_llevo_d, post.autorNombre.substringBefore(' ')), color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedCard(onClick = { onGuardar(); onCerrar() }, modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Icon(com.rutaalacima.app.ui.components.IconosRuta.Morral, null, tint = MaterialTheme.colorScheme.primary)
                    Column {
                        Text(stringResource(if (guardado) R.string.ex_mochila_no else R.string.ex_mochila_si), style = MaterialTheme.typography.titleSmall)
                        Text(stringResource(R.string.ex_mochila_d), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.padding(top = 4.dp)) {
                Icon(Icons.Filled.Explore, null, tint = MaterialTheme.colorScheme.primary)
                Column {
                    Text(stringResource(R.string.ex_paso_t), style = MaterialTheme.typography.titleSmall)
                    Text(stringResource(R.string.ex_paso_d), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            val l = libres
            when {
                l == null -> LinearProgressIndicator(Modifier.fillMaxWidth())
                l.isEmpty() -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.ex_sin_libres), Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                    TextButton(onClick = { onCerrar(); onBrujula() }) { Text(stringResource(R.string.ex_abrir_brujula)) }
                }
                else -> {
                    OutlinedTextField(texto, { texto = it.take(140) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.ex_mi_paso)) }, minLines = 2)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        l.forEach { (i, _, _) ->
                            FilterChip(elegido == i, { elegido = i }, { Text(nombresCamp[i]) },
                                leadingIcon = { Box(Modifier.size(8.dp).clip(CircleShape).background(colorCampamento(i))) })
                        }
                    }
                    Button(enabled = texto.isNotBlank() && elegido != null, modifier = Modifier.align(Alignment.End).heightIn(min = 48.dp), onClick = {
                        val (i, id, p) = l.first { it.first == elegido }
                        scope.launch {
                            c.respuestas.guardar(Mandala.WORKBOOK, Mandala.clave(id, p), texto.trim())
                            com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.ex_paso_nuevo, nombresCamp[i], p + 1))
                            onCerrar()
                        }
                    }) { Text(stringResource(R.string.ex_agregar)) }
                }
            }
        }
    }
}

/* ---------------------------------------------------------------- 2. Al ganar un paso */

/** Escucha los pasos que se ganan en cualquier pantalla: ofrece compartirlos y celebra los hitos (campamento y cumbre). */
@Composable
fun AvisosPasoGanado(onCompartir: (texto: String) -> Unit) {
    val ctx = LocalContext.current
    val c = remember { (ctx.applicationContext as RutaApp).container }
    var hito by remember { mutableStateOf<Pair<PasoCompartido, String>?>(null) }
    val nombres = Mandala.CAMPAMENTOS_FIJOS.map { nombreCodigo(it) }
    LaunchedEffect(Unit) {
        ExpedicionEventos.ganados.collect { (id, p) ->
            delay(400)   // que el guardado termine
            val r = c.respuestas.cargar(Mandala.WORKBOOK)
            val generales = c.db.visionDao().todas().filter { Mandala.anioDeOrigen(it.origen) == null }
            val camps = Mandala.repartir(generales, { it.origen }, { it.eje }).second
            val i = camps.indexOfFirst { it?.id == id }; if (i < 0) return@collect
            val pasos = MetodoCima.pasosDe(camps.map { it?.id }, r)
            val enCamp = pasos.subList(i * 8, i * 8 + 8).count { it.cumplido }; val total = pasos.count { it.cumplido }
            val h = if (total == 64) "CUMBRE" else if (enCamp == 8) "CAMPAMENTO" else null
            val info = PasoCompartido(i, Mandala.CAMPAMENTOS_FIJOS[i], p, enCamp, h)
            val mapa = pasos.joinToString("") { if (it.cumplido) "1" else "0" }
            val nombre = nombres[i]
            val texto = when (h) {
                "CUMBRE" -> ctx.getString(R.string.ex_texto_cumbre)
                "CAMPAMENTO" -> ctx.getString(R.string.ex_texto_camp, nombre)
                else -> ctx.getString(R.string.ex_texto_paso, nombre, r[Mandala.clave(id, p)].orEmpty().trim())
            }
            if (h == null) {
                delay(1600)
                com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.ex_ganado), ctx.getString(R.string.ex_compartir)) {
                    ExpedicionEventos.pendiente = info; onCompartir(texto)
                }
            } else hito = info to mapa
        }
    }
    hito?.let { (info, mapa) ->
        val nombre = nombres[info.i]
        AlertDialog(
            onDismissRequest = { hito = null },
            icon = { MiniBrujula(mapa, focoDe(info), Modifier.size(140.dp).clip(RoundedCornerShape(18.dp)).background(Color(0xFF0E1422)).padding(10.dp)) },
            title = { Text(if (info.hito == "CUMBRE") stringResource(R.string.ex_hito_cumbre_t) else stringResource(R.string.ex_hito_camp_t, nombre), textAlign = TextAlign.Center) },
            text = { Text(if (info.hito == "CUMBRE") stringResource(R.string.ex_hito_cumbre_d) else stringResource(R.string.ex_hito_camp_d, nombre), textAlign = TextAlign.Center) },
            confirmButton = { TextButton(onClick = {
                hito = null; ExpedicionEventos.pendiente = info
                onCompartir(if (info.hito == "CUMBRE") ctx.getString(R.string.ex_texto_cumbre) else ctx.getString(R.string.ex_texto_camp, nombre))
            }) { Text(stringResource(R.string.ex_compartir_comunidad)) } },
            dismissButton = { TextButton(onClick = { hito = null }) { Text(stringResource(R.string.fg_ahora_no)) } },
        )
    }
}

/** En Publicar: la vista previa del paso que viaja con la publicación, con la opción de quitarlo. */
@Composable
fun PreviaPaso(pa: PasoCompartido, mapa: String, onQuitar: () -> Unit) {
    val nombre = nombreCodigo(pa.cod)
    Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            MiniBrujula(mapa, focoDe(pa), Modifier.size(84.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFF0E1422)).padding(6.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(when (pa.hito) { "CUMBRE" -> stringResource(R.string.ex_tarjeta_cumbre); "CAMPAMENTO" -> stringResource(R.string.ex_hito_camp_t, nombre)
                    else -> stringResource(R.string.ex_tarjeta_paso, pa.n, nombre) }, style = MaterialTheme.typography.titleSmall)
                Text(stringResource(R.string.ex_previa_d), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedButton(onClick = onQuitar) { Text(stringResource(R.string.ex_sin_brujula)) }
            }
        }
    }
}
