package com.rutaalacima.app.data.social

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/** Un paso del recorrido: qué hizo [t], cuándo [f] ("2026-03" o "2026-03-14") y un detalle opcional [d]. */
data class PasoP(val t: String, val f: String = "", val d: String = "")

/**
 * Paso a paso (igual que la web, web/js/57-paso-a-paso.js): cómo se logró una meta o un propósito,
 * de la salida a la cumbre. Se guarda en la columna "pasos" de posts (supabase/2026-11-05-paso-a-paso.sql):
 *   { "meta": "Correr mi primera media maratón", "pasos": [{ "t": "…", "f": "2026-01", "d": "…" }] }
 */
data class PasoAPaso(val meta: String, val pasos: List<PasoP>) {
    companion object {
        const val MAX = 12; const val MAX_T = 90; const val MAX_D = 240; const val MAX_META = 90
        private val FECHA = Regex("^\\d{4}-\\d\\d(-\\d\\d)?$")

        /** Limpia lo escrito o lo que llega de la base; null si no queda ningún paso. */
        fun limpiar(meta: String, pasos: List<PasoP>): PasoAPaso? {
            val l = pasos.map { PasoP(it.t.trim().take(MAX_T), it.f.takeIf { f -> FECHA.matches(f) }.orEmpty(), it.d.trim().take(MAX_D)) }
                .filter { it.t.isNotEmpty() }.take(MAX)
            return if (l.isEmpty()) null else PasoAPaso(meta.trim().take(MAX_META), l)
        }

        fun de(e: JsonElement?): PasoAPaso? = runCatching {
            val o = when (e) {
                is JsonObject -> e
                is JsonPrimitive -> e.contentOrNull?.takeIf { it.startsWith("{") }?.let { kotlinx.serialization.json.Json.parseToJsonElement(it).jsonObject }
                else -> null
            } ?: return null
            val arr = o["pasos"] as? JsonArray ?: return null
            limpiar(o["meta"]?.jsonPrimitive?.contentOrNull.orEmpty(), arr.mapNotNull { x ->
                val p = x as? JsonObject ?: return@mapNotNull null
                PasoP(p["t"]?.jsonPrimitive?.contentOrNull.orEmpty(), p["f"]?.jsonPrimitive?.contentOrNull.orEmpty(), p["d"]?.jsonPrimitive?.contentOrNull.orEmpty())
            })
        }.getOrNull()

        fun json(r: PasoAPaso): JsonObject = buildJsonObject {
            put("meta", r.meta)
            put("pasos", JsonArray(r.pasos.map { p -> buildJsonObject { put("t", p.t); if (p.f.isNotEmpty()) put("f", p.f); if (p.d.isNotEmpty()) put("d", p.d) } }))
        }
    }
}
