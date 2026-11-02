package com.rutaalacima.app.data.social

import com.rutaalacima.app.data.remote.SupabaseClient
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import java.time.Instant

/** Una fogata en vivo: el tema, el eje y quien la encendió. */
data class Fogata(
    val id: String,
    val titulo: String,
    val eje: String?,
    val autorId: String,
    val autor: String,
    val avatar: String,
    val empezo: Long,
)

/** Lo necesario para entrar a la sala de LiveKit. */
data class ConexionFogata(val fogata: Fogata, val url: String, val token: String, val anfitrion: Boolean)

/**
 * Fogatas en vivo: el registro vive en Supabase y el video en LiveKit. Encender, entrar, el latido y
 * apagar pasan por la función «fogata» (que firma el permiso de LiveKit); lo que cada quien se lleva va
 * directo a la tabla fogata_llevo.
 */
class FogataRepository(private val supa: SupabaseClient) {
    val disponible: Boolean get() = supa.configurado && supa.sesion.value != null
    private val yo: String get() = supa.sesion.value?.userId.orEmpty()

    private fun JsonObject.s(k: String) = (this[k] as? JsonPrimitive)?.contentOrNull.orEmpty()
    private fun fecha(s: String) = runCatching { Instant.parse(s).toEpochMilli() }
        .recoverCatching { java.time.OffsetDateTime.parse(s).toInstant().toEpochMilli() }.getOrDefault(System.currentTimeMillis())

    private fun fogataDe(o: JsonObject, autorPorDefecto: String = ""): Fogata {
        val a = o["autor"] as? JsonObject
        return Fogata(
            id = o.s("id"), titulo = o.s("titulo"), eje = o.s("eje").ifBlank { null }, autorId = o.s("user_id"),
            autor = a?.s("nombre")?.ifBlank { null } ?: a?.s("username")?.ifBlank { null } ?: autorPorDefecto.ifBlank { "Senderista" },
            avatar = a?.s("avatar_url").orEmpty(), empezo = fecha(o.s("empezo_at")),
        )
    }

    /** Las fogatas encendidas ahora (con latido en los últimos 3 minutos). */
    suspend fun vivas(): List<Fogata> {
        if (!disponible) return emptyList()
        val desde = Instant.now().minusSeconds(180).toString()
        val r = supa.select("fogatas", "select=id,titulo,eje,user_id,empezo_at,autor:profiles!fogatas_user_id_fkey(nombre,username,avatar_url)" +
            "&estado=eq.EN_VIVO&latido_at=gte.${SupabaseClient.enc(desde)}&order=empezo_at.desc&limit=12")
        return (r as? JsonArray)?.map { fogataDe(it.jsonObject) } ?: emptyList()
    }

    suspend fun puedeEncender(): Boolean = disponible && runCatching { (supa.rpc("puede_encender") as? JsonPrimitive)?.booleanOrNull == true }.getOrDefault(false)

    private fun conexion(r: JsonElement, autor: String, avatar: String): ConexionFogata {
        val o = r.jsonObject
        (o["error"] as? JsonPrimitive)?.contentOrNull?.let { throw IllegalStateException(it) }
        val f = fogataDe(o["fogata"]!!.jsonObject, autor).let { if (avatar.isNotBlank() && it.avatar.isBlank()) it.copy(avatar = avatar) else it }
        return ConexionFogata(f, o.s("url"), o.s("token"), (o["anfitrion"] as? JsonPrimitive)?.booleanOrNull == true)
    }

    suspend fun encender(titulo: String, eje: String?, miNombre: String, miAvatar: String): ConexionFogata =
        conexion(supa.funcion("fogata", buildJsonObject { put("accion", "encender"); put("titulo", titulo); eje?.let { put("eje", it) } }), miNombre, miAvatar)

    suspend fun entrar(f: Fogata): ConexionFogata =
        conexion(supa.funcion("fogata", buildJsonObject { put("accion", "entrar"); put("id", f.id) }), f.autor, f.avatar)
            .let { it.copy(fogata = it.fogata.copy(autor = f.autor, avatar = f.avatar)) }

    suspend fun latido(id: String, personas: Int) {
        runCatching { supa.funcion("fogata", buildJsonObject { put("accion", "latido"); put("id", id); put("personas", personas) }) }
    }

    suspend fun apagar(id: String) {
        supa.funcion("fogata", buildJsonObject { put("accion", "apagar"); put("id", id) })
    }

    /** Lo que me llevo de una fogata para mi paso de mañana (lo ve quien la encendió). */
    suspend fun llevo(id: String, texto: String) {
        supa.upsert("fogata_llevo", buildJsonObject { put("fogata_id", id); put("user_id", yo); put("texto", texto.take(280)) })
    }

    /** Lo que se llevaron de mi fogata: nombre y texto. */
    suspend fun llevaron(id: String): List<Pair<String, String>> = runCatching {
        supa.select("fogata_llevo", "select=texto,autor:profiles!fogata_llevo_user_id_fkey(nombre,username)&fogata_id=eq.$id&order=created_at").jsonArray.map {
            val o = it.jsonObject; val a = o["autor"] as? JsonObject
            (a?.s("nombre")?.ifBlank { null } ?: a?.s("username").orEmpty()) to o.s("texto")
        }
    }.getOrDefault(emptyList())

    suspend fun reportar(f: Fogata, texto: String) {
        supa.insert("reportes", buildJsonObject {
            put("quien", yo); put("a_quien", f.autorId); put("motivo", "Fogata en vivo «${f.titulo}» (${f.id}): $texto".take(1000))
        }, devolver = false)
    }

    suspend fun soyModerador(): Boolean = disponible && runCatching { (supa.rpc("es_moderador") as? JsonPrimitive)?.booleanOrNull == true }.getOrDefault(false)
}
