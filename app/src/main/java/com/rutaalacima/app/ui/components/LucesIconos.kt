package com.rutaalacima.app.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight

import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.rutaalacima.app.R
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Luces de Comunidad: cinco reacciones pintadas como objetos reales (vela, farol de queroseno,
 * estrella, luna y sol), con el mismo dibujo que la web (web/js/51-luces.js), en un lienzo de 64 × 64.
 * Conviven con el impulso y los climas. Un toque da tu luz de siempre; mantener abre las cinco
 * y deslizar el dedo elige una al soltar.
 */
object Luces {
    val IDS = listOf("vela", "farol", "estrella", "luna", "sol")
    fun nombre(ctx: android.content.Context, k: String): String = ctx.getString(
        when (k) { "vela" -> R.string.lz_vela; "farol" -> R.string.lz_farol; "estrella" -> R.string.lz_estrella; "luna" -> R.string.lz_luna; else -> R.string.lz_sol },
    )
    /** La última luz que eligió esta persona (al principio, el sol). */
    fun ultima(ctx: android.content.Context): String = ctx.getSharedPreferences("luces", 0).getString("ultima", "sol")?.takeIf { it in IDS } ?: "sol"
    fun recordar(ctx: android.content.Context, k: String) { ctx.getSharedPreferences("luces", 0).edit().putString("ultima", k).apply() }
    fun mas(luces: Map<String, Int>): List<String> =
        IDS.filter { (luces[it] ?: 0) > 0 }.sortedWith(compareByDescending<String> { luces[it] ?: 0 }.thenByDescending { IDS.indexOf(it) }).take(3)
}

private fun p(d: String): Path = PathParser().parsePathString(d).toPath()
private fun c(hex: Long, a: Float = 1f) = Color(hex).copy(alpha = a)

private object Formas {
    val gota1 = p("M23.4 30.6c-.8 5-.4 9.5.6 11.4.9 1.6 2.2 1.2 2.3-.6.2-3.3-.2-7.3-.5-10.6z")
    val gota2 = p("M37 31c.3 3 .6 4.6 1.5 5 .9.4 1.5-.4 1.4-2-.1-1.3-.4-2.2-.7-3z")
    val mecha = p("M32 30.4c.5-1.8.2-3.4-.5-4.8")
    val llama = p("M32 4.5C37.6 12.4 38.6 19.6 32 26.3 25.4 19.6 26.4 12.4 32 4.5z")
    val llamaIn = p("M32 12.5c2.6 3.8 3 7.4 0 11.4-3-4-2.6-7.6 0-11.4z")
    val asa = p("M21.5 13.5C21 1.5 43 1.5 42.5 13.5")
    val tapa = p("M21 17.5h22l-4-7.5H25z")
    val vidrio = p("M23.6 17.5C13.6 24 13.6 40.5 23.6 47h16.8c10-6.5 10-23 0-29.5z")
    val llamaF = p("M32 23.5c3.6 5 4.2 9.6 0 14-4.2-4.4-3.6-9 0-14z")
    val llamaFIn = p("M32 29c1.6 2.4 1.8 4.6 0 7-1.8-2.4-1.6-4.6 0-7z")
    val reflejo = p("M20 21.5c-2.6 6-2.6 15.5 0 21.5")
    val base = p("M19.5 47h25c3 0 5 2 5 5v3.6c0 2.4-1.8 4.4-4.2 4.4H18.7c-2.4 0-4.2-2-4.2-4.4V52c0-3 2-5 5-5z")
    val destello = p("M50 9l1.1 4.4L55.5 14.5l-4.4 1.1L50 20l-1.1-4.4L44.5 14.5l4.4-1.1z")
    val rayo = p("M32 3.5l2.2 12h-4.4z")
    val luna: Path = Path.combine(PathOperation.Difference,
        Path().apply { addOval(Rect(Offset(32f, 32f), 22f)) }, Path().apply { addOval(Rect(Offset(43f, 26f), 19.5f)) })

    /** Las diez caras de la estrella: 0 = clara (mira a la luz), 1 = media, 2 = oscura. */
    val caras: List<Pair<Path, Int>>
    val contorno: Path
    init {
        val cx = 32.0; val cy = 33.0
        val pts = (0 until 10).map { i -> val a = -PI / 2 + i * PI / 5; val r = if (i % 2 == 1) 10.5 else 26.0; Offset((cx + r * cos(a)).toFloat(), (cy + r * sin(a)).toFloat()) }
        caras = (0 until 10).map { i ->
            val a = pts[i]; val b = pts[(i + 1) % 10]
            val mx = (a.x + b.x) / 2 - cx; val my = (a.y + b.y) / 2 - cy
            val luz = (-mx * 0.6 - my * 0.8) / 20
            Path().apply { moveTo(cx.toFloat(), cy.toFloat()); lineTo(a.x, a.y); lineTo(b.x, b.y); close() } to (if (luz > 0.25) 0 else if (luz > -0.25) 1 else 2)
        }
        contorno = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) }; close() }
    }
}

private fun laton(x0: Float, x1: Float) = Brush.horizontalGradient(
    0f to c(0xFF7A5A1E), 0.3f to c(0xFFE9CB7E), 0.55f to c(0xFFB88E3A), 1f to c(0xFF5E4314), startX = x0, endX = x1)

/** Valores de la animación de una luz (o los de reposo, si está quieta). */
private class Pulso(val llama: Float, val halo: Float, val destello: Float, val giro: Float)

/** Una luz pintada. [animada] la enciende (llama que tiembla, halo que respira, destello y rayos). */
@Composable
fun Luz(k: String, modifier: Modifier = Modifier, animada: Boolean = false) {
    val ctx = LocalContext.current
    val sinAnimar = remember { android.provider.Settings.Global.getFloat(ctx.contentResolver, android.provider.Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }
    val pulso = if (animada && !sinAnimar) {
        val t = rememberInfiniteTransition(label = "luz")
        val llama by t.animateFloat(0f, 1f, infiniteRepeatable(tween(1700, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "llama")
        val halo by t.animateFloat(0f, 1f, infiniteRepeatable(tween(if (k == "vela" || k == "farol") 1300 else 3200, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "halo")
        val destello by t.animateFloat(0f, 1f, infiniteRepeatable(tween(2600, easing = LinearEasing)), label = "destello")
        val giro by t.animateFloat(0f, 360f, infiniteRepeatable(tween(40000, easing = LinearEasing)), label = "giro")
        Pulso(llama, halo, destello, giro)
    } else Pulso(0.5f, 1f, 0.5f, 0f)
    Canvas(modifier) {
        val e = size.minDimension / 64f
        withTransform({ translate((size.width - 64f * e) / 2, (size.height - 64f * e) / 2); scale(e, e, Offset.Zero) }) {
            when (k) {
                "vela" -> vela(pulso); "farol" -> farol(pulso); "estrella" -> estrella(pulso); "luna" -> luna(pulso); else -> sol(pulso)
            }
        }
    }
}

private fun DrawScope.halo(centro: Offset, r: Float, color: Color, a: Float, pulso: Pulso) {
    val s = 0.94f + 0.1f * pulso.halo
    drawCircle(Brush.radialGradient(0f to color.copy(alpha = a * (0.75f + 0.25f * pulso.halo)), 1f to color.copy(alpha = 0f), center = centro, radius = r * s), r * s, centro)
}

private fun DrawScope.llama(pivote: Offset, pulso: Pulso, cuerpo: () -> Unit) {
    val f = pulso.llama
    withTransform({ scale(1f - 0.05f * sin(f * PI).toFloat() + 0.03f * f, 1f + 0.06f * sin(f * PI).toFloat() - 0.03f * f, pivote); rotate((f - 0.5f) * 5f, pivote) }) { cuerpo() }
}

private fun DrawScope.vela(pulso: Pulso) {
    halo(Offset(32f, 18f), 26f, c(0xFFFFC66B), 0.55f, pulso)
    drawOval(Color.Black.copy(alpha = 0.16f), Offset(19f, 59.2f), Size(26f, 3.6f))
    drawRoundRect(Brush.horizontalGradient(0f to c(0xFFCDBF9F), 0.32f to c(0xFFFBF5E6), 0.62f to c(0xFFEFE5CE), 1f to c(0xFFBBAA86), startX = 22f, endX = 42f),
        Offset(22f, 30f), Size(20f, 30f), CornerRadius(2.2f))
    drawPath(Formas.gota1, c(0xFFF7EFDC)); drawPath(Formas.gota2, c(0xFFF3EAD4))
    drawOval(c(0xFFEDE2C7), Offset(22f, 27.7f), Size(20f, 5.2f))
    drawOval(c(0xFFFFF8E3), Offset(25.2f, 29f), Size(13.6f, 3f))
    drawPath(Formas.mecha, c(0xFF2A211B), style = Stroke(1.2f, cap = StrokeCap.Round))
    llama(Offset(32f, 26f), pulso) {
        drawPath(Formas.llama, Brush.radialGradient(0f to c(0xFFFFFBE8), 0.38f to c(0xFFFFDA74), 0.78f to c(0xFFFF9A2E), 1f to c(0xFFF06A12), center = Offset(32f, 20.2f), radius = 14f))
        drawPath(Formas.llamaIn, c(0xFFFFFDF3))
        drawOval(c(0xFF5E8DF0, 0.55f), Offset(30f, 23.3f), Size(4f, 2.6f))
    }
    drawRoundRect(Brush.verticalGradient(0f to c(0xFFFFF4D6, 0.5f), 1f to c(0xFFFFF4D6, 0f), startY = 32f, endY = 58f), Offset(25f, 32f), Size(2.2f, 26f), CornerRadius(1.1f))
}

private fun DrawScope.farol(pulso: Pulso) {
    halo(Offset(32f, 32f), 28f, c(0xFFFFC66B), 0.6f, pulso)
    drawOval(Color.Black.copy(alpha = 0.16f), Offset(17f, 59.7f), Size(30f, 3.6f))
    drawPath(Formas.asa, c(0xFF4A3B2E), style = Stroke(1.8f, cap = StrokeCap.Round))
    drawRoundRect(laton(28.6f, 35.4f), Offset(28.6f, 6.6f), Size(6.8f, 3.6f), CornerRadius(1f))
    drawPath(Formas.tapa, laton(21f, 43f))
    drawPath(Formas.vidrio, Brush.radialGradient(0f to c(0xFFFFF6D2, 0.95f), 0.5f to c(0xFFFFD782, 0.6f), 1f to c(0xFFF3E3C0, 0.22f), center = Offset(32f, 34.4f), radius = 18.5f))
    drawPath(Formas.vidrio, c(0xFF8A6A2E, 0.45f), style = Stroke(0.8f))
    llama(Offset(32f, 37.5f), pulso) {
        drawPath(Formas.llamaF, Brush.radialGradient(0f to c(0xFFFFFBE8), 0.4f to c(0xFFFFDA74), 0.8f to c(0xFFFF9A2E), 1f to c(0xFFF06A12), center = Offset(32f, 33.6f), radius = 8.4f))
        drawPath(Formas.llamaFIn, c(0xFFFFFDF3))
    }
    drawRoundRect(laton(27.5f, 36.5f), Offset(27.5f, 37.6f), Size(9f, 3.6f), CornerRadius(1f))
    drawPath(Formas.reflejo, Color.White.copy(alpha = 0.55f), style = Stroke(1.6f, cap = StrokeCap.Round))
    drawLine(laton(19f, 23f), Offset(20.6f, 17.5f), Offset(20.6f, 47f), 1.3f)
    drawLine(laton(41f, 45f), Offset(43.4f, 17.5f), Offset(43.4f, 47f), 1.3f)
    drawPath(Formas.base, laton(14.5f, 49.5f))
    drawLine(c(0xFFFFF1C8, 0.6f), Offset(17f, 51.6f), Offset(47f, 51.6f), 0.9f)
    drawCircle(laton(48.6f, 52.6f), 2f, Offset(50.6f, 51.5f))
    drawCircle(c(0xFF5E4314), 2f, Offset(50.6f, 51.5f), style = Stroke(0.5f))
}

private fun DrawScope.estrella(pulso: Pulso) {
    halo(Offset(32f, 33f), 30f, c(0xFFF3D27A), 0.55f, pulso)
    val a = Offset(6f, 7f); val b = Offset(58f, 59f)
    val tonos = listOf(
        Brush.linearGradient(listOf(c(0xFFFFF1BF), c(0xFFE9C463)), a, b),
        Brush.linearGradient(listOf(c(0xFFE2B54E), c(0xFFC39033)), a, b),
        Brush.linearGradient(listOf(c(0xFFA97A27), c(0xFF7C5719)), a, b),
    )
    Formas.caras.forEach { (cara, t) -> drawPath(cara, tonos[t]) }
    drawPath(Formas.contorno, c(0xFF6E4D16, 0.6f), style = Stroke(0.7f))
    val f = pulso.destello; val s = 0.5f + 0.65f * sin(f * PI).toFloat()
    withTransform({ rotate(45f * sin(f * PI).toFloat(), Offset(50f, 14.5f)); scale(s, s, Offset(50f, 14.5f)) }) {
        val al = 0.4f + 0.6f * sin(f * PI).toFloat()
        drawPath(Formas.destello, c(0xFFFFF8DF, al)); drawPath(Formas.destello, c(0xFFC99A3A, al), style = Stroke(0.6f))
    }
}

private fun DrawScope.luna(pulso: Pulso) {
    halo(Offset(30f, 32f), 31f, c(0xFFD9E6FF), 0.55f, pulso)
    clipPath(Formas.luna) {
        drawCircle(Brush.radialGradient(0f to c(0xFFFCFAF1), 0.55f to c(0xFFE2DDCD), 1f to c(0xFFACA591), center = Offset(23.2f, 25.4f), radius = 33f), 22f, Offset(32f, 32f))
        val crater = c(0xFFBDB6A2)
        listOf(Triple(18f, 31f, 3.2f), Triple(23f, 45f, 2.4f), Triple(14.5f, 40.5f, 1.5f), Triple(31f, 50f, 1.7f), Triple(21f, 21.5f, 1.8f), Triple(38f, 47f, 1.1f))
            .forEach { (x, y, r) -> drawCircle(crater, r, Offset(x, y)) }
        drawArc(c(0xFFFFFDF4, 0.8f), 20f, 140f, false, Offset(14.8f, 27.8f), Size(6.4f, 6.4f), style = Stroke(0.8f))
    }
}

private fun DrawScope.sol(pulso: Pulso) {
    halo(Offset(32f, 32f), 31f, c(0xFFFFD978), 0.75f, pulso)
    withTransform({ rotate(pulso.giro, Offset(32f, 32f)) }) {
        repeat(12) { i -> withTransform({ rotate(i * 30f, Offset(32f, 32f)) }) { drawPath(Formas.rayo, c(0xFFFFC24A, 0.55f)) } }
    }
    drawCircle(Brush.radialGradient(0f to c(0xFFFFFBE6), 0.35f to c(0xFFFFE07A), 0.78f to c(0xFFFFA126), 1f to c(0xFFDD6417), center = Offset(29.5f, 28.9f), radius = 19.2f), 15.5f, Offset(32f, 32f))
    drawOval(Color.White.copy(alpha = 0.35f), Offset(22.5f, 23f), Size(9f, 6f))
}

// ====================================================================== El botón y la fila de las cinco

private val ANCHO_OP = 58.dp
private val PASO_OP = 58.dp          // sin separación: cada opción ya trae su aire
private val FILA_ANCHO = 12.dp + ANCHO_OP * 5
private val FILA_ALTO = 96.dp        // dibujo de 52 dp y el nombre en dos líneas

/**
 * El botón de las luces. [enCima]: círculo translúcido de 48 dp con la luz y el total (columna de Cimas).
 * Si no, la línea del muro: la pila de las luces más dadas y una píldora con el nombre.
 * Todos ven qué luces recibió y cuántas ([verTotal]).
 */
@Composable
fun BotonLuces(luces: Map<String, Int>, miLuz: String?, onElegir: (String?) -> Unit, modifier: Modifier = Modifier, enCima: Boolean = true, verTotal: Boolean = true) {
    val ctx = LocalContext.current
    val haptico = LocalHapticFeedback.current
    val dens = LocalDensity.current
    var abierto by remember { mutableStateOf(false) }
    var sobre by remember { mutableIntStateOf(-1) }
    val total = Luces.IDS.sumOf { luces[it] ?: 0 }
    val mas = Luces.mas(luces)
    val ultima = Luces.ultima(ctx)
    val muestra = miLuz ?: if (enCima) mas.firstOrNull() ?: ultima else ultima
    val actual by rememberUpdatedState(miLuz)
    val elegir: (String) -> Unit = { k ->
        abierto = false; sobre = -1
        haptico.performHapticFeedback(HapticFeedbackType.LongPress)
        val nuevo = if (k == actual) null else k
        if (nuevo != null) Luces.recordar(ctx, nuevo)
        onElegir(nuevo)
    }
    val tocar = { elegir(actual ?: Luces.ultima(ctx)) }
    val etiqueta = if (miLuz != null) ctx.getString(R.string.lz_quitar, Luces.nombre(ctx, miLuz)) else ctx.getString(R.string.lz_dar, Luces.nombre(ctx, ultima))
    val pop by animateFloatAsState(if (miLuz != null) 1f else 0.98f, tween(420, easing = FastOutSlowInEasing), label = "pop")

    // Centro de cada opción respecto al borde izquierdo del botón (la fila va a la izquierda en Cimas y arriba en el muro)
    fun indice(x: Float, y: Float): Int = with(dens) {
        val centros = Luces.IDS.indices.map { i ->
            if (enCima) -(8.dp + 6.dp + PASO_OP * (4 - i) + ANCHO_OP / 2).toPx() else (6.dp + PASO_OP * i + ANCHO_OP / 2).toPx()
        }
        val cerca = if (enCima) abs(y - 24.dp.toPx()) < 80.dp.toPx() else y < 10.dp.toPx() && y > -(FILA_ALTO + 90.dp).toPx()
        if (!cerca) return -1
        val i = centros.indices.minByOrNull { abs(centros[it] - x) } ?: return -1
        if (abs(centros[i] - x) <= (PASO_OP / 2).toPx()) i else -1
    }
    val gesto = Modifier.pointerInput(enCima) {
        awaitEachGesture {
            awaitFirstDown(requireUnconsumed = false)
            var fin = 0   // 0 = se mantuvo, 1 = se soltó, 2 = se canceló (desplazamiento)
            withTimeoutOrNull(viewConfiguration.longPressTimeoutMillis) { fin = if (waitForUpOrCancellation() != null) 1 else 2 }
            when (fin) {
                1 -> tocar()
                0 -> {
                    abierto = true; sobre = -1
                    haptico.performHapticFeedback(HapticFeedbackType.LongPress)
                    while (true) {
                        val ev = awaitPointerEvent()
                        val ch = ev.changes.firstOrNull() ?: break
                        val i = indice(ch.position.x, ch.position.y)
                        if (i != sobre) { sobre = i; if (i >= 0) haptico.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
                        ch.consume()
                        if (!ch.pressed) break
                    }
                    if (sobre >= 0) elegir(Luces.IDS[sobre])
                }
            }
        }
    }
    val sem = Modifier.semantics {
        contentDescription = etiqueta + if (verTotal) ", " + ctx.getString(R.string.lz_total, total) else ""
        role = Role.Button
        onClick { tocar(); true }
        customActions = Luces.IDS.map { k -> CustomAccessibilityAction(Luces.nombre(ctx, k)) { elegir(k); true } }
    }

    Box(modifier) {
        if (enCima) {
            Column(Modifier.width(56.dp).then(gesto).then(sem), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    Modifier.size(48.dp).graphicsLayer { scaleX = pop; scaleY = pop }.clip(CircleShape)
                        .background(if (miLuz != null) Color(0x4DF6EAD3) else Color(0x29FBF8F3))
                        .then(if (miLuz != null) Modifier.border(1.5.dp, Color(0xCCE9CB7E), CircleShape) else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    Luz(muestra, Modifier.size(34.dp).graphicsLayer { alpha = if (miLuz == null && total == 0) 0.72f else 1f }, animada = miLuz != null)
                }
                Text(if (verTotal && total > 0) total.toString() else "", color = Color.White, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Medium)
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (total > 0) Row(verticalAlignment = Alignment.CenterVertically) {
                    mas.forEachIndexed { i, k -> Luz(k, Modifier.size(22.dp).offset(x = (-6 * i).dp)) }
                    if (verTotal) Text(total.toString(), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.offset(x = (8 - 6 * mas.size).dp))
                }
                Box(
                    Modifier.heightIn(min = 40.dp).clip(RoundedCornerShape(50))
                        .background(if (miLuz != null) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh)
                        .then(gesto).then(sem).padding(start = 8.dp, end = 14.dp, top = 6.dp, bottom = 6.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Luz(muestra, Modifier.size(26.dp).graphicsLayer { scaleX = pop; scaleY = pop }, animada = miLuz != null)
                        Spacer(Modifier.width(6.dp))
                        Text(Luces.nombre(ctx, muestra), style = MaterialTheme.typography.labelLarge,
                            fontWeight = if (miLuz != null) FontWeight.SemiBold else FontWeight.Medium)
                    }
                }
            }
        }
        if (abierto) {
            val desplazamiento = with(dens) {
                if (enCima) IntOffset(-(FILA_ANCHO + 8.dp).roundToPx(), (24.dp - FILA_ALTO / 2).roundToPx())
                else IntOffset(0, -(FILA_ALTO + 10.dp).roundToPx())
            }
            Popup(alignment = Alignment.TopStart, offset = desplazamiento, onDismissRequest = { abierto = false; sobre = -1 }, properties = PopupProperties(focusable = true)) {
                FilaLuces(miLuz, sobre, oscura = enCima, onElegir = elegir)
            }
        }
    }
}

@Composable
private fun FilaLuces(miLuz: String?, sobre: Int, oscura: Boolean, onElegir: (String) -> Unit) {
    val ctx = LocalContext.current
    val fondo = if (oscura) Color(0xE60A0E18) else MaterialTheme.colorScheme.surfaceContainerLowest
    val borde = if (oscura) Color.White.copy(alpha = 0.16f) else MaterialTheme.colorScheme.outlineVariant
    Row(
        Modifier.clip(RoundedCornerShape(28.dp)).background(fondo).border(1.dp, borde, RoundedCornerShape(28.dp)).padding(6.dp),
    ) {
        Luces.IDS.forEachIndexed { i, k ->
            val arriba by animateFloatAsState(if (i == sobre) 1f else 0f, tween(200, easing = FastOutSlowInEasing), label = "sobre")
            val nombre = Luces.nombre(ctx, k)
            val marcada = k == miLuz || i == sobre
            Column(
                Modifier.width(ANCHO_OP).clip(RoundedCornerShape(22.dp))
                    .background(if (k == miLuz) (if (oscura) Color.White.copy(alpha = 0.14f) else MaterialTheme.colorScheme.secondaryContainer) else Color.Transparent)
                    .clickable { onElegir(k) }.semantics { contentDescription = nombre }.padding(top = 4.dp, bottom = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) {
                    Luz(k, Modifier.size(44.dp).graphicsLayer {
                        translationY = -10.dp.toPx() * arriba; val s = 1f + 0.35f * arriba; scaleX = s; scaleY = s
                    }, animada = true)
                }
                // El nombre de cada luz, siempre visible bajo su dibujo
                Text(nombre, fontSize = 10.5.sp, lineHeight = 12.sp, maxLines = 2, textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    fontWeight = if (marcada) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (oscura) Color.White.copy(alpha = if (marcada) 1f else 0.86f) else if (marcada) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
    // El nombre de la luz bajo el dedo, encima de la fila
    if (sobre >= 0) {
        val dens = LocalDensity.current
        Popup(alignment = Alignment.TopStart, offset = with(dens) { IntOffset((6.dp + PASO_OP * sobre - 16.dp).roundToPx(), (-30).dp.roundToPx()) }) {
            Text(
                Luces.nombre(ctx, Luces.IDS[sobre]),
                color = if (oscura) Color(0xFF1D2427) else MaterialTheme.colorScheme.inverseOnSurface,
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(if (oscura) Color(0xFFF4F1EA) else MaterialTheme.colorScheme.inverseSurface)
                    .padding(horizontal = 10.dp, vertical = 3.dp),
            )
        }
    }
}
