import SwiftUI

/// Cordadas: un reto de N días con otras personas; cada día se marca y se ve el avance del grupo.
struct CordadasVista: View {
    @State private var cordadas: [Cordada] = []
    @State private var codigo = ""
    @State private var creando = false
    @State private var error: String?
    var body: some View {
        List {
            Section { Text(L("cordadas_intro")).font(.footnote).foregroundStyle(Tema.tintaSuave) }
            ForEach(cordadas) { c in
                NavigationLink { DetalleCordada(c: c) } label: { FilaCordada(c: c) { si in marcar(c, si) } }
            }
            if cordadas.isEmpty { Text(L("cordadas_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
            Section(L("cordadas_unirme")) {
                HStack {
                    TextField(L("cordadas_codigo"), text: $codigo).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button(L("cordadas_entrar")) {
                        Task {
                            do { try await Red.unirse(codigo: codigo); codigo = ""; error = nil; await cargar() }
                            catch { self.error = L("ios_codigo_no_existe") }
                        }
                    }
                    .disabled(codigo.count < 4)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(Tema.burdeos) }
            }
        }
        .fondoPapel()
        .navigationTitle(L("cordadas"))
        .toolbar { Button { creando = true } label: { Label(L("cordadas_nueva"), systemImage: "plus") }.disabled(Config.demo) }
        .sheet(isPresented: $creando) { NuevaCordada { Task { await cargar() } } }
        .refreshable { await cargar() }
        .task { await cargar() }
    }
    private func cargar() async { cordadas = (try? await Red.cordadas()) ?? [] }
    private func marcar(_ c: Cordada, _ si: Bool) { Task { try? await Red.marcarHoy(c.id, si); await cargar() } }
}

private struct FilaCordada: View {
    let c: Cordada
    let marcar: (Bool) -> Void
    var body: some View {
        let color = c.eje.map { Tema.eje($0) } ?? Tema.oro
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(c.nombre).font(.headline)
                Text(c.reto).font(.footnote).foregroundStyle(Tema.tintaSuave).lineLimit(2)
                Text(c.terminada ? L("cordadas_terminada") : L("cordadas_dia_de", c.diaActual, c.dias)).font(.caption).foregroundStyle(color)
                Avance(valor: Double(c.mis_dias ?? 0) / Double(max(1, c.dias)), color: color, alto: 4)
            }
            if !c.terminada {
                Button { marcar(!(c.marque_hoy ?? false)) } label: {
                    Image(systemName: c.marque_hoy == true ? "checkmark.circle.fill" : "circle").font(.title).foregroundStyle(c.marque_hoy == true ? color : Tema.linea)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L(c.marque_hoy == true ? "cordadas_hoy_listo" : "cordadas_marcar_hoy"))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DetalleCordada: View {
    let c: Cordada
    @State private var miembros: [MiembroCordada] = []
    @Environment(\.dismiss) private var cerrar
    var body: some View {
        List {
            Section {
                Text(c.reto).font(Tema.serif(.title3))
                Text(L("cordadas_resumen", c.mis_dias ?? 0, c.miembros ?? miembros.count, c.dias_grupo ?? 0)).font(.footnote).foregroundStyle(Tema.tintaSuave)
                ShareLink(item: L("cordadas_invitacion", c.nombre, c.codigo)) { Label(L("cordadas_invitar") + " · " + c.codigo, systemImage: "square.and.arrow.up") }
            }
            Section(L("cordadas_companeros")) {
                ForEach(miembros) { m in
                    HStack {
                        Avatar(url: m.avatar, nombre: m.nombre ?? "?", tam: 36)
                        Text(m.soy_yo == true ? L("cordadas_yo") : (m.nombre ?? m.usuario ?? L("ios_senderista")))
                        Spacer()
                        Text(L("cordadas_n_de", m.dias?.count ?? 0, c.dias)).font(.footnote.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                    }
                }
            }
            Section { Button(L("cordadas_salir"), role: .destructive) { Task { try? await Red.salir(c.id); cerrar() } } }
        }
        .fondoPapel()
        .navigationTitle(c.nombre)
        .task { miembros = (try? await Red.miembros(c.id)) ?? [] }
    }
}

private struct NuevaCordada: View {
    let alCrear: () -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var reto = ""
    @State private var eje: String? = nil
    @State private var dias = 30
    var body: some View {
        NavigationStack {
            Form {
                TextField(L("cordadas_nombre"), text: $nombre)
                TextField(L("cordadas_reto_ejemplo"), text: $reto, axis: .vertical).lineLimit(2...4)
                Picker(L("cordadas_eje"), selection: $eje) {
                    Text("—").tag(String?.none)
                    ForEach(Eje.allCases) { e in Text(e.nombre).tag(String?.some(e.rawValue)) }
                }
                Stepper(L("cordadas_n_dias", dias), value: $dias, in: 7...100, step: 7)
            }
            .navigationTitle(L("cordadas_nueva"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("cordadas_crear")) {
                        Task { try? await Red.crearCordada(nombre: nombre, reto: reto, eje: eje, dias: dias); alCrear(); cerrar() }
                    }
                    .disabled(nombre.count < 2 || reto.count < 3)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
