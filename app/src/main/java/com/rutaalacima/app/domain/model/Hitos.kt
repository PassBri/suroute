package com.rutaalacima.app.domain.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * Hitos del ascenso financiero, igual que la web (web/js/56-hitos.js): las cumbres que el dinero hace posibles
 * (comprar la casa, un viaje, pagar la última cuota). Se planean con fecha y se marcan «¡Lo logré!».
 * Se guardan en "fin#hitos" del workbook "finanzas".
 */
object Hitos {
    const val CLAVE = "fin#hitos"
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    @Serializable
    data class Hito(val id: String, val t: String, val k: String = "otro", val f: String, val ok: Boolean = true, val m: Double? = null, val n: String? = null,
        /** Ícono de Material elegido por la persona (clave como "beach_access"); sin él, el del tipo. */
        val i: String? = null)

    /** Tipos de hito (el ícono se elige en la interfaz). */
    val TIPOS = listOf("casa", "viaje", "carro", "estudio", "deuda", "negocio", "ahorro", "familia", "otro")

    private val ser = ListSerializer(Hito.serializer())
    fun leer(v: String?): List<Hito> = if (v.isNullOrBlank()) emptyList()
        else runCatching { json.decodeFromString(ser, v) }.getOrDefault(emptyList()).filter { it.t.isNotBlank() && Regex("\\d{4}-\\d{2}-\\d{2}").matches(it.f) }
    fun escribir(l: List<Hito>): String = if (l.isEmpty()) "" else json.encodeToString(ser, l)
    fun guardar(l: List<Hito>, h: Hito) = if (l.any { it.id == h.id }) l.map { if (it.id == h.id) h else it } else l + h
}
