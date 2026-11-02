package com.rutaalacima.app.data.social

import com.rutaalacima.app.AppContainer
import com.rutaalacima.app.domain.model.Constancia
import com.rutaalacima.app.domain.model.Mandala
import com.rutaalacima.app.domain.model.MetodoCima
import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.LocalDate

/** El camino que hay detrás de una publicación: días seguidos con hábitos y pasos ganados de la Brújula. */
data class Camino(
    val racha: Int, val ganados: Int,
    /** Su Brújula: 64 caracteres 0/1 (campamento i, paso p → i*8+p), para pintar la mini-Brújula 9×9. */
    val mapa: String = "",
    /** El paso (o el hito) que se comparte con esta publicación. */
    val paso: PasoCompartido? = null,
    /** Una página del Libro de cumbres que viaja con la publicación (firma, cápsula del mes o libro del año), igual que la web. */
    val libro: JsonObject? = null,
) { val vacio get() = racha == 0 && ganados == 0 && paso == null && libro == null }

/** Un paso ganado que se comparte: campamento [i] (código [cod]), paso [p], cuántos lleva ese campamento [n] y el hito
 *  ("CAMPAMENTO" con los 8, "CUMBRE" con los 64, o null). Igual que la web (posts.camino.paso). */
data class PasoCompartido(val i: Int, val cod: String, val p: Int, val n: Int, val hito: String? = null)

/** Avisos de la Brújula hacia la comunidad: un paso recién ganado y el paso que se va a publicar. */
object ExpedicionEventos {
    private val _ganados = kotlinx.coroutines.flow.MutableSharedFlow<Pair<Long, Int>>(extraBufferCapacity = 8)
    /** (casilla, paso) de cada paso que se acaba de ganar. */
    val ganados: kotlinx.coroutines.flow.SharedFlow<Pair<Long, Int>> = _ganados
    private val claveHecho = Regex("""^mandala#(\d+)#(\d)#hecho$""")
    /** Lo llama RespuestasRepository al guardar: solo cuenta lo ganado hoy o ayer (no lo que llega al sincronizar). */
    fun alGuardar(clave: String, valor: String) {
        val m = claveHecho.find(clave) ?: return
        val f = runCatching { LocalDate.parse(valor.take(10)) }.getOrNull() ?: return
        if (f.isBefore(LocalDate.now().minusDays(1))) return
        _ganados.tryEmit(m.groupValues[1].toLong() to m.groupValues[2].toInt())
    }
    /** El paso que viaja a la siguiente publicación (lo pone «Compartir este paso» y lo toma Publicar). */
    @Volatile var pendiente: PasoCompartido? = null
    /** La página del Libro de cumbres que viaja a la siguiente publicación. */
    @Volatile var libroPendiente: JsonObject? = null
}

/** Un compromiso con fecha: abierto hasta [hasta]; al vencer, el autor dice si lo logró o lo replantea. */
data class Compromiso(val hasta: String, val estado: String = ABIERTO) {
    companion object { const val ABIERTO = "ABIERTO"; const val LOGRADO = "LOGRADO"; const val REPLANTEO = "REPLANTEO" }
}

/** Lo nuevo de una publicación (columnas camino, compromiso y sello). */
data class ExtrasPost(val camino: Camino? = null, val compromiso: Compromiso? = null, val sello: String? = null)

/**
 * Comunidad viva (igual que web/js/45-comunidad-viva.js): lo que hace distinta a SuRoute.
 * Aquí no se premia la atención sino el avance real.
 */
object ComunidadViva {
    const val PASOS_BRUJULA = 64

    /** El camino de hoy de esta persona: racha de días con hábitos y pasos ganados de su Brújula general. */
    suspend fun caminoActual(c: AppContainer): Camino = runCatching {
        val hoy = LocalDate.now()
        val dias = c.checklist.desde(hoy.minusDays(800)).first().filterValues { it.isNotEmpty() }.keys
        val racha = Constancia.racha(dias, hoy)
        val r = c.respuestas.cargar(Mandala.WORKBOOK)
        val generales = c.db.visionDao().todas().filter { Mandala.anioDeOrigen(it.origen) == null }
        val camps = Mandala.repartir(generales, { it.origen }, { it.eje }).second.map { it?.id }
        val pasos = MetodoCima.pasosDe(camps, r)
        Camino(racha, pasos.count { it.cumplido }, mapa = pasos.joinToString("") { if (it.cumplido) "1" else "0" })
    }.getOrDefault(Camino(0, 0))

    /** El eje de tu campamento más flojo (el que menos pasos ha ganado): "Para ti" muestra primero lo de ese tramo. */
    suspend fun tramoMio(c: AppContainer): String? = runCatching {
        val r = c.respuestas.cargar(Mandala.WORKBOOK)
        val generales = c.db.visionDao().todas().filter { Mandala.anioDeOrigen(it.origen) == null }
        val camps = Mandala.repartir(generales, { it.origen }, { it.eje }).second
        camps.mapIndexedNotNull { i, cas -> cas ?: return@mapIndexedNotNull null
            val cod = Mandala.CAMPAMENTOS_FIJOS[i]
            if (cod == "CON" || cod == "CAM") return@mapIndexedNotNull null
            cod to (0 until Mandala.PASOS).count { MetodoCima.leer(cas.id, it, r).cumplido }
        }.minByOrNull { it.second }?.first
    }.getOrNull()

    /** Sellada para quien no es el autor, hasta la fecha en que se abre. */
    fun estaSellada(p: Post): Boolean = !p.propio && p.sello != null && LocalDate.now().toString() < p.sello

    /** Bono de "Para ti": tu tramo y el camino real detrás (igual que la web). */
    fun bono(p: Post, tramo: String?): Double {
        val c = p.camino
        return (if (tramo != null && p.eje == tramo) 1.5 else 1.0) *
            (if (c != null) 1 + minOf(0.5, kotlin.math.ln(1.0 + c.racha + c.ganados) / kotlin.math.ln(2.0) / 12) else 1.0) *
            (if (p.compromiso?.estado == Compromiso.LOGRADO) 1.2 else 1.0)
    }

    // ---------- JSON ----------
    private fun obj(e: JsonElement?): JsonObject? = when (e) {
        is JsonObject -> e
        is JsonPrimitive -> e.contentOrNull?.takeIf { it.startsWith("{") }?.let { runCatching { kotlinx.serialization.json.Json.parseToJsonElement(it).jsonObject }.getOrNull() }
        else -> null
    }
    fun caminoDe(e: JsonElement?): Camino? = obj(e)?.let { o ->
        val pa = obj(o["paso"])?.let { x ->
            PasoCompartido(x["i"]?.jsonPrimitive?.intOrNull ?: 0, x["cod"]?.jsonPrimitive?.contentOrNull.orEmpty(), x["p"]?.jsonPrimitive?.intOrNull ?: 0,
                x["n"]?.jsonPrimitive?.intOrNull ?: 0, x["hito"]?.jsonPrimitive?.contentOrNull)
        }
        Camino(o["racha"]?.jsonPrimitive?.intOrNull ?: 0, o["ganados"]?.jsonPrimitive?.intOrNull ?: 0,
            o["mapa"]?.jsonPrimitive?.contentOrNull?.takeIf { it.length == 64 }.orEmpty(), pa, o["libro"] as? JsonObject).takeUnless { it.vacio }
    }
    fun compromisoDe(e: JsonElement?): Compromiso? = obj(e)?.let { o ->
        val h = o["hasta"]?.jsonPrimitive?.contentOrNull ?: return@let null
        Compromiso(h, o["estado"]?.jsonPrimitive?.contentOrNull ?: Compromiso.ABIERTO)
    }
    fun selloDe(e: JsonElement?): String? = obj(e)?.get("abre")?.jsonPrimitive?.contentOrNull
    fun json(c: Camino) = buildJsonObject {
        put("racha", c.racha); put("ganados", c.ganados)
        if (c.mapa.length == 64 && '1' in c.mapa) put("mapa", c.mapa)
        c.libro?.let { put("libro", it) }
        c.paso?.let { pa -> put("paso", buildJsonObject { put("i", pa.i); put("cod", pa.cod); put("p", pa.p); put("n", pa.n); pa.hito?.let { put("hito", it) } }) }
    }
    fun json(k: Compromiso) = buildJsonObject { put("hasta", k.hasta); put("estado", k.estado) }
    fun jsonSello(abre: String) = buildJsonObject { put("abre", abre) }

    /** Lo que se guarda en el teléfono para una publicación propia. */
    fun aTexto(x: ExtrasPost): String = buildJsonObject {
        x.camino?.let { put("camino", json(it)) }; x.compromiso?.let { put("compromiso", json(it)) }; x.sello?.let { put("sello", jsonSello(it)) }
    }.toString()
    fun deTexto(s: String?): ExtrasPost = if (s.isNullOrBlank()) ExtrasPost() else runCatching {
        val o = kotlinx.serialization.json.Json.parseToJsonElement(s).jsonObject
        ExtrasPost(caminoDe(o["camino"]), compromisoDe(o["compromiso"]), selloDe(o["sello"]))
    }.getOrDefault(ExtrasPost())

    /** Cordada: quien lleva 3 días seguidos sin marcar (sin contar hoy) necesita una cuerda. */
    fun necesitaCuerda(dias: Set<LocalDate>, inicio: LocalDate, hoy: LocalDate = LocalDate.now()): Boolean {
        if (hoy in dias) return false
        val ultimos = (1..3).map { hoy.minusDays(it.toLong()) }
        return ultimos.all { !it.isBefore(inicio) } && ultimos.none { it in dias }
    }
}
