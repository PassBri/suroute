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

/// Las pestañas al estilo iPhone: ícono con su nombre. (Etapa 2: Comunidad y Publicar; etapa 3: Finanzas.)
struct Pestanas: View {
    enum P: String { case hoy, ruta, brujula, cuenta }
    @State private var sel: P = P(rawValue: (Config.pestanaInicial ?? "").replacingOccurrences(of: "81", with: "")) ?? .hoy
    var body: some View {
        TabView(selection: $sel) {
            HoyVista().tabItem { Label(L("tab_hoy"), systemImage: "sun.horizon") }.tag(P.hoy)
            MiRutaVista().tabItem { Label(L("tab_ruta"), systemImage: "mountain.2") }.tag(P.ruta)
            BrujulaVista(abrir81: Config.pestanaInicial == "brujula81").tabItem { Label(L("ios_tab_brujula"), systemImage: "safari") }.tag(P.brujula)
            CuentaVista().tabItem { Label(L("tab_perfil"), systemImage: "person.crop.circle") }.tag(P.cuenta)
        }
    }
}
