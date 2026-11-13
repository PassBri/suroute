import SwiftUI
import Supabase

/// El coach de IA (la función «coach» de Supabase, la misma de Android y la web). La clave de la IA vive
/// en el servidor. Se elige el tema (general, propósito, metas o finanzas) y cada respuesta se puede reportar.
struct CoachVista: View {
    @Environment(Almacen.self) private var a
    struct Msg: Identifiable, Hashable { let id = UUID(); let rol: String; let texto: String }
    @State private var mensajes: [Msg] = []
    @State private var texto = ""
    @State private var tema = ""
    @State private var pensando = false
    @State private var reportar: Msg?
    @State private var error = false

    var body: some View {
        ScrollViewReader { lector in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(L("ios_coach_tema"), selection: $tema) {
                        Text(L("ios_coach_general")).tag("")
                        Text(L("ios_coach_proposito")).tag("proposito")
                        Text(L("ios_coach_metas")).tag("metas")
                        Text(L("ios_coach_finanzas")).tag("finanzas")
                    }
                    .pickerStyle(.segmented)
                    if mensajes.isEmpty {
                        Text(L("ios_coach_intro")).font(.subheadline).foregroundStyle(Tema.tintaSuave).padding(.top, 8)
                    }
                    ForEach(mensajes) { m in
                        let mio = m.rol == "user"
                        HStack {
                            if mio { Spacer(minLength: 40) }
                            Text((try? AttributedString(markdown: m.texto, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(m.texto))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(mio ? Tema.burdeos : Tema.hoja, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .foregroundStyle(mio ? Tema.sobreColor : Tema.tinta)
                                .contextMenu { if !mio { Button(L("ios_coach_reportar"), systemImage: "flag") { reportar = m } } }
                            if !mio { Spacer(minLength: 40) }
                        }
                        .id(m.id)
                    }
                    if pensando { ProgressView().padding(.leading, 8) }
                    if error { Text(L("ios_coach_error")).font(.footnote).foregroundStyle(Tema.burdeos) }
                }
                .padding(16)
            }
            .onChange(of: mensajes.count) { _, _ in if let u = mensajes.last { withAnimation { lector.scrollTo(u.id, anchor: .bottom) } } }
        }
        .fondoPapel()
        .navigationTitle(L("ios_coach"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                TextField(L("ios_coach_escribe"), text: $texto, axis: .vertical).lineLimit(1...5)
                    .padding(.horizontal, 14).padding(.vertical, 10).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button { Task { await enviar() } } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pensando || Config.demo)
                    .accessibilityLabel(L("enviar"))
            }
            .padding(.horizontal, 12).padding(.vertical, 8).background(.bar)
        }
        .confirmationDialog(L("ios_coach_reportar"), isPresented: Binding(get: { reportar != nil }, set: { if !$0 { reportar = nil } }), titleVisibility: .visible) {
            ForEach([("ofensiva", "ios_coach_m_ofensiva"), ("peligrosa", "ios_coach_m_peligrosa"), ("equivocada", "ios_coach_m_equivocada"), ("otra", "ios_coach_m_otra")], id: \.0) { (k, t) in
                Button(L(t)) { if let m = reportar { Task { await enviarReporte(m, motivo: k) } } }
            }
        } message: { Text(L("ios_coach_reportar_ayuda")) }
    }

    private func contexto() -> String {
        let p = Perfil(a), c = Cascada(a)
        var l: [String] = []
        if !p.nombre.isEmpty { l.append("Nombre: \(p.nombre)") }
        if !p.cumbre.isEmpty { l.append("Cumbre personal: \(p.cumbre)") }
        if let f = p.fase.flatMap(Fase.init(rawValue:)) { l.append("Fase actual: \(f.numero). \(f.nombre)") }
        if !c.propositos.isEmpty { l.append("Propósitos a 5 años: " + c.propositos.map { "\($0.titulo) (\(Int(c.avance($0) * 100))%)" }.joined(separator: "; ")) }
        let an = c.anuales.filter { $0.anio == Fecha.anio }
        if !an.isEmpty { l.append("Metas \(Fecha.anio): " + an.map { "\($0.titulo) (\(Int(c.avance($0) * 100))%)" }.joined(separator: "; ")) }
        let me = MetaMes.delMes(a)
        if !me.isEmpty { l.append("Metas de este mes: " + me.map { "\($0.texto) (\(Int($0.avance * 100))%)" }.joined(separator: "; ")) }
        let h = Habitos.lista(a), m = Habitos.marcados(a)
        l.append("Hábitos de hoy: \(h.filter { m.contains($0.id) }.count) de \(h.count)")
        // Las cifras de las finanzas solo viajan si la persona eligió hablar de finanzas (y las tiene abiertas)
        if tema == "finanzas" && !Fin.shared.cerrado {
            let t = Movs.totales(String(Fecha.iso().prefix(7)))
            l.append("Finanzas del mes: ingresos \(Int(t.ing)), gastos \(Int(t.gas)), ahorro \(Int(t.aho)), inversión \(Int(t.inv)), dar \(Int(t.gen)), disponible \(Int(t.disp)) \(Plata.moneda)")
        }
        return l.joined(separator: "\n")
    }

    private func enviar() async {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty, let sb = Nube.shared?.cliente else { return }
        texto = ""; error = false
        mensajes.append(Msg(rol: "user", texto: t)); pensando = true; defer { pensando = false }
        struct Entrada: Encodable { let contexto: String; let idioma: String; let mensajes: [[String: String]]; let tema: String }
        struct Salida: Decodable { let texto: String? }
        let idioma = Locale.current.language.languageCode?.identifier ?? "es"
        let hist = mensajes.suffix(20).map { ["role": $0.rol, "content": $0.texto] }
        do {
            let r: Salida = try await sb.functions.invoke("coach", options: FunctionInvokeOptions(body: Entrada(contexto: contexto(), idioma: idioma, mensajes: hist, tema: tema)))
            mensajes.append(Msg(rol: "assistant", texto: r.texto ?? ""))
        } catch { self.error = true }
    }
    private func enviarReporte(_ m: Msg, motivo: String) async {
        guard let sb = Nube.shared?.cliente else { return }
        let i = mensajes.firstIndex(of: m) ?? 0
        let pregunta = i > 0 ? mensajes[i - 1].texto : ""
        _ = try? await sb.from("coach_reportes").insert(["motivo": motivo, "pregunta": String(pregunta.prefix(2000)), "respuesta": String(m.texto.prefix(8000)), "tema": tema]).execute()
        reportar = nil
    }
}
