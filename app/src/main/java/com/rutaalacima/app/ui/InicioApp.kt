package com.rutaalacima.app.ui

import android.content.Context

/**
 * Dónde se abre la app en el teléfono.
 *  · "auto" (por defecto): en Comunidad si la persona tiene cuenta y ya escribió su cumbre; si no, en Mi ruta,
 *    que le enseña el método (sin cuenta o recién llegada, Comunidad estaría vacía o pediría registrarse).
 *  · "comunidad", "ruta" u "hoy": lo que la persona eligió en Ajustes › Abrir la app en.
 * En Comunidad, la franja «Tu paso de hoy» va arriba hasta que se da el paso del día.
 */
object InicioApp {
    private const val CLAVE = "abrir_en"
    val OPCIONES = listOf("auto", "comunidad", "ruta", "hoy")

    private fun prefs(c: Context) = c.getSharedPreferences("rutacima_inicio", Context.MODE_PRIVATE)
    fun elegido(c: Context): String = prefs(c).getString(CLAVE, "auto").takeIf { it in OPCIONES } ?: "auto"
    fun elegir(c: Context, v: String) = prefs(c).edit().putString(CLAVE, v).apply()

    /** La ruta de inicio. [conCuenta]: hay sesión en el servidor; [conCumbre]: ya escribió su cumbre. */
    fun ruta(c: Context, conCuenta: Boolean, conCumbre: Boolean): String = when (elegido(c)) {
        "comunidad" -> Rutas.COMUNIDAD
        "ruta" -> Rutas.RUTA
        "hoy" -> Rutas.HOY
        else -> if (conCuenta && conCumbre) Rutas.COMUNIDAD else Rutas.RUTA
    }
}
