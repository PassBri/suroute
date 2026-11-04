package com.rutaalacima.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.graphics.luminance
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.sin

/**
 * Un mapa como los del deporte de orientación (igual que la web, web/js/55-mapa.js): papel, campo abierto en amarillo,
 * vegetación en verde, un lago azul, curvas de nivel en café (cada quinta más gruesa) y el recorrido en magenta:
 * la salida (triángulo), los controles y la meta (doble círculo) en la cumbre. Cubre su caja como una foto.
 */
private object Mapa {
    const val W = 1200f; const val H = 800f; private const val PASO = 10
    private val CERROS = listOf(floatArrayOf(820f, 330f, 1f, 250f), floatArrayOf(300f, 560f, .62f, 170f), floatArrayOf(500f, 170f, .42f, 130f),
        floatArrayOf(1060f, 660f, .38f, 140f), floatArrayOf(110f, 160f, .3f, 120f))
    val RUTA = listOf(170f to 705f, 345f to 585f, 470f to 430f, 610f to 250f, 700f to 420f, 820f to 330f)

    private fun altura(x: Float, y: Float): Float {
        var h = 0.0
        for (c in CERROS) h += c[2] * exp(-(((x - c[0]) * (x - c[0]) + (y - c[1]) * (y - c[1])) / (2.0 * c[3] * c[3])))
        h += .045 * sin(x * .012 + 1.3) * cos(y * .015 + .4) + .03 * sin((x + y) * .02 + 2.1) + .02 * cos(x * .031 - y * .011)
        return h.toFloat()
    }

    /** Marching squares: un Path con las curvas normales y otro con las índice (cada quinta). */
    val curvas: Pair<Path, Path> by lazy {
        val cols = (W / PASO).toInt() + 1; val filas = (H / PASO).toInt() + 1
        val g = FloatArray(cols * filas) { val i = it % cols; val j = it / cols; altura(i * PASO.toFloat(), j * PASO.toFloat()) }
        val normal = Path(); val indice = Path()
        for (k in 1..22) {
            val lv = .03f + k * .045f; val p = if ((k + 1) % 5 == 0) indice else normal
            for (j in 0 until filas - 1) for (i in 0 until cols - 1) {
                val a = g[j * cols + i]; val b = g[j * cols + i + 1]; val c = g[(j + 1) * cols + i + 1]; val d = g[(j + 1) * cols + i]
                val caso = (if (a > lv) 8 else 0) or (if (b > lv) 4 else 0) or (if (c > lv) 2 else 0) or (if (d > lv) 1 else 0)
                if (caso == 0 || caso == 15) continue
                val x = i * PASO.toFloat(); val y = j * PASO.toFloat()
                fun t(p1: Float, q1: Float) = (lv - p1) / (q1 - p1)
                val arr = Offset(x + PASO * t(a, b), y); val der = Offset(x + PASO, y + PASO * t(b, c))
                val abj = Offset(x + PASO * t(d, c), y + PASO); val izq = Offset(x, y + PASO * t(a, d))
                val tramos = when (caso) {
                    1, 14 -> listOf(izq to abj); 2, 13 -> listOf(abj to der); 3, 12 -> listOf(izq to der); 4, 11 -> listOf(arr to der)
                    5 -> listOf(izq to arr, abj to der); 6, 9 -> listOf(arr to abj); 7, 8 -> listOf(izq to arr); 10 -> listOf(izq to abj, arr to der)
                    else -> emptyList()
                }
                for ((u, v) in tramos) { p.moveTo(u.x, u.y); p.lineTo(v.x, v.y) }
            }
        }
        normal to indice
    }

    /** Una mancha orgánica alrededor de (cx, cy). */
    fun mancha(cx: Float, cy: Float, r: Float, f: Float): Path {
        val pts = (0 until 28).map { k -> val a = k / 28.0 * PI * 2; val rr = r * (1 + .2 * sin(3 * a + f) + .1 * sin(5 * a + f * 2.3))
            Offset((cx + rr * cos(a)).toFloat(), (cy + rr * .8 * sin(a)).toFloat()) }
        fun m(p: Offset, q: Offset) = Offset((p.x + q.x) / 2, (p.y + q.y) / 2)
        return Path().apply {
            val ini = m(pts[27], pts[0]); moveTo(ini.x, ini.y)
            pts.forEachIndexed { k, p -> val q = m(p, pts[(k + 1) % 28]); quadraticTo(p.x, p.y, q.x, q.y) }
            close()
        }
    }
    val abierto by lazy { listOf(mancha(360f, 380f, 120f, .7f), mancha(960f, 180f, 95f, 2.1f), mancha(150f, 520f, 70f, 4.2f)) }
    val veg by lazy { listOf(mancha(640f, 640f, 110f, 1.4f), mancha(1050f, 420f, 80f, 3.3f), mancha(260f, 120f, 85f, 5.1f)) }
    val agua by lazy { mancha(560f, 740f, 70f, 2.7f) }
}

@Composable
fun MapaOrientacion(modifier: Modifier = Modifier, conRuta: Boolean = true) {
    val oscuro = MaterialTheme.colorScheme.background.luminance() < .5f
    val curvas = remember { Mapa.curvas }
    Canvas(modifier) {
        val e = max(size.width / Mapa.W, size.height / Mapa.H)
        translate((size.width - Mapa.W * e) / 2, (size.height - Mapa.H * e) / 2) {
            scale(e, e, pivot = Offset.Zero) {
                drawRect(if (oscuro) Color(0xFF14191C) else Color(0xFFFBF8EF), size = androidx.compose.ui.geometry.Size(Mapa.W, Mapa.H))
                Mapa.abierto.forEach { drawPath(it, if (oscuro) Color(0x804A3F22) else Color(0xBFF6DE9B)) }
                Mapa.veg.forEach { drawPath(it, if (oscuro) Color(0x9923402A) else Color(0xD9C9E3B4)) }
                drawPath(Mapa.agua, if (oscuro) Color(0xFF173A50) else Color(0xFFA9D7EF))
                drawPath(Mapa.agua, if (oscuro) Color(0xFF4F9DCC) else Color(0xFF2D7FB8), style = Stroke(2.4f))
                val cafe = if (oscuro) Color(0x80B9773F) else Color(0xBFC0742F)
                drawPath(curvas.first, cafe, style = Stroke(1.3f, cap = StrokeCap.Round))
                drawPath(curvas.second, cafe.copy(alpha = if (oscuro) .55f else .85f), style = Stroke(2.6f, cap = StrokeCap.Round))
                if (conRuta) {
                    val mag = if (oscuro) Color(0xBFE07AB8) else Color(0xD9B5307E); val st = Stroke(3.4f); val r = 22f; val ruta = Mapa.RUTA
                    for (i in 0 until ruta.size - 1) {
                        val (x1, y1) = ruta[i]; val (x2, y2) = ruta[i + 1]; val l = hypot(x2 - x1, y2 - y1); val ux = (x2 - x1) / l; val uy = (y2 - y1) / l
                        val r1 = if (i == 0) 26f else r + 4; val r2 = if (i + 1 == ruta.size - 1) r + 12 else r + 4
                        drawLine(mag, Offset(x1 + ux * r1, y1 + uy * r1), Offset(x2 - ux * r2, y2 - uy * r2), 3.4f)
                    }
                    val (sx, sy) = ruta[0]
                    drawPath(Path().apply { moveTo(sx, sy - 26); lineTo(sx + 22.5f, sy + 13); lineTo(sx - 22.5f, sy + 13); close() }, mag, style = st)
                    ruta.subList(1, ruta.size - 1).forEach { (x, y) -> drawCircle(mag, r, Offset(x, y), style = st) }
                    val (mx, my) = ruta.last()
                    drawCircle(mag, r, Offset(mx, my), style = st); drawCircle(mag, r + 8, Offset(mx, my), style = st)
                }
            }
        }
    }
}
