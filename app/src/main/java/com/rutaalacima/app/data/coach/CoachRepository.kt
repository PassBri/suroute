package com.rutaalacima.app.data.coach

import android.content.Context
import com.rutaalacima.app.R
import com.rutaalacima.app.data.bancos.BancosRepository
import com.rutaalacima.app.data.local.CoachMensajeEntity
import com.rutaalacima.app.data.local.RutaDatabase
import com.rutaalacima.app.data.local.avance
import com.rutaalacima.app.data.local.puntajes
import com.rutaalacima.app.data.remote.SupabaseClient
import com.rutaalacima.app.domain.model.Cuentas
import com.rutaalacima.app.domain.model.Deudas
import com.rutaalacima.app.domain.model.Eje
import com.rutaalacima.app.domain.model.MetasFin
import com.rutaalacima.app.domain.model.Fase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.LocalDate
import java.util.Locale

/**
 * Coach de IA de SuRoute.
 *  - Con servidor: llama a la Edge Function "coach" de Supabase (supabase/functions/coach),
 *    que guarda la clave de la IA en el servidor y responde con el método Ruta a la Cima.
 *  - Sin servidor: un coach basado en reglas del método (ejes débiles, protocolos, bancos).
 * En ambos casos se envía un resumen del contexto del usuario (cumbre, fase, ejes y metas).
 */
class CoachRepository(
    private val context: Context,
    private val db: RutaDatabase,
    private val supa: SupabaseClient,
    private val bancos: BancosRepository,
) {
    val conversacion: Flow<List<CoachMensajeEntity>> = db.coachDao().observe()
    val conIA: Boolean get() = supa.configurado

    suspend fun borrar() = db.coachDao().borrarTodo()

    // ---------- Los controles: el tema de la conversación (propósito, metas o finanzas)
    private val prefs = context.getSharedPreferences("coach", Context.MODE_PRIVATE)
    /** "" (general), "proposito", "metas" o "finanzas". Decide qué aconseja el coach y si viajan las finanzas. */
    val tema = kotlinx.coroutines.flow.MutableStateFlow(prefs.getString("tema", "").orEmpty())
    fun elegirTema(t: String) { tema.value = t; prefs.edit().putString("tema", t).apply() }

    /** Por qué el coach con IA no respondió (null si respondió): la pantalla lo dice en lugar de disfrazar la guía. */
    val aviso = kotlinx.coroutines.flow.MutableStateFlow<String?>(null)

    /** Envía un mensaje al coach, guarda la conversación y devuelve la respuesta. */
    suspend fun enviar(texto: String): String {
        db.coachDao().insert(CoachMensajeEntity(rol = "user", texto = texto.trim()))
        val respuesta = (if (supa.configurado) runCatching { remoto() }.onSuccess { aviso.value = null }.onFailure { e ->
            val m = e.message.orEmpty()
            aviso.value = when {
                e is com.rutaalacima.app.data.remote.SupabaseException && e.codigo == 404 -> context.getString(R.string.coach_aviso_sin_funcion)
                "ANTHROPIC_API_KEY" in m -> context.getString(R.string.coach_aviso_sin_clave)
                else -> context.getString(R.string.coach_aviso_error, m.take(120).ifBlank { "?" })
            }
        }.getOrNull() else null) ?: local(texto)
        db.coachDao().insert(CoachMensajeEntity(rol = "assistant", texto = respuesta))
        return respuesta
    }

    // ---------- Reportar una respuesta (política de IA generativa de Google Play)
    private val reportadas = context.getSharedPreferences("coach_reportes", Context.MODE_PRIVATE)
    val idsReportados = kotlinx.coroutines.flow.MutableStateFlow(reportadas.getStringSet("ids", emptySet()).orEmpty())

    /** Envía a moderación la respuesta del coach y el mensaje que la provocó. Sin cuenta, solo se marca aquí. */
    suspend fun reportar(id: Long, motivo: String, detalle: String): Boolean {
        val todos = db.coachDao().ultimos(200).sortedBy { it.id }
        val i = todos.indexOfFirst { it.id == id }; if (i < 0) return false
        val pregunta = todos.take(i).lastOrNull { it.rol == "user" }?.texto.orEmpty()
        val yo = supa.sesion.value?.userId
        if (supa.configurado && yo != null) {
            val ok = runCatching {
                supa.insert("coach_reportes", buildJsonObject {
                    put("quien", yo); put("motivo", motivo); put("detalle", detalle.take(1000))
                    put("pregunta", pregunta.take(2000)); put("respuesta", todos[i].texto.take(8000)); put("tema", tema.value)
                }, devolver = false)
            }.isSuccess
            if (!ok) return false
        }
        idsReportados.value = idsReportados.value + id.toString()
        reportadas.edit().putStringSet("ids", idsReportados.value).apply()
        return true
    }

    /** Pregunta puntual sin guardar en la conversación (p. ej. "mejorar esta meta"). */
    suspend fun consultar(instruccion: String): String? = runCatching {
        if (!supa.configurado) return null
        val r = supa.funcion("coach", buildJsonObject {
            put("contexto", contexto())
            put("idioma", Locale.getDefault().language)
            put("mensajes", buildJsonArray { add(buildJsonObject { put("role", "user"); put("content", instruccion) }) })
        })
        r.jsonObject["texto"]?.jsonPrimitive?.contentOrNull
    }.getOrNull()

    private suspend fun remoto(): String? {
        val historial = db.coachDao().ultimos(24).reversed()
        val r = supa.funcion("coach", buildJsonObject {
            put("contexto", contexto())
            put("idioma", Locale.getDefault().language)
            put("tema", tema.value)
            put("mensajes", buildJsonArray {
                historial.forEach { m -> add(buildJsonObject { put("role", m.rol); put("content", m.texto) }) }
            })
        })
        // El servidor avisa si se llegó al límite del día: la pantalla ofrece el Plan Cumbre a quien no lo tiene
        limiteAlcanzado.value = r.jsonObject["limite"]?.jsonPrimitive?.contentOrNull == "true" &&
            r.jsonObject["cumbre"]?.jsonPrimitive?.contentOrNull != "true"
        return r.jsonObject["texto"]?.jsonPrimitive?.contentOrNull
    }

    /** true si el último mensaje llegó al límite diario del plan gratuito. */
    val limiteAlcanzado = kotlinx.coroutines.flow.MutableStateFlow(false)

    /** Resumen del usuario para que el coach responda con su realidad. */
    suspend fun contexto(): String {
        val perfil = db.perfilDao().get()
        val eval = db.evaluacionDao().observeUltima().first()
        val props = db.planificadorDao().observePropositos().first()
        val anio = LocalDate.now().year
        val anuales = db.planificadorDao().observeMetas(anio).first()
        val hoy = LocalDate.now()
        val mensuales = db.planAnualDao().observeMetasMes(hoy.year, hoy.monthValue).first()
        return buildString {
            perfil?.let {
                appendLine("Nombre: ${it.nombre}")
                if (it.cumbreFrase.isNotBlank()) appendLine("Cumbre personal: ${it.cumbreFrase}")
                Fase.fromName(it.faseActual)?.let { f -> appendLine("Fase actual: ${f.numero}. ${f.nombre}") }
            }
            eval?.let { e ->
                appendLine("Ejes (1-10): " + Eje.entries.zip(e.puntajes()).joinToString { "${it.first.nombre} ${it.second}" })
            }
            if (props.isNotEmpty()) appendLine("Propósitos a 5 años: " + props.joinToString("; ") { "${it.titulo} (${it.progreso}%)" })
            if (anuales.isNotEmpty()) appendLine("Metas $anio: " + anuales.joinToString("; ") { "${it.titulo} (${it.avance}%)" })
            if (mensuales.isNotEmpty()) appendLine("Metas de este mes: " + mensuales.joinToString("; ") { "${it.texto} (${(it.avance() * 100).toInt()}%)" })
            // Constancia y lo último que escribió en sus revisiones (para que el coach recuerde)
            val dias = db.checklistDao().observeDesde(hoy.minusDays(60).toString()).first()
                .filter { it.marcados.isNotBlank() }.mapNotNull { runCatching { LocalDate.parse(it.fecha) }.getOrNull() }.toSet()
            appendLine("Racha de días con hábitos: ${com.rutaalacima.app.domain.model.Comodines.calcular(dias, hoy).let { "${it.racha} (comodines guardados: ${it.disponibles})" }}; días con hábitos en las últimas 4 semanas: ${dias.count { !it.isBefore(hoy.minusDays(28)) }}")
            val revision = db.respuestaDao().getWorkbook("revision").filter { it.clave.contains("#q") }
                .sortedByDescending { it.clave }.take(3)
            if (revision.isNotEmpty()) appendLine("Su última revisión: " + revision.joinToString(" | ") { r ->
                val q = when (r.clave.substringAfterLast("#q")) { "1" -> "Funcionó"; "2" -> "Lo frenó"; else -> "Paso clave" }
                "$q: ${r.valor.take(200)}"
            })
            // Las finanzas solo viajan cuando la persona elige hablar de finanzas (sus cifras son privadas)
            if (tema.value == "finanzas") appendLine(contextoFinanciero())
        }
    }

    /** Los últimos 3 meses de Ascenso financiero, deudas y metas financieras (igual que la web). */
    private suspend fun contextoFinanciero(): String = runCatching {
        val fin = db.respuestaDao().getWorkbook(com.rutaalacima.app.domain.model.Cuentas.WB).associate { it.clave to it.valor }
        val propias = Cuentas.leerPropias(fin["fin#cats"])
        val hoy = LocalDate.now()
        val l = mutableListOf("Finanzas (moneda ${Cuentas.moneda(fin[Cuentas.CLAVE_MONEDA])}):")
        (0L..2L).map { java.time.YearMonth.from(hoy).minusMonths(it).toString() }.forEach { ym ->
            val movs = fin.filterKeys { it.startsWith(Cuentas.PREFIJO + ym) }.values.flatMap { Cuentas.leer(it) }
            if (movs.isEmpty()) return@forEach
            val s = Cuentas.sumar(movs, propias)
            val mo = if (s.gas > 0) " · mochilas verde ${((s.mochilas[Cuentas.Mochila.VERDE] ?: 0.0) / s.gas * 100).toInt()}%, amarilla ${((s.mochilas[Cuentas.Mochila.AMARILLA] ?: 0.0) / s.gas * 100).toInt()}%" else ""
            l += "- $ym: ingresos ${s.ing.toLong()}, gastos ${s.gas.toLong()}, ahorro ${s.aho.toLong()}, inversión ${s.inv.toLong()}, dar ${s.gen.toLong()}, disponible ${s.disponible.toLong()}" +
                (s.tasa?.let { ", tasa de ahorro e inversión ${(it * 100).toInt()}%" } ?: "") + mo
        }
        val d = Deudas.leer(fin[Deudas.CLAVE])
        if (d.lista.isNotEmpty()) l += "- Deudas: " + d.lista.joinToString("; ") { "${it.nombre.ifBlank { "deuda" }} saldo ${it.saldo.toLong()}" + (if (it.tasa > 0) " al ${it.tasa}%" else "") } + " (método ${d.metodo})"
        val metas = MetasFin.leer(fin[MetasFin.CLAVE])
        if (metas.isNotEmpty()) l += "- Metas financieras: " + metas.joinToString("; ") { "${it.nombre} objetivo ${it.objetivo.toLong()}" + (if (it.fecha.isNotBlank()) " para ${it.fecha}" else "") }
        if (l.size > 1) l.joinToString("\n") else "Finanzas: todavía no ha registrado movimientos en Ascenso financiero."
    }.getOrDefault("")

    // ------------------------------------------------------------------ Coach sin servidor

    private suspend fun local(texto: String): String {
        val t = texto.lowercase()
        fun tiene(vararg p: String) = p.any { it in t }
        val eval = db.evaluacionDao().observeUltima().first()
        val debil = eval?.let { e -> Eje.entries.zip(e.puntajes()).minByOrNull { it.second }?.first }
        val b = bancos.bancos()
        return when {
            tiene("motiv", "ganas", "cansad", "fuego", "motivation", "tired") -> context.getString(R.string.coach_local_motivacion)
            tiene("rendir", "abandon", "dejar", "quit", "give up") -> context.getString(R.string.coach_local_rendirse)
            tiene("perdid", "confund", "no sé", "no se", "lost", "confus") -> context.getString(R.string.coach_local_perdido)
            tiene("meta", "objetivo", "propósito", "proposito", "goal", "purpose") -> {
                val ejemplo = b.metas.filter { it.area in b.areasSugeridas(debil?.codigo) }.randomOrNull() ?: b.metas.random()
                context.getString(R.string.coach_local_meta, ejemplo.meta, ejemplo.observable, ejemplo.plazo)
            }
            else -> {
                val eje = debil ?: Eje.VOLUNTAD
                val acciones = b.accionesDe(eje.codigo).take(3).joinToString("\n") { "• ${it.texto}" }
                if (eval == null) context.getString(R.string.coach_local_sin_eval)
                else context.getString(R.string.coach_local_eje, context.getString(com.rutaalacima.app.ui.i18n.Textos.nombre(eje)), acciones)
            }
        }
    }
}
