import SwiftUI

/// Mensajes: las conversaciones (las solicitudes nuevas primero) y cada chat.
struct MensajesVista: View {
    @State private var convs: [Conversacion] = []
    @State private var cargado = false
    var body: some View {
        List {
            let solicitudes = convs.filter { $0.estado == "pendiente" && $0.iniciada_por != Red.yo }
            if !solicitudes.isEmpty {
                Section(L("mensajes_solicitudes")) { ForEach(solicitudes) { c in fila(c) } }
            }
            Section { ForEach(convs.filter { !solicitudes.contains($0) }) { c in fila(c) } }
            if cargado && convs.isEmpty {
                Text(L(Config.demo ? "mensajes_sin_cuenta" : "mensajes_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                    .listRowBackground(Color.clear)
            }
        }
        .fondoPapel()
        .navigationTitle(L("mensajes"))
        .refreshable { await cargar() }
        .task { await cargar() }
    }
    private func fila(_ c: Conversacion) -> some View {
        NavigationLink(value: Destino.chat(c)) {
            HStack(spacing: 12) {
                Avatar(url: nil, nombre: c.nombre, tam: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.nombre).font(.subheadline.weight((c.no_leidos ?? 0) > 0 ? .bold : .semibold))
                    Text(c.estado == "pendiente" && c.iniciada_por != Red.yo ? L("mensajes_quiere_escribirte") : (c.ultimo_texto ?? ""))
                        .font(.footnote).foregroundStyle(Tema.tintaSuave).lineLimit(1)
                }
                Spacer()
                if let n = c.no_leidos, n > 0 {
                    Text("\(n)").font(.caption2.bold()).foregroundStyle(Tema.sobreColor).padding(.horizontal, 7).padding(.vertical, 3).background(Tema.burdeos, in: Capsule())
                }
            }
        }
    }
    private func cargar() async { convs = (try? await Red.conversaciones()) ?? []; cargado = true }
}

struct ChatVista: View {
    let conv: Conversacion
    @State private var estado: String
    @State private var mensajes: [Mensaje] = []
    @State private var texto = ""
    @State private var reportando = false
    @State private var motivo = ""
    @State private var reloj = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    init(conv: Conversacion) { self.conv = conv; _estado = State(initialValue: conv.estado) }

    var body: some View {
        let solicitudParaMi = estado == "pendiente" && conv.iniciada_por != Red.yo
        ScrollViewReader { lector in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(mensajes) { m in
                        let mio = m.autor == Red.yo
                        HStack {
                            if mio { Spacer(minLength: 50) }
                            Text(m.texto).font(.body)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(mio ? Tema.burdeos : Tema.hoja, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .foregroundStyle(mio ? Tema.sobreColor : Tema.tinta)
                            if !mio { Spacer(minLength: 50) }
                        }
                        .id(m.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: mensajes.count) { _, _ in if let u = mensajes.last { withAnimation { lector.scrollTo(u.id, anchor: .bottom) } } }
        }
        .fondoPapel()
        .navigationTitle(conv.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                NavigationLink(value: Destino.persona(conv.otro)) { Label(L("tab_perfil"), systemImage: "person") }
                Button(L("mensajes_reportar"), systemImage: "flag") { reportando = true }
                Button(L("mensajes_bloquear"), systemImage: "hand.raised", role: .destructive) { Task { try? await Red.bloquear(conv.otro); estado = "bloqueada" } }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if solicitudParaMi {
                    VStack(spacing: 8) {
                        Text(L("mensajes_solicitud_texto")).font(.footnote).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                        HStack {
                            Button(L("mensajes_rechazar")) { Task { try? await Red.responderSolicitud(conv.id, aceptar: false); estado = "bloqueada" } }.buttonStyle(.bordered)
                            Button(L("mensajes_aceptar")) { Task { try? await Red.responderSolicitud(conv.id, aceptar: true); estado = "aceptada" } }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                        }
                    }
                } else if estado == "bloqueada" {
                    Text(L("mensajes_bloqueada")).font(.footnote).foregroundStyle(Tema.tintaSuave)
                } else {
                    HStack(spacing: 8) {
                        TextField(L("mensajes_escribe"), text: $texto, axis: .vertical).lineLimit(1...5)
                            .padding(.horizontal, 14).padding(.vertical, 10).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        Button {
                            let t = texto.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
                            texto = ""
                            Task { try? await Red.enviar(conv.id, t); await cargar() }
                        } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }
                            .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel(L("enviar"))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).frame(maxWidth: .infinity).background(.bar)
        }
        .alert(L("mensajes_reportar"), isPresented: $reportando) {
            TextField(L("mensajes_reportar_motivo"), text: $motivo)
            Button(L("cancelar"), role: .cancel) {}
            Button(L("enviar")) { Task { try? await Red.reportar(persona: conv.otro, conversacion: conv.id, motivo: motivo) } }
        }
        .task { await cargar(); await Red.marcarLeidos(conv.id) }
        .onReceive(reloj) { _ in Task { await cargar() } }
    }
    private func cargar() async {
        if let xs = try? await Red.mensajes(conv.id), xs.count != mensajes.count || xs.last?.id != mensajes.last?.id { mensajes = xs }
    }
}
