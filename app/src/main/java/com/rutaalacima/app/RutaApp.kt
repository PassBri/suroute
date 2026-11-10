package com.rutaalacima.app

import android.app.Application

class RutaApp : Application() {
    lateinit var container: AppContainer
        private set

    /**
     * El idioma elegido en la app también para lo que se arma fuera de las pantallas (propuestas de la Brújula,
     * avisos, coach…). Antes de Android 13 el idioma propio de la app solo llega a las pantallas: el contexto de la
     * aplicación seguía en el idioma del sistema y, por ejemplo, la Brújula proponía campamentos en inglés.
     */
    private var recursosIdioma: Pair<String, android.content.res.Resources>? = null
    override fun getResources(): android.content.res.Resources {
        val base = super.getResources()
        if (android.os.Build.VERSION.SDK_INT >= 33) return base
        val etiquetas = runCatching { androidx.appcompat.app.AppCompatDelegate.getApplicationLocales().toLanguageTags() }.getOrDefault("")
        if (etiquetas.isBlank()) return base
        recursosIdioma?.let { if (it.first == etiquetas) return it.second }
        val cfg = android.content.res.Configuration(base.configuration).apply { setLocales(android.os.LocaleList.forLanguageTags(etiquetas)) }
        return createConfigurationContext(cfg).resources.also { recursosIdioma = etiquetas to it }
    }

    override fun onCreate() {
        super.onCreate()
        // Reporte de errores anónimo: captura los cierres inesperados y envía los pendientes
        com.rutaalacima.app.diagnostico.Errores.instalar(this)
        container = AppContainer(this)
        com.rutaalacima.app.seguridad.Discreto.iniciar(this)
        com.rutaalacima.app.diagnostico.Errores.enviarPendientes(this, container.supabase)
        // Recordatorio diario del camino hacia los 120 años
        com.rutaalacima.app.notificaciones.Recordatorios.crearCanal(this)
        com.rutaalacima.app.notificaciones.Recordatorios.programar(this)
        com.rutaalacima.app.notificaciones.AvisosTramites.crearCanal(this)
        com.rutaalacima.app.notificaciones.AvisosTramites.programar(this)
        com.rutaalacima.app.notificaciones.AvisosTramites.revisar(this)
        // Avisos de mensajes, solicitudes y coach de vida (cada 15 minutos, si hay cuenta)
        com.rutaalacima.app.notificaciones.AvisosMensajes.programar(this)
    }
}
