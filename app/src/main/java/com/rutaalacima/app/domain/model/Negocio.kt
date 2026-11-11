package com.rutaalacima.app.domain.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.YearMonth

/**
 * Mi negocio, igual que la web (web/js/58-negocio.js): las cuentas de cada negocio, aparte de las finanzas personales.
 * Una persona puede llevar varios. Por ahora solo plata (lo que entra y sale); el inventario vendrá después.
 *   fin#neg#lista                 [{ id, n, g? }]
 *   fin#neg#<id>#mov#<aaaa-mm>    [{ id, f, t: ven|cos|gas|inv|pag, m, c?, n? }]
 *   fin#neg#<id>#bal              { a: [{ id, n?, k, m }], p: [{ id, n?, k, m }] }
 * Un «Pago a ti» (pag) escribe también un ingreso personal (categoría «negocio») en fin#mov#<fecha> con id "ng-<id>".
 */
object Negocio {
    const val LISTA = "fin#neg#lista"
    fun claveMes(id: String, ym: String) = "fin#neg#$id#mov#$ym"
    fun claveBal(id: String) = "fin#neg#$id#bal"
    fun prefijoMeses(id: String) = "fin#neg#$id#mov#"
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    @Serializable data class Neg(val id: String, val n: String, val g: String? = null)
    @Serializable data class Mov(val id: String, val f: String, val t: String, val m: Double, val c: String? = null, val n: String? = null)
    @Serializable data class Partida(val id: String, val k: String = "otro", val m: Double = 0.0, val n: String? = null)
    @Serializable data class Bal(val a: List<Partida> = emptyList(), val p: List<Partida> = emptyList())

    val TIPOS = listOf("ven", "cos", "gas", "inv", "pag")
    val CAT_GAS = listOf("arriendo", "servicios", "nomina", "publicidad", "transporte", "impuestos", "bancos", "otro")
    /** Activos: (clave, corriente) */
    val ACTIVOS = listOf("caja" to true, "cobrar" to true, "inventario" to true, "equipo" to false, "local" to false, "otro" to false)
    val PASIVOS = listOf("proveedores" to true, "corto" to true, "impuestos" to true, "largo" to false, "otro" to false)

    private val serL = ListSerializer(Neg.serializer()); private val serM = ListSerializer(Mov.serializer())
    fun lista(r: Map<String, String>): List<Neg> = runCatching { json.decodeFromString(serL, r[LISTA].orEmpty()) }.getOrDefault(emptyList()).filter { it.id.isNotBlank() && it.n.isNotBlank() }
    fun escribirLista(l: List<Neg>) = if (l.isEmpty()) "" else json.encodeToString(serL, l)
    fun movs(r: Map<String, String>, id: String, ym: String): List<Mov> = runCatching { json.decodeFromString(serM, r[claveMes(id, ym)].orEmpty()) }
        .getOrDefault(emptyList()).filter { it.t in TIPOS && it.m.isFinite() }
    fun escribirMovs(l: List<Mov>) = if (l.isEmpty()) "" else json.encodeToString(serM, l.map { it.copy(m = Math.round(it.m * 100) / 100.0, n = it.n?.take(120)?.ifBlank { null }) })
    fun bal(r: Map<String, String>, id: String): Bal = runCatching { json.decodeFromString(Bal.serializer(), r[claveBal(id)].orEmpty()) }.getOrDefault(Bal())
    fun escribirBal(b: Bal) = if (b.a.isEmpty() && b.p.isEmpty()) "" else json.encodeToString(Bal.serializer(), b)
    fun meses(r: Map<String, String>, id: String): List<String> = prefijoMeses(id).let { p -> r.filter { it.key.startsWith(p) && it.value.isNotBlank() }.keys.map { it.removePrefix(p) }.sorted() }

    class Cifras(val ven: Double, val cos: Double, val gas: Double, val inv: Double, val pag: Double, val cat: Map<String, Double>) {
        val bruta get() = ven - cos
        val util get() = bruta - gas
        val caja get() = util - inv - pag
    }
    fun cifras(l: List<Mov>): Cifras {
        fun s(t: String) = l.filter { it.t == t }.sumOf { it.m }
        return Cifras(s("ven"), s("cos"), s("gas"), s("inv"), s("pag"), l.filter { it.t == "gas" }.groupBy { it.c ?: "otro" }.mapValues { (_, v) -> v.sumOf { it.m } })
    }
    fun sumaBal(l: List<Partida>, tabla: List<Pair<String, Boolean>>, corriente: Boolean? = null) =
        l.filter { corriente == null || (tabla.firstOrNull { t -> t.first == it.k }?.second ?: false) == corriente }.sumOf { it.m }

    /** Indicadores de los últimos 12 meses hasta [ym]. clave → (valor, estado); los mismos medidores de la salud financiera. */
    class Salud12(val c: Cifras, val meses: Int, val activos: Double, val pasivos: Double, val ind: List<Salud.Indicador>, val ventasMes: Double)
    fun salud(r: Map<String, String>, id: String, ym: YearMonth): Salud12 {
        val ms = (0 until 12).map { ym.minusMonths(it.toLong()).toString() }
        val movs = ms.flatMap { movs(r, id, it) }; val n = ms.count { movs(r, id, it).isNotEmpty() }.coerceAtLeast(1)
        val c = cifras(movs); val b = bal(r, id)
        val act = sumaBal(b.a, ACTIVOS); val pas = sumaBal(b.p, PASIVOS); val actC = sumaBal(b.a, ACTIVOS, true); val pasC = sumaBal(b.p, PASIVOS, true)
        fun anual(v: Double) = v / n * 12
        fun est(v: Double, ok: Double, medio: Double, menor: Boolean = false) =
            if (menor) (if (v <= ok) Salud.Estado.OK else if (v <= medio) Salud.Estado.MEDIO else Salud.Estado.BAJO)
            else (if (v >= ok) Salud.Estado.OK else if (v >= medio) Salud.Estado.MEDIO else Salud.Estado.BAJO)
        val l = mutableListOf<Salud.Indicador>()
        if (c.ven > 0) {
            val margen = c.bruta / c.ven
            l += Salud.Indicador("nmargen", margen, est(margen, 0.3, 0.15))
            l += Salud.Indicador("nneto", c.util / c.ven, est(c.util / c.ven, 0.1, 0.03))
            if (margen > 0) { val pe = c.gas / n / margen; val vm = c.ven / n
                l += Salud.Indicador("npe", pe, if (vm >= pe * 1.2) Salud.Estado.OK else if (vm >= pe) Salud.Estado.MEDIO else Salud.Estado.BAJO) }
            if (act > 0) { l += Salud.Indicador("nroa", anual(c.util) / act, est(anual(c.util) / act, 0.1, 0.05))
                l += Salud.Indicador("nrot", anual(c.ven) / act, est(anual(c.ven) / act, 1.0, 0.5)) }
        }
        if (pasC > 0) l += Salud.Indicador("nliq", actC / pasC, est(actC / pasC, 1.2, 1.0))
        if (act > 0 && pas > 0) l += Salud.Indicador("nendeuda", pas / act, est(pas / act, 0.5, 0.7, true))
        return Salud12(c, n, act, pas, l, c.ven / n)
    }
}
