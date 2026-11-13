import SwiftUI

/// Tu cuenta: quién eres, si tu ruta está al día con la nube, salir y eliminar la cuenta.
struct CuentaVista: View {
    @Environment(Almacen.self) private var a
    @Environment(\.openURL) private var abrir
    @State private var confirmarEliminar = false
    @State private var eliminando = false
    @State private var error: String?
    var body: some View {
        let _ = a.version
        let p = Perfil(a)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Tema.burdeosSuave)
                            Text(String(p.nombre.prefix(1)).uppercased()).font(Tema.serif(.title2, .semibold)).foregroundStyle(Tema.burdeos)
                        }
                        .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.nombre.isEmpty ? L("tab_perfil") : p.nombre).font(.headline)
                            Text(Config.demo ? L("ios_demo") : (Nube.shared?.correo ?? "")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    HStack {
                        Label(a.errorNube == nil ? L("ios_al_dia") : L("ios_sin_nube"), systemImage: a.errorNube == nil ? "checkmark.icloud" : "icloud.slash")
                        Spacer()
                        if a.cargando { ProgressView() }
                    }
                    Button { Task { await a.traerDeLaNube() } } label: { Label(L("ios_traer"), systemImage: "arrow.clockwise") }
                } footer: { Text(L("ios_misma_cuenta")) }
                Section {
                    Button { abrir(Config.sitio) } label: { Label(L("ios_abrir_web"), systemImage: "safari") }
                    Button { abrir(Config.sitio.appendingPathComponent("privacidad.html")) } label: { Label(L("ios_privacidad"), systemImage: "hand.raised") }
                }
                if !Config.demo {
                    Section {
                        Button(L("cerrar_sesion")) { Task { await a.cerrarSesion() } }
                        Button(L("ios_eliminar_cuenta"), role: .destructive) { confirmarEliminar = true }.disabled(eliminando)
                    } footer: {
                        if let error { Text(error).foregroundStyle(Tema.burdeos) }
                    }
                }
            }
            .fondoPapel()
            .navigationTitle(L("tab_perfil"))
            .confirmationDialog(L("ios_eliminar_cuenta"), isPresented: $confirmarEliminar, titleVisibility: .visible) {
                Button(L("ios_eliminar_si"), role: .destructive) {
                    Task {
                        eliminando = true; defer { eliminando = false }
                        do { try await Nube.shared?.eliminarCuenta(); await a.cerrarSesion() }
                        catch { self.error = L("ios_eliminar_error") }
                    }
                }
            } message: { Text(L("ios_eliminar_aviso")) }
        }
    }
}
