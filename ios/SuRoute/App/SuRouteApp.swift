import SwiftUI

@main
struct SuRouteApp: App {
    @State private var almacen = Almacen.shared
    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(almacen)
                .tint(Tema.burdeos)
                .task { await almacen.arrancar() }
        }
    }
}

/// La entrada: sin sesión, la pantalla para entrar o crear la cuenta; con sesión, las pestañas.
struct Raiz: View {
    @Environment(Almacen.self) private var a
    @Environment(\.scenePhase) private var fase
    var body: some View {
        Group {
            if a.uid == nil { Entrar() } else { Pestanas() }
        }
        .onChange(of: fase) { _, f in if f == .active { Task { await a.traerDeLaNube() } } }
    }
}

/// Las pestañas al estilo iPhone: ícono con su nombre. Publicar es una acción (botón de redactar en
/// Comunidad, como en Mail), no una pestaña; el perfil va en el botón de arriba a la derecha.
struct Pestanas: View {
    enum P: String { case hoy, ruta, brujula, comunidad, finanzas }
    @State private var sel: P = P(rawValue: (Config.pestanaInicial ?? "").replacingOccurrences(of: "81", with: "").replacingOccurrences(of: "publicar", with: "comunidad")) ?? .hoy
    var body: some View {
        TabView(selection: $sel) {
            HoyVista().tabItem { Label(L("tab_hoy"), systemImage: "sun.horizon") }.tag(P.hoy)
            MiRutaVista().tabItem { Label(L("tab_ruta"), systemImage: "mountain.2") }.tag(P.ruta)
            BrujulaVista(abrir81: Config.pestanaInicial == "brujula81").tabItem { Label(L("ios_tab_brujula"), systemImage: "safari") }.tag(P.brujula)
            ComunidadVista(abrirPublicar: Config.pestanaInicial == "publicar").tabItem { Label(L("tab_comunidad"), systemImage: "flame") }.tag(P.comunidad)
            FinanzasVista().tabItem { Label(L("ios_tab_finanzas"), systemImage: "dollarsign.circle") }.tag(P.finanzas)
        }
        .sheet(isPresented: .constant(Config.pestanaInicial == "cuenta")) { CuentaVista() }
    }
}

/// El botón del perfil (arriba a la derecha en cada pestaña): abre tu cuenta.
struct BotonPerfil: View {
    @Environment(Almacen.self) private var a
    @State private var abierto = false
    var body: some View {
        Button { abierto = true } label: { Avatar(url: nil, nombre: Perfil(a).nombre.isEmpty ? "?" : Perfil(a).nombre, tam: 32) }
            .accessibilityLabel(L("tab_perfil"))
            .sheet(isPresented: $abierto) { CuentaVista() }
    }
}
