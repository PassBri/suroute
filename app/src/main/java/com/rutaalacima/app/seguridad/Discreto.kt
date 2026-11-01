package com.rutaalacima.app.seguridad

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.mutableStateOf

/**
 * El ojo para toda la app (como el «Visible» de la banca): con él activo, las cifras de dinero se ven
 * como ••••• en todas partes (Hoy, Mi ruta y el Ascenso financiero). Se recuerda en este teléfono,
 * igual que la web lo recuerda en cada navegador.
 */
object Discreto {
    private val estado = mutableStateOf(false)
    private var prefs: SharedPreferences? = null

    fun iniciar(c: Context) {
        prefs = c.getSharedPreferences("discreto", Context.MODE_PRIVATE)
        estado.value = prefs?.getBoolean("activo", false) ?: false
    }

    var activo: Boolean
        get() = estado.value
        set(v) { estado.value = v; prefs?.edit()?.putBoolean("activo", v)?.apply() }
}
