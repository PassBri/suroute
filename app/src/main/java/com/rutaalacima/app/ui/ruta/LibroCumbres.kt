package com.rutaalacima.app.ui.ruta

import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil.compose.AsyncImage
import com.rutaalacima.app.AppContainer
import com.rutaalacima.app.R
import com.rutaalacima.app.data.social.Compromiso
import com.rutaalacima.app.data.social.ExpedicionEventos
import com.rutaalacima.app.data.social.Post
import com.rutaalacima.app.domain.model.Mandala
import com.rutaalacima.app.domain.model.MetodoCima
import com.rutaalacima.app.ui.alto.Alto
import com.rutaalacima.app.ui.comunidad.colorCampamento
import com.rutaalacima.app.ui.components.rutaViewModel
import com.rutaalacima.app.ui.vision.nombreCodigo
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

/*
 * Libro de cumbres (igual que la web, web/js/54-libro.js): el registro de la vida que no se pierde.
 * Las páginas de cumbre (campamentos completos, la cumbre, metas cumplidas y compromisos logrados) se firman con lo
 * que costó y una foto del diario; la cápsula del mes se sella al terminar el mes y se abre rompiendo el lacre; el
 * libro del año lo reúne todo, con la carta al año siguiente y la descarga en PDF. Todo vive en el libro "libro" de
 * respuestas (viaja con la web) y se puede publicar en Comunidad (posts.camino.libro).
 */
object Libro {
    const val WB = "libro"
    fun claveFirma(clave: String) = "libro#firma#$clave"
    fun claveCapsula(ym: YearMonth) = "libro#capsula#$ym"
    fun claveFrase(ym: YearMonth) = "libro#frase#$ym"
    fun claveCarta(anio: Int) = "libro#carta#$anio"
}

data class Firma(val fecha: String, val texto: String, val foto: String)
enum class TipoHito { CAMPAMENTO, CUMBRE, META, COMPROMISO }
data class Hito(val clave: String, val tipo: TipoHito, val titulo: String, val cod: String?, val i: Int, val fecha: String?, val firma: Firma?)
data class DatosMes(
    val ym: YearMonth, val dias: Int, val fotos: List<String>, val constancia: Int,
    val pasos: List<Triple<Int, String, String>>, val alto: List<Triple<String, String, String>>,
    val firmas: List<Hito>, val frase: String, val llevo: List<Pair<String, String>>,
) { val vacio get() = fotos.isEmpty() && constancia == 0 && pasos.isEmpty() && alto.isEmpty() && firmas.isEmpty() }

private fun firmaDe(v: String?): Firma? = v?.takeIf { it.isNotBlank() }?.let { s ->
    runCatching { JSONObject(s).let { Firma(it.optString("fecha"), it.optString("texto"), it.optString("foto")) } }.getOrNull()
}
private fun ymDe(p: Post): YearMonth = Instant.ofEpochMilli(p.creadoEn).atZone(ZoneId.systemDefault()).toLocalDate().let { YearMonth.of(p.anio.takeIf { a -> a > 1900 } ?: it.year, it.monthValue) }
private fun fotoValida(u: String) = u.isNotBlank() && !u.startsWith("blob:")

class LibroViewModel(private val c: AppContainer) : ViewModel() {
    val libro: StateFlow<Map<String, String>> = c.respuestas.observar(Libro.WB).stateIn(viewModelScope, SharingStarted.Eagerly, emptyMap())
    val posts: StateFlow<List<Post>> = c.social.misPublicaciones.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())
    private val mandala = c.respuestas.observar(Mandala.WORKBOOK)
    private val generales = c.db.visionDao().observe()
    var hitos by mutableStateOf<List<Hito>>(emptyList())
        private set
    private var pasosCache: List<MetodoCima.Paso> = emptyList()
    private var campsCache: List<Long?> = emptyList()
    private var mandalaCache: Map<String, String> = emptyMap()

    init {
        viewModelScope.launch {
            combine(libro, posts, mandala, generales, c.planificador.todasLasMetas) { lb, ps, r, cs, metas ->
                val camps = Mandala.repartir(cs.filter { Mandala.anioDeOrigen(it.origen) == null }, { it.origen }, { it.eje }).second
                val ids = camps.map { it?.id }
                val pasos = MetodoCima.pasosDe(ids, r)
                pasosCache = pasos; campsCache = ids; mandalaCache = r
                val h = mutableListOf<Hito>()
                camps.forEachIndexed { i, cas ->
                    cas ?: return@forEachIndexed
                    val ps8 = pasos.subList(i * 8, i * 8 + 8)
                    if (ps8.all { it.cumplido }) h += Hito("camp:${cas.id}", TipoHito.CAMPAMENTO, "", Mandala.CAMPAMENTOS_FIJOS[i], i, ps8.mapNotNull { it.cumplidoEn?.toString() }.maxOrNull(), null)
                }
                if (pasos.size == 64 && pasos.all { it.cumplido }) h += Hito("cumbre", TipoHito.CUMBRE, "", null, -1, pasos.mapNotNull { it.cumplidoEn?.toString() }.maxOrNull(), null)
                metas.filter { it.estado == "CUMPLIDA" || it.avance >= 100 }.forEach { m ->
                    h += Hito("meta:${m.id}", TipoHito.META, m.titulo, m.eje, Mandala.CAMPAMENTOS_FIJOS.indexOf(m.eje ?: "CON"), "${m.anio}-12-31", null)
                }
                ps.filter { it.compromiso?.estado == Compromiso.LOGRADO }.forEach { p ->
                    h += Hito("comp:${p.id}", TipoHito.COMPROMISO, p.texto.take(90), p.eje, Mandala.CAMPAMENTOS_FIJOS.indexOf(p.eje ?: "CON"), p.compromiso?.hasta, null)
                }
                h.map { x -> val f = firmaDe(lb[Libro.claveFirma(x.clave)]); x.copy(firma = f, fecha = f?.fecha?.ifBlank { null } ?: x.fecha) }
                    .sortedWith(compareByDescending<Hito> { it.firma != null }.thenByDescending { it.fecha.orEmpty() })
            }.collect { hitos = it }
        }
    }

    fun guardar(clave: String, valor: String) = viewModelScope.launch { c.respuestas.guardar(Libro.WB, clave, valor) }
    fun firmar(h: Hito, texto: String, foto: String) = guardar(Libro.claveFirma(h.clave),
        JSONObject().put("fecha", h.firma?.fecha?.ifBlank { null } ?: h.fecha ?: LocalDate.now().toString()).put("texto", texto).put("foto", foto).toString())

    fun capsulaAbierta(ym: YearMonth) = !libro.value[Libro.claveCapsula(ym)].isNullOrBlank()

    /** Lo que fue un mes: fotos, constancia, pasos ganados, el Alto en el camino, firmas, la frase y las fogatas. */
    suspend fun datosMes(ctx: android.content.Context, ym: YearMonth, conFogatas: Boolean = true): DatosMes {
        val dias = ym.lengthOfMonth()
        val fotos = posts.value.filter { ymDe(it) == ym }.flatMap { p -> listOf(p.foto) + p.media.filter { it.tipo == "img" }.map { it.url } }.filter(::fotoValida).distinct()
        val marcados = runCatching { c.checklist.desde(ym.atDay(1)).first() }.getOrDefault(emptyMap())
        val constancia = (1..dias).count { d -> !marcados[ym.atDay(d)].isNullOrEmpty() }
        val pasos = mutableListOf<Triple<Int, String, String>>()
        campsCache.forEachIndexed { i, id -> if (id != null) for (p in 0 until 8) {
            val x = pasosCache.getOrNull(i * 8 + p) ?: continue
            if (x.cumplido && x.cumplidoEn?.let { YearMonth.from(it) } == ym) pasos += Triple(i, mandalaCache[Mandala.clave(id, p)].orEmpty().trim(), x.cumplidoEn.toString())
        } }
        val alto = runCatching {
            val b = Alto.banco(ctx); val r = c.respuestas.cargar(Alto.WB)
            Alto.delMes(b, ym).mapIndexedNotNull { i, q -> r[Alto.clave(ym, i)]?.trim()?.takeIf { it.isNotEmpty() }?.let { Triple(q.nombre, q.texto, it) } }
        }.getOrDefault(emptyList())
        val firmas = hitos.filter { it.firma != null && it.fecha.orEmpty().startsWith(ym.toString()) }
        val llevo = if (conFogatas) c.fogatas.misLlevos(ym) else emptyList()
        return DatosMes(ym, dias, fotos, constancia, pasos, alto, firmas, libro.value[Libro.claveFrase(ym)].orEmpty(), llevo)
    }

    fun haceUnAnio(): Post? {
        val h = LocalDate.now()
        return posts.value.filter { val d = Instant.ofEpochMilli(it.creadoEn).atZone(ZoneId.systemDefault()).toLocalDate(); d.year < h.year && d.monthValue == h.monthValue && d.dayOfMonth == h.dayOfMonth }
            .sortedByDescending { fotoValida(it.foto) }.firstOrNull()
    }
    fun anios(): List<Int> = (posts.value.map { ymDe(it).year } + hitos.mapNotNull { it.fecha?.take(4)?.toIntOrNull() } + LocalDate.now().year).filter { it > 1900 }.distinct().sortedDescending()
}

/* ---------------------------------------------------------------- Textos y colores */

private val PAPEL = Color(0xFFFBF6EC)
private val TINTA = Color(0xFF2B1D17)
private val TINTA_SUAVE = Color(0xFF6E625A)
private val ORO = Color(0xFFC9A45C)

@Composable
private fun nombreMesLargo(ym: YearMonth): String = ym.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault()).replaceFirstChar { it.titlecase(Locale.getDefault()) } + " ${ym.year}"
private fun fechaLarga(f: String?): String = runCatching { LocalDate.parse(f!!.take(10)).format(java.time.format.DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.LONG)) }.getOrDefault("")

@Composable
fun tituloHito(h: Hito): String = when (h.tipo) {
    TipoHito.CAMPAMENTO -> stringResource(R.string.lb_campamento_x, nombreCodigo(h.cod ?: "CON"))
    TipoHito.CUMBRE -> stringResource(R.string.lb_mi_cumbre)
    else -> h.titulo
}
@Composable
fun subHito(h: Hito): String = when (h.tipo) {
    TipoHito.CAMPAMENTO -> stringResource(R.string.lb_sub_camp)
    TipoHito.CUMBRE -> stringResource(R.string.lb_sub_cumbre)
    TipoHito.META -> stringResource(R.string.lb_sub_meta, h.fecha?.take(4).orEmpty())
    TipoHito.COMPROMISO -> stringResource(R.string.lb_sub_comp)
}
@Composable
private fun tipoHito(t: TipoHito): String = stringResource(when (t) {
    TipoHito.CAMPAMENTO -> R.string.lb_t_camp; TipoHito.CUMBRE -> R.string.lb_t_cumbre; TipoHito.META -> R.string.lb_t_meta; TipoHito.COMPROMISO -> R.string.lb_t_comp
})
private fun colorHito(i: Int) = if (i >= 0) colorCampamento(i) else ORO

@Composable
private fun Lacre(tamano: Int, modifier: Modifier = Modifier) =
    Image(painterResource(R.drawable.logo_sello), null, modifier.size(tamano.dp))

/* ---------------------------------------------------------------- Pantalla principal */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibroCumbresScreen(onBack: () -> Unit, onCapsula: (String) -> Unit, onAnio: (Int) -> Unit, onPost: (String) -> Unit, onPublicar: (String) -> Unit) {
    val vm = rutaViewModel { LibroViewModel(it) }
    val libro by vm.libro.collectAsState()
    val posts by vm.posts.collectAsState()
    var anio by rememberSaveable { mutableIntStateOf(LocalDate.now().year) }
    var firmando by remember { mutableStateOf<Hito?>(null) }
    val hoyYm = YearMonth.now()
    Scaffold(
        topBar = { TopAppBar(title = { Column { Text(stringResource(R.string.lb_titulo)); Text(stringResource(R.string.lb_sub), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) } },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.volver)) } }) },
    ) { pad ->
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 8.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            vm.haceUnAnio()?.let { p -> item { HaceUnAnio(p) { onPost(p.id) } } }
            item {
                Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.lb_capsulas_de, anio), style = MaterialTheme.typography.titleMedium)
                        val anios = remember(posts, vm.hitos) { vm.anios() }
                        if (anios.size > 1) Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            anios.forEach { a -> FilterChip(a == anio, { anio = a }, { Text("$a") }) }
                        }
                        (1..12).chunked(4).forEach { fila ->
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                fila.forEach { m ->
                                    val ym = YearMonth.of(anio, m)
                                    CeldaMes(ym, hoyYm, !libro[Libro.claveCapsula(ym)].isNullOrBlank(), Modifier.weight(1f)) { onCapsula(ym.toString()) }
                                }
                            }
                        }
                        Button(onClick = { onAnio(anio) }, modifier = Modifier.heightIn(min = 48.dp)) {
                            Icon(Icons.Filled.MenuBook, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text(stringResource(R.string.lb_ver_libro, anio))
                        }
                    }
                }
            }
            item {
                val n = vm.hitos.count { it.firma == null }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                    Text(stringResource(R.string.lb_paginas), style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Serif))
                    if (n > 0) Badge { Text(stringResource(R.string.lb_por_firmar, n)) }
                }
            }
            if (vm.hitos.isEmpty()) item { Text(stringResource(R.string.lb_sin_paginas), color = MaterialTheme.colorScheme.onSurfaceVariant) }
            items(vm.hitos, key = { it.clave }) { h ->
                PaginaCumbre(h, onFirmar = { firmando = h }, onPublicar = {
                    ExpedicionEventos.libroPendiente = buildJsonObject {
                        put("t", "firma"); put("tipo", h.tipo.name); put("fecha", h.fecha.orEmpty()); put("foto", h.firma?.foto.orEmpty()); put("i", h.i)
                        put("titulo", h.titulo.take(90)); h.cod?.let { put("cod", it) }
                    }
                    onPublicar(h.firma?.texto.orEmpty())
                })
            }
        }
    }
    firmando?.let { h -> HojaFirmar(h, posts, onFirmar = { t, f -> vm.firmar(h, t, f); firmando = null }, onCerrar = { firmando = null }) }
}

@Composable
private fun CeldaMes(ym: YearMonth, hoyYm: YearMonth, abierta: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val futuro = ym > hoyYm; val cerrado = ym < hoyYm
    val estado = stringResource(when { futuro -> R.string.lb_por_vivir; !cerrado -> R.string.lb_llenandose; abierta -> R.string.lb_abierta; else -> R.string.lb_sellada })
    val nombre = ym.month.getDisplayName(TextStyle.SHORT_STANDALONE, Locale.getDefault()).replaceFirstChar { it.titlecase(Locale.getDefault()) }.removeSuffix(".")
    Column(
        modifier.aspectRatio(0.75f).clip(RoundedCornerShape(14.dp))
            .background(if (cerrado && !abierta) Color(0xFFF4ECDD) else MaterialTheme.colorScheme.surfaceVariant)
            .border(1.dp, if (!futuro && !cerrado) ORO else MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(14.dp))
            .alpha(if (futuro) 0.45f else 1f).clickable(enabled = !futuro, onClick = onClick).padding(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Bottom,
    ) {
        if (cerrado && !abierta) Lacre(34, Modifier.padding(bottom = 4.dp))
        Text(nombre, style = MaterialTheme.typography.titleSmall.copy(fontFamily = FontFamily.Serif), color = if (cerrado && !abierta) TINTA else MaterialTheme.colorScheme.onSurface)
        Text(estado, style = MaterialTheme.typography.labelSmall, fontSize = 10.sp, maxLines = 1, color = if (cerrado && !abierta) TINTA_SUAVE else MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun HaceUnAnio(p: Post, onClick: () -> Unit) {
    val n = LocalDate.now().year - Instant.ofEpochMilli(p.creadoEn).atZone(ZoneId.systemDefault()).year
    Surface(onClick = onClick, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (fotoValida(p.foto)) AsyncImage(if (p.foto.startsWith("http")) p.foto else File(p.foto), null, Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.Crop)
            else Box(Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment = Alignment.Center) { Icon(Icons.Filled.CalendarMonth, null, tint = MaterialTheme.colorScheme.primary) }
            Column(Modifier.weight(1f)) {
                Text(if (n <= 1) stringResource(R.string.lb_hace_uno) else stringResource(R.string.lb_hace_n, n), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(p.texto.ifBlank { stringResource(R.string.lb_un_recuerdo) }, style = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif), maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun PaginaCumbre(h: Hito, onFirmar: (() -> Unit)?, onPublicar: (() -> Unit)?) {
    val c = colorHito(h.i)
    Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.clip(RoundedCornerShape(50)).background(c.copy(alpha = 0.16f)).padding(horizontal = 10.dp, vertical = 3.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(c)); Text(tipoHito(h.tipo), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.weight(1f))
                if (h.firma != null) Lacre(38)
            }
            Text(tituloHito(h), style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Serif))
            Text(subHito(h) + (h.fecha?.let { " · " + fechaLarga(it) } ?: ""), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            h.firma?.foto?.takeIf(::fotoValida)?.let { f ->
                AsyncImage(if (f.startsWith("http")) f else File(f), stringResource(R.string.lb_foto_evidencia), Modifier.fillMaxWidth().heightIn(max = 300.dp).rotate(-0.6f)
                    .border(6.dp, Color.White, RoundedCornerShape(10.dp)).clip(RoundedCornerShape(10.dp)), contentScale = ContentScale.Crop)
            }
            h.firma?.texto?.takeIf { it.isNotBlank() }?.let { Text("“$it”", style = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic)) }
            if (onFirmar != null) Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 4.dp)) {
                if (h.firma == null) Button(onClick = onFirmar, modifier = Modifier.heightIn(min = 48.dp)) { Icon(Icons.Filled.Edit, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.lb_firmar_pagina)) }
                else {
                    OutlinedButton(onClick = onFirmar, modifier = Modifier.heightIn(min = 48.dp)) { Text(stringResource(R.string.lb_editar)) }
                    if (onPublicar != null) Button(onClick = onPublicar, modifier = Modifier.heightIn(min = 48.dp)) { Icon(Icons.Outlined.Share, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.lb_publicar)) }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HojaFirmar(h: Hito, posts: List<Post>, onFirmar: (String, String) -> Unit, onCerrar: () -> Unit) {
    var texto by remember { mutableStateOf(h.firma?.texto.orEmpty()) }
    var foto by remember { mutableStateOf(h.firma?.foto.orEmpty()) }
    val anio = h.fecha?.take(4)?.toIntOrNull() ?: LocalDate.now().year
    val fotos = remember(posts) { posts.filter { kotlin.math.abs(ymDe(it).year - anio) <= 1 }.map { it.foto }.filter(::fotoValida).distinct().take(18) }
    ModalBottomSheet(onDismissRequest = onCerrar) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp).navigationBarsPadding().imePadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.lb_firmar_t), style = MaterialTheme.typography.titleLarge)
            Text("${tituloHito(h)} · ${subHito(h)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(texto, { texto = it.take(600) }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.lb_que_costo)) },
                placeholder = { Text(stringResource(R.string.lb_que_costo_ph)) }, minLines = 3)
            if (fotos.isNotEmpty()) {
                Text(stringResource(R.string.lb_foto_diario), style = MaterialTheme.typography.labelLarge)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(foto.isBlank(), { foto = "" }, { Text(stringResource(R.string.lb_sin_foto)) }, modifier = Modifier.height(72.dp))
                    fotos.forEach { f ->
                        AsyncImage(if (f.startsWith("http")) f else File(f), null, Modifier.size(72.dp).clip(RoundedCornerShape(12.dp))
                            .border(if (foto == f) 3.dp else 0.dp, ORO, RoundedCornerShape(12.dp)).clickable { foto = f }, contentScale = ContentScale.Crop)
                    }
                }
            }
            Button(onClick = { onFirmar(texto.trim(), foto) }, enabled = texto.isNotBlank(), modifier = Modifier.align(Alignment.End).heightIn(min = 48.dp)) { Text(stringResource(R.string.lb_firmar)) }
        }
    }
}

/* ---------------------------------------------------------------- La cápsula del mes */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CapsulaScreen(ymTexto: String, onBack: () -> Unit, onPublicar: (String) -> Unit) {
    val ym = runCatching { YearMonth.parse(ymTexto) }.getOrDefault(YearMonth.now().minusMonths(1))
    val vm = rutaViewModel { LibroViewModel(it) }
    val ctx = LocalContext.current
    val libro by vm.libro.collectAsState()
    val posts by vm.posts.collectAsState()
    val abierta = !libro[Libro.claveCapsula(ym)].isNullOrBlank()
    val cerrado = ym < YearMonth.now()
    var datos by remember { mutableStateOf<DatosMes?>(null) }
    LaunchedEffect(ym, posts, vm.hitos) { datos = vm.datosMes(ctx, ym) }
    var rompiendo by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val nombre = nombreMesLargo(ym)
    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.lb_capsula_de, nombre), maxLines = 1, overflow = TextOverflow.Ellipsis) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.volver)) } },
            actions = { if (abierta) datos?.let { d -> IconButton(onClick = {
                ExpedicionEventos.libroPendiente = buildJsonObject {
                    put("t", "capsula"); put("ym", ym.toString()); put("fotos", JsonArray(d.fotos.filter { it.startsWith("http") }.take(4).map { JsonPrimitive(it) }))
                    put("dias", d.constancia); put("de", d.dias); put("pasos", d.pasos.size); put("recuerdos", d.fotos.size)
                }
                onPublicar(d.frase.ifBlank { ctx.getString(R.string.lb_texto_capsula, nombre) })
            }) { Icon(Icons.Outlined.Share, stringResource(R.string.lb_publicar)) } } }) },
    ) { pad ->
        Box(Modifier.fillMaxSize().padding(top = pad.calculateTopPadding())) {
            when {
                !cerrado -> Column(Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Lacre(72)
                    Text(stringResource(R.string.lb_llenando_t, nombre), style = MaterialTheme.typography.headlineSmall.copy(fontFamily = FontFamily.Serif), textAlign = TextAlign.Center)
                    Text(stringResource(R.string.lb_llenando_d, fechaLarga(ym.plusMonths(1).atDay(1).toString())), textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    datos?.let { Cifras(it) }
                }
                !abierta -> {
                    val escala by animateFloatAsState(if (rompiendo) 0.6f else 1f, tween(650), label = "lacre")
                    val alfa by animateFloatAsState(if (rompiendo) 0f else 1f, tween(650), label = "lacre-a")
                    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                        Surface(shape = RoundedCornerShape(18.dp), color = PAPEL, shadowElevation = 10.dp, modifier = Modifier.widthIn(max = 440.dp)) {
                            Column(Modifier.padding(horizontal = 26.dp, vertical = 34.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Lacre(96, Modifier.scale(escala).rotate(if (rompiendo) 18f else 0f).alpha(alfa))
                                Text(nombre, style = MaterialTheme.typography.headlineMedium.copy(fontFamily = FontFamily.Serif), color = TINTA)
                                Text(stringResource(R.string.lb_dentro), color = TINTA_SUAVE, textAlign = TextAlign.Center)
                                Button(onClick = {
                                    rompiendo = true
                                    scope.launch { delay(650); vm.guardar(Libro.claveCapsula(ym), LocalDate.now().toString()) }
                                }, modifier = Modifier.heightIn(min = 48.dp)) { Text(stringResource(R.string.lb_romper)) }
                            }
                        }
                    }
                }
                else -> datos?.let { d -> ContenidoMes(d, vm, editable = true) } ?: Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            }
        }
    }
}

@Composable
private fun Cifras(d: DatosMes, sobrePapel: Boolean = false) {
    @Composable fun Celda(n: Int, t: String, m: Modifier) = Column(m.clip(RoundedCornerShape(12.dp)).background(if (sobrePapel) Color.White.copy(alpha = 0.7f) else MaterialTheme.colorScheme.surfaceVariant).padding(vertical = 10.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text("$n", style = MaterialTheme.typography.headlineSmall.copy(fontFamily = FontFamily.Serif), color = if (sobrePapel) TINTA else MaterialTheme.colorScheme.onSurface)
        Text(t, style = MaterialTheme.typography.labelSmall, textAlign = TextAlign.Center, color = if (sobrePapel) TINTA_SUAVE else MaterialTheme.colorScheme.onSurfaceVariant)
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Celda(d.constancia, stringResource(R.string.lb_dias_constancia, d.dias), Modifier.weight(1f))
            Celda(d.pasos.size, stringResource(R.string.lb_pasos_ganados), Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Celda(d.fotos.size, stringResource(R.string.lb_recuerdos), Modifier.weight(1f))
            Celda(d.firmas.size, stringResource(R.string.lb_cumbres_firmadas), Modifier.weight(1f))
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ContenidoMes(d: DatosMes, vm: LibroViewModel, editable: Boolean) {
    var frase by remember(d.ym) { mutableStateOf(d.frase) }
    LaunchedEffect(frase) { if (editable && frase != d.frase) { delay(600); vm.guardar(Libro.claveFrase(d.ym), frase.trim()) } }
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        if (d.vacio) item { Text(stringResource(R.string.lb_mes_silencio), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        item { Cifras(d) }
        if (d.fotos.isNotEmpty()) item {
            Seccion(stringResource(R.string.lb_tus_recuerdos)) {
                d.fotos.take(9).chunked(3).forEach { fila ->
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 6.dp)) {
                        fila.forEach { f -> AsyncImage(if (f.startsWith("http")) f else File(f), null, Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(10.dp)), contentScale = ContentScale.Crop) }
                        repeat(3 - fila.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
        if (d.pasos.isNotEmpty()) item {
            Seccion(stringResource(R.string.lb_pasos_que)) {
                d.pasos.forEach { (i, t, f) ->
                    Row(Modifier.fillMaxWidth().padding(bottom = 8.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Box(Modifier.padding(top = 5.dp).size(10.dp).clip(CircleShape).background(colorCampamento(i)))
                        Column {
                            Text("${nombreCodigo(Mandala.CAMPAMENTOS_FIJOS[i])} · ${fechaLarga(f)}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(t.ifBlank { stringResource(R.string.lb_paso_ganado) })
                        }
                    }
                }
            }
        }
        if (d.firmas.isNotEmpty()) item { Seccion(stringResource(R.string.lb_cumbres_que)) { d.firmas.forEach { PaginaCumbre(it, null, null); Spacer(Modifier.height(8.dp)) } } }
        if (d.alto.isNotEmpty()) item {
            Seccion(stringResource(R.string.lb_tu_alto)) {
                d.alto.forEach { (n, q, r) -> Bloque(n, q, r) }
            }
        }
        if (d.llevo.isNotEmpty()) item { Seccion(stringResource(R.string.lb_fogatas)) { d.llevo.forEach { (t, r) -> Bloque(t.ifBlank { stringResource(R.string.lb_fogata) }, null, r) } } }
        item {
            Seccion(stringResource(R.string.lb_frase_mes)) {
                if (editable) OutlinedTextField(frase, { frase = it.take(280) }, Modifier.fillMaxWidth(), placeholder = { Text(stringResource(R.string.lb_frase_ph)) },
                    textStyle = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif), minLines = 2)
                else if (d.frase.isNotBlank()) Text("“${d.frase}”", style = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic))
            }
        }
    }
}

@Composable
private fun Seccion(titulo: String, contenido: @Composable ColumnScope.() -> Unit) = Column {
    Text(titulo, style = MaterialTheme.typography.titleMedium.copy(fontFamily = FontFamily.Serif), modifier = Modifier.padding(bottom = 8.dp))
    contenido()
}
@Composable
private fun Bloque(arriba: String, medio: String?, texto: String) = Column(
    Modifier.fillMaxWidth().padding(bottom = 8.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant).padding(10.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
    Text(arriba, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    medio?.let { Text(it, style = MaterialTheme.typography.labelLarge) }
    Text(texto, style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Serif))
}

/* ---------------------------------------------------------------- El libro del año */

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibroAnioScreen(anio: Int, onBack: () -> Unit, onPublicar: (String) -> Unit) {
    val vm = rutaViewModel { LibroViewModel(it) }
    val ctx = LocalContext.current
    val libro by vm.libro.collectAsState()
    val posts by vm.posts.collectAsState()
    var meses by remember { mutableStateOf<List<DatosMes>?>(null) }
    LaunchedEffect(anio, posts, vm.hitos) {
        val hoyYm = YearMonth.now()
        meses = (1..12).map { YearMonth.of(anio, it) }.filter { it <= hoyYm }.map { vm.datosMes(ctx, it, conFogatas = false) }
    }
    val firmas = vm.hitos.filter { it.firma != null && it.fecha.orEmpty().startsWith("$anio") }
    var carta by remember(libro) { mutableStateOf(libro[Libro.claveCarta(anio + 1)].orEmpty()) }
    LaunchedEffect(carta) { delay(600); if (carta != libro[Libro.claveCarta(anio + 1)].orEmpty()) vm.guardar(Libro.claveCarta(anio + 1), carta.trim()) }
    val nombrePersona = ctx.getString(R.string.lb_titulo)
    val tituloPdf = ctx.getString(R.string.lb_libro_de, anio)
    val textosPdf = rememberTextosPdf()
    val guardarPdf = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        val ms = meses ?: return@rememberLauncherForActivityResult
        if (uri != null) runCatching { ctx.contentResolver.openOutputStream(uri)?.use { escribirPdf(it, tituloPdf, ms, firmas, carta, textosPdf) } }
            .onSuccess { com.rutaalacima.app.ui.theme.AvisoGlobal.mostrar(ctx.getString(R.string.lb_pdf_ok)) }
    }
    Scaffold(
        topBar = { TopAppBar(title = { Text(tituloPdf) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.volver)) } },
            actions = {
                IconButton(onClick = { guardarPdf.launch("libro-de-cumbres-$anio.pdf") }, enabled = meses != null) { Icon(Icons.Filled.Download, stringResource(R.string.lb_pdf)) }
                IconButton(onClick = {
                    val ms = meses.orEmpty()
                    ExpedicionEventos.libroPendiente = buildJsonObject {
                        put("t", "anio"); put("anio", anio); put("fotos", JsonArray(ms.flatMap { it.fotos }.filter { it.startsWith("http") }.take(4).map { JsonPrimitive(it) }))
                        put("dias", ms.sumOf { it.constancia }); put("pasos", ms.sumOf { it.pasos.size }); put("cumbres", firmas.size)
                    }
                    onPublicar(ctx.getString(R.string.lb_texto_anio, anio))
                }) { Icon(Icons.Outlined.Share, stringResource(R.string.lb_publicar)) }
            }) },
    ) { pad ->
        val ms = meses
        if (ms == null) { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }; return@Scaffold }
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 8.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                Surface(shape = RoundedCornerShape(20.dp), color = PAPEL) {
                    Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Lacre(64)
                        Text("$anio", style = MaterialTheme.typography.displayMedium.copy(fontFamily = FontFamily.Serif), color = TINTA)
                        Text(nombrePersona, color = TINTA_SUAVE)
                        Cifras(DatosMes(YearMonth.of(anio, 1), ms.sumOf { it.dias }, ms.flatMap { it.fotos }, ms.sumOf { it.constancia }, ms.flatMap { it.pasos }, emptyList(), firmas, "", emptyList()), sobrePapel = true)
                    }
                }
            }
            if (firmas.isNotEmpty()) item { Seccion(stringResource(R.string.lb_cumbres_anio)) { firmas.forEach { PaginaCumbre(it, null, null); Spacer(Modifier.height(8.dp)) } } }
            ms.reversed().forEach { d ->
                item(key = d.ym.toString()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        HorizontalDivider()
                        Text(nombreMesLargo(d.ym), style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Serif))
                        if (d.vacio) Text(stringResource(R.string.lb_un_mes_silencio), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        else {
                            Cifras(d)
                            if (d.fotos.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                d.fotos.take(3).forEach { f -> AsyncImage(if (f.startsWith("http")) f else File(f), null, Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(10.dp)), contentScale = ContentScale.Crop) }
                                repeat(3 - d.fotos.take(3).size) { Spacer(Modifier.weight(1f)) }
                            }
                            d.pasos.forEach { (i, t, _) -> Text("• ${nombreCodigo(Mandala.CAMPAMENTOS_FIJOS[i])}: ${t.ifBlank { stringResource(R.string.lb_paso_ganado) }}", style = MaterialTheme.typography.bodyMedium) }
                            if (d.frase.isNotBlank()) Text("“${d.frase}”", style = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic))
                        }
                    }
                }
            }
            item {
                Seccion(stringResource(R.string.lb_carta_a, anio + 1)) {
                    OutlinedTextField(carta, { carta = it.take(3000) }, Modifier.fillMaxWidth(), placeholder = { Text(stringResource(R.string.lb_carta_ph, anio + 1)) },
                        textStyle = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif), minLines = 5)
                }
            }
        }
    }
}

/* ---------------------------------------------------------------- PDF */

private data class TextosPdf(val dias: String, val pasos: String, val recuerdos: String, val cumbres: String, val carta: String, val silencio: String, val meses: List<String>, val tipos: Map<TipoHito, String>, val campamento: String, val miCumbre: String)

@Composable
private fun rememberTextosPdf(): TextosPdf {
    val meses = (1..12).map { java.time.Month.of(it).getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault()).replaceFirstChar { c -> c.titlecase(Locale.getDefault()) } }
    return TextosPdf(stringResource(R.string.lb_pdf_dias), stringResource(R.string.lb_pasos_ganados), stringResource(R.string.lb_recuerdos), stringResource(R.string.lb_cumbres_firmadas),
        stringResource(R.string.lb_carta_corta), stringResource(R.string.lb_un_mes_silencio), meses,
        TipoHito.entries.associateWith { tipoHito(it) }, stringResource(R.string.lb_campamento_x, "%s"), stringResource(R.string.lb_mi_cumbre))
}

/** El libro del año en PDF (A4, solo texto): portada, cumbres firmadas, cada mes y la carta. */
private fun escribirPdf(out: java.io.OutputStream, titulo: String, meses: List<DatosMes>, firmas: List<Hito>, carta: String, t: TextosPdf) {
    val doc = PdfDocument(); val ancho = 595; val alto = 842; val margen = 48f
    var n = 0; var pagina: PdfDocument.Page? = null; var y = 0f
    val tituloP = TextPaint().apply { isAntiAlias = true; textSize = 26f; typeface = android.graphics.Typeface.SERIF; color = 0xFF2B1D17.toInt() }
    val subP = TextPaint().apply { isAntiAlias = true; textSize = 17f; typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD); color = 0xFF2B1D17.toInt() }
    val texP = TextPaint().apply { isAntiAlias = true; textSize = 11.5f; color = 0xFF2B1D17.toInt() }
    fun nueva() { pagina?.let { doc.finishPage(it) }; n++; pagina = doc.startPage(PdfDocument.PageInfo.Builder(ancho, alto, n).create()); y = margen }
    fun escribir(s: String, p: TextPaint, despues: Float = 6f) {
        val l = StaticLayout.Builder.obtain(s, 0, s.length, p, (ancho - 2 * margen).toInt()).setAlignment(Layout.Alignment.ALIGN_NORMAL).build()
        if (pagina == null || y + l.height > alto - margen) nueva()
        val cv = pagina!!.canvas; cv.save(); cv.translate(margen, y); l.draw(cv); cv.restore(); y += l.height + despues
    }
    escribir(titulo, tituloP, 14f)
    escribir("${meses.sumOf { it.constancia }} ${t.dias} · ${meses.sumOf { it.pasos.size }} ${t.pasos} · ${meses.sumOf { it.fotos.size }} ${t.recuerdos} · ${firmas.size} ${t.cumbres}", texP, 18f)
    firmas.forEach { h ->
        val tit = when (h.tipo) { TipoHito.CAMPAMENTO -> t.campamento.format(h.cod ?: ""); TipoHito.CUMBRE -> t.miCumbre; else -> h.titulo }
        escribir("${t.tipos[h.tipo]} · $tit · ${fechaLarga(h.fecha)}", subP, 4f)
        h.firma?.texto?.takeIf { it.isNotBlank() }?.let { escribir("“$it”", texP, 12f) }
    }
    meses.reversed().forEach { d ->
        escribir("${t.meses[d.ym.monthValue - 1]} ${d.ym.year}", subP, 4f)
        if (d.vacio) escribir(t.silencio, texP, 12f)
        else {
            escribir("${d.constancia} ${t.dias} · ${d.pasos.size} ${t.pasos} · ${d.fotos.size} ${t.recuerdos}", texP, 4f)
            d.pasos.forEach { (_, txt, f) -> escribir("• $txt (${fechaLarga(f)})", texP, 2f) }
            d.alto.forEach { (nm, q, r) -> escribir("$nm — $q\n$r", texP, 4f) }
            if (d.frase.isNotBlank()) escribir("“${d.frase}”", texP, 4f)
            y += 8f
        }
    }
    if (carta.isNotBlank()) { escribir(t.carta, subP, 4f); escribir(carta, texP) }
    pagina?.let { doc.finishPage(it) }
    doc.writeTo(out); doc.close()
}

/* ---------------------------------------------------------------- Entradas y la página en Comunidad */

/** La entrada al libro en Mi ruta. */
@Composable
fun EntradaLibro(onClick: () -> Unit) {
    val vm = rutaViewModel { LibroViewModel(it) }
    val n = vm.hitos.count { it.firma == null }
    Surface(onClick = onClick, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment = Alignment.Center) { Icon(Icons.Filled.Terrain, null, tint = MaterialTheme.colorScheme.primary) }
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.lb_titulo), style = MaterialTheme.typography.titleMedium)
                Text((if (n > 0) stringResource(R.string.lb_por_firmar, n) + " · " else "") + stringResource(R.string.lb_sub_corto), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** El ícono del libro junto al título de la vida en años, con el número de páginas por firmar. */
@Composable
fun IconoLibro(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val vm = rutaViewModel { LibroViewModel(it) }
    val n = vm.hitos.count { it.firma == null }
    val desc = stringResource(R.string.lb_titulo) + if (n > 0) ", " + stringResource(R.string.lb_por_firmar, n) else ""
    IconButton(onClick = onClick, modifier = modifier.semantics { contentDescription = desc }) {
        BadgedBox(badge = { if (n > 0) Badge { Text("$n") } }) {
            Icon(Icons.Filled.MenuBook, null, tint = MaterialTheme.colorScheme.primary)
        }
    }
}

/** La cápsula de un mes, dentro del mes en Mi ruta. */
@Composable
fun BotonCapsula(ym: YearMonth, onClick: () -> Unit) {
    val vm = rutaViewModel { LibroViewModel(it) }
    val libro by vm.libro.collectAsState()
    val cerrado = ym < YearMonth.now(); val abierta = !libro[Libro.claveCapsula(ym)].isNullOrBlank()
    Surface(onClick = onClick, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface, border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Lacre(44)
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.lb_capsula_de, nombreMesLargo(ym)), style = MaterialTheme.typography.titleSmall)
                Text(stringResource(when { !cerrado -> R.string.lb_se_llena; abierta -> R.string.lb_releer; else -> R.string.lb_lista_abrir }), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** En Hoy: la cápsula del mes pasado lista para abrir (los primeros 10 días) y «Hace un año hoy». */
@Composable
fun TarjetasLibroHoy(onCapsula: (String) -> Unit, onPost: (String) -> Unit) {
    val vm = rutaViewModel { LibroViewModel(it) }
    val ctx = LocalContext.current
    val libro by vm.libro.collectAsState()
    val posts by vm.posts.collectAsState()
    val ym = YearMonth.now().minusMonths(1)
    var hayAlgo by remember { mutableStateOf(false) }
    LaunchedEffect(posts, vm.hitos) { hayAlgo = LocalDate.now().dayOfMonth <= 10 && !vm.datosMes(ctx, ym, conFogatas = false).vacio }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (hayAlgo && libro[Libro.claveCapsula(ym)].isNullOrBlank()) Surface(onClick = { onCapsula(ym.toString()) }, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface,
            border = BorderStroke(1.dp, ORO.copy(alpha = 0.6f)), modifier = Modifier.fillMaxWidth()) {
            Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Lacre(44)
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.lb_capsula_lista, ym.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault())), style = MaterialTheme.typography.titleSmall)
                    Text(stringResource(R.string.lb_capsula_lista_d), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null)
            }
        }
        vm.haceUnAnio()?.let { p -> HaceUnAnio(p) { onPost(p.id) } }
    }
}

/** La página del libro en Cimas, en el muro y en la vista previa de Publicar. */
@Composable
fun TarjetaLibro(lb: JsonObject, texto: String, modifier: Modifier = Modifier, compacta: Boolean = false) {
    fun s(k: String) = (lb[k] as? JsonPrimitive)?.contentOrNull.orEmpty()
    fun n(k: String) = (lb[k] as? JsonPrimitive)?.intOrNull ?: 0
    val i = (lb["i"] as? JsonPrimitive)?.intOrNull ?: -1
    val fotos = (lb["fotos"] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.contentOrNull }?.filter { it.isNotBlank() }.orEmpty()
    val c = colorHito(i)
    Surface(shape = RoundedCornerShape(16.dp), color = PAPEL, shadowElevation = if (compacta) 0.dp else 12.dp,
        border = if (compacta) BorderStroke(1.dp, Color(0xFFE8DCC6)) else null, modifier = modifier.widthIn(max = 360.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.lb_titulo), style = MaterialTheme.typography.labelMedium, color = TINTA_SUAVE, modifier = Modifier.weight(1f))
                Lacre(32)
            }
            val (etiqueta, titulo, sub) = when (s("t")) {
                "firma" -> {
                    val tipo = runCatching { TipoHito.valueOf(s("tipo")) }.getOrDefault(TipoHito.META)
                    Triple(tipoHito(tipo), when (tipo) { TipoHito.CAMPAMENTO -> stringResource(R.string.lb_campamento_x, nombreCodigo(s("cod").ifBlank { Mandala.CAMPAMENTOS_FIJOS.getOrElse(i) { "CON" } })); TipoHito.CUMBRE -> stringResource(R.string.lb_mi_cumbre); else -> s("titulo") }, fechaLarga(s("fecha")))
                }
                "capsula" -> Triple(stringResource(R.string.lb_t_capsula), runCatching { nombreMesLargo(YearMonth.parse(s("ym"))) }.getOrDefault(s("ym")),
                    stringResource(R.string.lb_resumen_capsula, n("dias"), n("de"), n("pasos"), n("recuerdos")))
                else -> Triple(stringResource(R.string.lb_t_anio), s("anio"), stringResource(R.string.lb_resumen_anio, n("dias"), n("pasos"), n("cumbres")))
            }
            Row(Modifier.clip(RoundedCornerShape(50)).background(c.copy(alpha = 0.16f)).padding(horizontal = 10.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.size(7.dp).clip(CircleShape).background(c)); Text(etiqueta, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = TINTA)
            }
            Text(titulo, style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Serif), color = TINTA)
            if (s("t") == "firma") {
                if (sub.isNotBlank()) Text(sub, style = MaterialTheme.typography.bodySmall, color = TINTA_SUAVE)
                s("foto").takeIf { it.startsWith("http") }?.let { AsyncImage(it, null, Modifier.fillMaxWidth().heightIn(max = 240.dp).rotate(-0.8f).border(5.dp, Color.White, RoundedCornerShape(8.dp)).clip(RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop) }
                if (texto.isNotBlank() && !compacta) Text("“$texto”", style = MaterialTheme.typography.bodyLarge.copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic), color = TINTA, maxLines = 4, overflow = TextOverflow.Ellipsis)
            } else {
                if (fotos.isNotEmpty()) fotos.take(4).chunked(2).forEach { fila ->
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { fila.forEach { AsyncImage(it, null, Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(6.dp)), contentScale = ContentScale.Crop) }; if (fila.size == 1 && fotos.size > 1) Spacer(Modifier.weight(1f)) }
                }
                Text(sub, style = MaterialTheme.typography.bodySmall, color = TINTA_SUAVE)
            }
        }
    }
}

/** En Publicar: la página del libro que viaja con la publicación, con la opción de quitarla. */
@Composable
fun PreviaLibro(lb: JsonObject, onQuitar: () -> Unit) = Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
    TarjetaLibro(lb, "", Modifier.fillMaxWidth(), compacta = true)
    OutlinedButton(onClick = onQuitar) { Text(stringResource(R.string.lb_sin_pagina)) }
}
