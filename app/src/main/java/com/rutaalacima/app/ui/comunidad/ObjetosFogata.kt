package com.rutaalacima.app.ui.comunidad

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.vector.PathParser
import com.rutaalacima.app.R

/**
 * Lo que se le da a una fogata en vivo (en vez de las luces de las publicaciones): leña, fósforo, piedra, chispa,
 * taza de café y manta. Pintados en un lienzo de 64 unidades, igual que la web (web/js/52-fogata.js).
 */
object ObjetosFogata {
    val IDS = listOf("lena", "fosforo", "piedra", "chispa", "cafe", "manta")
    /** Cuánto aviva la hoguera cada objeto. */
    fun calor(k: String): Float = when (k) { "lena" -> 3f; "fosforo", "chispa" -> 2f; else -> 1f }
    fun nombre(k: String): Int = when (k) {
        "lena" -> R.string.fo_lena; "fosforo" -> R.string.fo_fosforo; "piedra" -> R.string.fo_piedra
        "chispa" -> R.string.fo_chispa; "cafe" -> R.string.fo_cafe; else -> R.string.fo_manta
    }
}

private fun p(d: String): Path = PathParser().parsePathString(d).toPath()

private val TRONCO = p("M17 24H43A9 9 0 0 1 52 33V35A9 9 0 0 1 43 44H17A9 9 0 0 1 8 35V33A9 9 0 0 1 17 24Z")
private val CORTEZA = p("M12 28c8 1 16-1 24 0s10 2 14 1M11 36c9-1 15 1 22 0s11-1 17 0M13 41c7 0 13-1 20 0M26 24c-2 3-2 6 0 8")
private val RAMITAS = p("M6 30l-3-3M7 38l-4 2")
private val LLAMA = p("M32 2c5 7 8 11 6.5 16.5C37 22 34.8 23 32 23s-5-1-6.5-4.5C24 13 27 8 32 2z")
private val LLAMA_IN = p("M32 10c2.4 3.6 3.6 6 2.8 8.6-.6 1.8-1.6 2.4-2.8 2.4s-2.2-.6-2.8-2.4C28.4 16 29.6 13.6 32 10z")
private val PIEDRA_A = p("M28 40c-1-12 7-22 18-22 9 0 14 8 13 17-1 10-9 17-19 17-7 0-11-4-12-12z")
private val PIEDRA_B = p("M10 46c-2-9 4-17 13-19 7-1 12 3 14 9 2 7-1 14-10 16-8 2-15 0-17-6z")
private val ESTRELLA = p("M32 8l3.2 19.8L55 32l-19.8 3.2L32 56l-3.2-20.8L8 32l20.8-4.2z")
private val ESTRELLA_IN = p("M32 18l1.8 12.2L46 32l-12.2 1.8L32 46l-1.8-12.2L18 32l12.2-1.8z")
private val TAZA = p("M14 24h32v24a8 8 0 0 1-8 8H22a8 8 0 0 1-8-8z")
private val ASA = p("M46 30h4a7 7 0 0 1 0 14h-4")
private val VAPOR = p("M24 18c-3-4 3-6 0-10M32 18c-3-4 3-6 0-10M40 18c-3-4 3-6 0-10")
private val BORDE_TAZA = p("M14 51c1 3 4 5 8 5h16c4 0 7-2 8-5")
private val MANTA = p("M13 17h38a5 5 0 0 1 5 5v24a5 5 0 0 1-5 5H13a5 5 0 0 1-5-5V22a5 5 0 0 1 5-5z")

private fun u(x: Float, y: Float) = Offset(x, y)

private fun DrawScope.lena() = rotate(-18f, u(32f, 34f)) {
    drawPath(TRONCO, Brush.verticalGradient(listOf(Color(0xFF8A5A34), Color(0xFF6B4226), Color(0xFF3E2614)), 24f, 44f))
    drawPath(CORTEZA, Color(0xFF2E1B0E).copy(alpha = 0.55f), style = Stroke(1.1f, cap = StrokeCap.Round))
    val tapa = Rect(45.5f, 24f, 58.5f, 44f)
    drawOval(Brush.radialGradient(listOf(Color(0xFFF2D3A0), Color(0xFFD9A86A), Color(0xFF9A6A3A)), u(51.4f, 32.4f), 9f), tapa.topLeft, tapa.size)
    drawOval(Color(0xFF5A3A1E), tapa.topLeft, tapa.size, style = Stroke(1f))
    listOf(4.2f to 6.6f, 2.2f to 3.4f).forEach { (rx, ry) -> drawOval(Color(0xFFB07D46), u(52f - rx, 34f - ry), Size(rx * 2, ry * 2), style = Stroke(0.9f)) }
    drawCircle(Color(0xFF8A5A30), 0.9f, u(52f, 34f))
    drawPath(RAMITAS, Color(0xFF5A3A1E), style = Stroke(2f, cap = StrokeCap.Round))
}

private fun DrawScope.fosforo() = rotate(35f, u(32f, 34f)) {
    drawRoundRect(Brush.horizontalGradient(listOf(Color(0xFFE9C88E), Color(0xFFD6AE6E), Color(0xFFB98A4C)), 29.6f, 34.4f), u(29.6f, 22f), Size(4.8f, 38f), CornerRadius(1.6f))
    drawOval(Brush.radialGradient(listOf(Color(0xFFE0573A), Color(0xFFA3261A), Color(0xFF5E120C)), u(30.2f, 19.5f), 6f), u(27.4f, 16f), Size(9.2f, 12f))
    drawPath(LLAMA, Brush.radialGradient(0f to Color(0xFFFFF6C8), 0.35f to Color(0xFFFFC94A), 0.75f to Color(0xFFF07A1C), 1f to Color(0x00C2410C), center = u(32f, 18f), radius = 16f))
    drawPath(LLAMA_IN, Color(0xFFFFF8DC).copy(alpha = 0.9f))
}

private fun DrawScope.piedra() {
    drawOval(Color.Black.copy(alpha = 0.22f), u(8f, 50f), Size(48f, 8f))
    drawPath(PIEDRA_B, Brush.radialGradient(listOf(Color(0xFFB3AEA4), Color(0xFF77726A), Color(0xFF3D3A35)), u(18f, 33f), 22f))
    drawPath(PIEDRA_A, Brush.radialGradient(listOf(Color(0xFFC9C6BF), Color(0xFF8E8A82), Color(0xFF4E4B46)), u(39f, 27f), 28f))
    drawPath(p("M40 24c4-1 8 0 10 3"), Color.White.copy(alpha = 0.35f), style = Stroke(1.6f, cap = StrokeCap.Round))
}

private fun DrawScope.chispa() {
    drawCircle(Brush.radialGradient(0f to Color(0xFFFFFBE6), 0.3f to Color(0xFFFFD25C), 0.7f to Color(0x8CF28A1E), 1f to Color(0x00E25B0E), center = u(32f, 32f), radius = 22f), 22f, u(32f, 32f))
    drawPath(ESTRELLA, Color(0xFFFFE7A3))
    drawPath(ESTRELLA_IN, Color(0xFFFFFDF2))
    listOf(Triple(50f, 14f, 1.8f), Triple(14f, 18f, 1.3f), Triple(52f, 50f, 1.2f), Triple(12f, 48f, 1.6f), Triple(44f, 8f, 1f))
        .forEach { (x, y, r) -> drawCircle(Color(0xFFFFB53C), r, u(x, y)) }
}

private fun DrawScope.cafe() {
    drawPath(VAPOR, Color.White.copy(alpha = 0.7f), style = Stroke(2f, cap = StrokeCap.Round))
    drawPath(ASA, Color(0xFFC7D0D7), style = Stroke(4f))
    drawPath(TAZA, Brush.horizontalGradient(listOf(Color(0xFFE9EEF2), Color.White, Color(0xFFB9C3CB)), 14f, 46f))
    drawOval(Color(0xFF1F4E79), u(14f, 20f), Size(32f, 8f))
    drawOval(Brush.radialGradient(listOf(Color(0xFF7A4A26), Color(0xFF2E180A)), u(28f, 23.5f), 14f), u(16f, 21.6f), Size(28f, 6f))
    drawPath(BORDE_TAZA, Color(0xFF1F4E79), style = Stroke(2.2f))
    drawCircle(Color(0xFFC2DAF0).copy(alpha = 0.8f), 2f, u(22f, 38f))
}

private fun DrawScope.manta() {
    drawPath(MANTA, Brush.verticalGradient(listOf(Color(0xFFA33A2A), Color(0xFF6E2116)), 17f, 51f))
    clipPath(MANTA) {
        var y = 21f; while (y < 52f) { drawRect(Color(0xFFE9C88E).copy(alpha = 0.45f), u(8f, y), Size(48f, 2.4f)); y += 12f }
        var x = 12f; while (x < 57f) { drawRect(Color(0xFF2B1410).copy(alpha = 0.35f), u(x, 17f), Size(2.4f, 34f)); x += 12f }
    }
    listOf(28f, 36f).forEach { drawLine(Color(0xFF3A120C).copy(alpha = 0.55f), u(8f, it), u(56f, it), 1.4f) }
    var x = 10f; while (x <= 50f) { drawLine(Color(0xFFE9C88E).copy(alpha = 0.85f), u(x, 51f), u(x, 55f), 1.4f, cap = StrokeCap.Round); x += 5f }
}

/** Un objeto de la fogata pintado. */
@Composable
fun ObjetoFogata(k: String, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val s = size.minDimension / 64f
        scale(s, s, pivot = Offset.Zero) {
            when (k) { "fosforo" -> fosforo(); "piedra" -> piedra(); "chispa" -> chispa(); "cafe" -> cafe(); "manta" -> manta(); else -> lena() }
        }
    }
}
