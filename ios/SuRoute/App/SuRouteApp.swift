import SwiftUI
import WidgetKit

@main
struct SuRouteApp: App {
    @State private var almacen = Almacen.shared
    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(almacen)
                .tint(Tema.burdeos)
                .task { await almacen.arrancar() }
                .onChange(of: almacen.version) { _, _ in PuenteWidget.actualizar() }
        }
    }
}

/// La entrada: sin sesión, la pantalla para entrar o crear la cuenta; con sesión, las pestañas.
struct Raiz: View {
    @Environment(Almacen.self) private var a
    @Environment(\.scenePhase) private var fase
    @State private var vinculo: String?
    struct AnioCodigo: Identifiable { let id: String }
    @State private var carta = CartaBienvenidaVista.leida || (Config.demo && Config.pestanaInicial != "carta")
    /// Cuenta nueva: sin nombre ni primer uso hecho (en Android o la web ya lo habría marcado).
    private var faltaPrimerUso: Bool {
        if Config.pestanaInicial == "inicio" { return true }
        guard a.sincronizado, !Config.demo else { return false }
        let p = Perfil(a)
        return p.d["onboardingCompleto"]?.bool != true && p.nombre.isEmpty && p.cumbre.isEmpty
    }
    var body: some View {
        Group {
            if !carta { CartaBienvenidaVista { withAnimation { carta = true } } }
            else if a.uid == nil { Entrar() }
            else if faltaPrimerUso { OnboardingVista() }
            else { Pestanas() }
        }
        .task(id: a.sincronizado) { if a.sincronizado { await Recordatorios.programar() } }
        .onChange(of: fase) { _, f in if f == .active { Task { await a.traerDeLaNube() } } }
        .onOpenURL { u in if u.scheme == "rutacima", let c = Vinculo.codigo(u.absoluteString) { vinculo = c } }
        .sheet(item: Binding(get: { vinculo.map(AnioCodigo.init) }, set: { vinculo = $0?.id })) { x in NavigationStack { WebVista(codigoEntrante: x.id) } }
    }
}

/// Las pestañas al estilo iPhone: ícono con su nombre. Publicar es una acción (botón de redactar en
/// Comunidad, como en Mail), no una pestaña; el perfil va en el botón de arriba a la derecha.
struct Pestanas: View {
    enum P: String { case hoy, ruta, brujula, comunidad, finanzas }
    @State private var sel: P = P(rawValue: (Config.pestanaInicial ?? Pestanas.abrirEn).replacingOccurrences(of: "81", with: "").replacingOccurrences(of: "publicar", with: "comunidad")) ?? .hoy
    /// Dónde se abre la app (Ajustes). Automático, igual que Android: Comunidad con cuenta y cumbre escrita; si no, Mi ruta.
    @MainActor static var abrirEn: String {
        let e = UserDefaults.standard.string(forKey: "abrir_en") ?? "auto"
        if e != "auto" { return e }
        return Perfil(Almacen.shared).cumbre.isEmpty ? "ruta" : "comunidad"
    }
    var body: some View {
        TabView(selection: $sel) {
            HoyVista().tabItem { Label(L("tab_hoy"), systemImage: "sun.horizon") }.tag(P.hoy)
            MiRutaVista().tabItem { Label(L("tab_ruta"), systemImage: "mountain.2") }.tag(P.ruta)
            BrujulaVista(abrir81: Config.pestanaInicial == "brujula81").tabItem { Label(L("ios_tab_brujula"), systemImage: "safari") }.tag(P.brujula)
            ComunidadVista(abrirPublicar: Config.pestanaInicial == "publicar").tabItem { Label(L("tab_comunidad"), systemImage: "flame") }.tag(P.comunidad)
            FinanzasVista().tabItem { Label(L("ios_tab_finanzas"), systemImage: "dollarsign.circle") }.tag(P.finanzas)
        }
        .sheet(isPresented: .constant(Config.pestanaInicial == "cuenta")) { CuentaVista() }
        .fullScreenCover(isPresented: .constant(["bienestar", "ajustes", "agenda", "mes", "deudas", "metasfin"].contains(Config.pestanaInicial ?? ""))) {
            NavigationStack {
                switch Config.pestanaInicial {
                case "ajustes": AjustesVista()
                case "agenda": AgendaVista()
                case "mes": MesVista()
                case "deudas": DeudasVista()
                case "metasfin": MetasFinVista()
                default: BienestarVista()
                }
            }
        }
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

/// Le deja al widget «Tu paso de hoy» los hábitos de hoy y el siguiente que falta.
@MainActor
enum PuenteWidget {
    private static var ultimo = ""
    static func actualizar() {
        let a = Almacen.shared, h = Habitos.lista(a), m = Habitos.marcados(a)
        let r = ResumenWidget(hechos: h.filter { m.contains($0.id) }.count, total: h.count, cumbre: Perfil(a).cumbre,
                              siguiente: h.first { !m.contains($0.id) }?.texto ?? "", fecha: Fecha.iso())
        let firma = "\(r.hechos)|\(r.total)|\(r.cumbre)|\(r.siguiente)|\(r.fecha)"
        guard firma != ultimo else { return }
        ultimo = firma; r.guardar(); WidgetCenter.shared.reloadAllTimelines()
    }
}
