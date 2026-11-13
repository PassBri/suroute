import SwiftUI

/// Aprende y Mochila: los cuadernos del método (los mismos JSON de la app Android, app/src/main/assets/content).
/// Las respuestas se guardan como en Android y la web: respuesta con la clave del bloque y el cuaderno.
struct Cuaderno: Decodable, Identifiable, Hashable {
    let id: String, title: String
    let subtitle: String?, category: String?, order: Int?
    let sections: [Seccion]?
    struct Seccion: Decodable, Hashable { let id: String?; let title: String?; let blocks: [Bloque]? }
}
struct IndiceCuaderno: Decodable, Identifiable, Hashable {
    let id: String, title: String
    let subtitle: String?, category: String?, order: Int?, inputs: Int?
}
final class Bloque: Decodable, Hashable {
    let type: String
    let text: String?, label: String?, title: String?, number: String?, mark: String?, id: String?
    let level: Int?, min: Int?, max: Int?, rows: Int?
    let options: [String]?, headers: [String]?, rowLabels: [String]?
    let tabla: [[String]]?
    let blocks: [Bloque]?
    enum K: String, CodingKey { case type, text, label, title, number, mark, id, level, min, max, rows, options, headers, rowLabels, blocks }
    required init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        text = try? c.decode(String.self, forKey: .text); label = try? c.decode(String.self, forKey: .label)
        title = try? c.decode(String.self, forKey: .title); number = try? c.decode(String.self, forKey: .number)
        mark = try? c.decode(String.self, forKey: .mark); id = try? c.decode(String.self, forKey: .id)
        level = try? c.decode(Int.self, forKey: .level); min = try? c.decode(Int.self, forKey: .min); max = try? c.decode(Int.self, forKey: .max)
        options = try? c.decode([String].self, forKey: .options); headers = try? c.decode([String].self, forKey: .headers)
        rowLabels = try? c.decode([String].self, forKey: .rowLabels); blocks = try? c.decode([Bloque].self, forKey: .blocks)
        // "rows" es un número en inputTable y una matriz de textos en table
        rows = try? c.decode(Int.self, forKey: .rows); tabla = try? c.decode([[String]].self, forKey: .rows)
    }
    static func == (a: Bloque, b: Bloque) -> Bool { a === b }
    func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

enum Contenido {
    static func url(_ id: String) -> URL? { Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "content") }
    static let indice: [IndiceCuaderno] = {
        guard let u = url("index"), let d = try? Data(contentsOf: u) else { return [] }
        return ((try? JSONDecoder().decode([IndiceCuaderno].self, from: d)) ?? []).sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }()
    static func cuaderno(_ id: String) -> Cuaderno? {
        guard let u = url(id), let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(Cuaderno.self, from: d)
    }
    /// Las herramientas de la mochila, por el momento en que sirven (igual que la web y Android).
    static let mochila: [(String, [String])] = [
        ("ios_mochila_metas", ["bono_metas", "bono_indicadores", "bono_confluencia"]),
        ("ios_mochila_dias", ["bono_acciones"]),
        ("ios_mochila_mes", ["bono_cierre", "bono_evidencias"]),
        ("ios_mochila_caidas", ["bono_anti_abandono"]),
    ]
    static var idsMochila: Set<String> { Set(mochila.flatMap(\.1)) }
}

/// Aprende: los cuadernos por categoría, con cuántas respuestas llevas.
struct AprendeVista: View {
    @Environment(Almacen.self) private var a
    var mochila = false
    var body: some View {
        let _ = a.version
        List {
            if mochila {
                ForEach(Contenido.mochila, id: \.0) { (grupo, ids) in
                    Section(L(grupo)) { ForEach(Contenido.indice.filter { ids.contains($0.id) }) { fila($0) } }
                }
            } else {
                let lista = Contenido.indice.filter { !Contenido.idsMochila.contains($0.id) }
                let cats = lista.reduce(into: [String]()) { r, x in let c = x.category ?? ""; if !r.contains(c) { r.append(c) } }
                ForEach(cats, id: \.self) { c in
                    Section(c.isEmpty ? "" : c.capitalizedPrimeraLetra) { ForEach(lista.filter { ($0.category ?? "") == c }) { fila($0) } }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L(mochila ? "ios_mochila" : "tab_aprende"))
    }
    private func fila(_ x: IndiceCuaderno) -> some View {
        let n = (a.docs["respuesta"] ?? [:]).values.filter { $0.t("workbookId") == x.id && !$0.t("clave").contains("#") && !$0.t("valor").isEmpty }.count
        return NavigationLink { CuadernoVista(id: x.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(x.title).font(.body.weight(.medium))
                    if let s = x.subtitle, !s.isEmpty { Text(s).font(.footnote).foregroundStyle(Tema.tintaSuave) }
                }
                Spacer()
                if let t = x.inputs, t > 0, n > 0 { Text("\(min(n, t))/\(t)").font(.caption.monospacedDigit()).foregroundStyle(Tema.oro) }
            }
        }
    }
}

/// Un cuaderno: sus secciones con lectura e interacción (escribir, marcar, elegir, calificar y tablas).
struct CuadernoVista: View {
    let id: String
    @State private var c: Cuaderno?
    @State private var seccion = 0
    var body: some View {
        ScrollView {
            if let c, let secs = c.sections, !secs.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    if secs.count > 1 {
                        Picker(L("ios_seccion"), selection: $seccion) {
                            ForEach(secs.indices, id: \.self) { i in Text(secs[i].title ?? "\(i + 1)").tag(i) }
                        }
                        .pickerStyle(.menu)
                    }
                    let s = secs[min(seccion, secs.count - 1)]
                    if let t = s.title { Text(t).font(Tema.serif(.title2, .semibold)) }
                    ForEach(s.blocks ?? [], id: \.self) { b in VistaBloque(b: b, wb: id) }
                    HStack {
                        if seccion > 0 { Button { withAnimation { seccion -= 1 } } label: { Label(L("ios_anterior"), systemImage: "chevron.left") } }
                        Spacer()
                        if seccion < secs.count - 1 {
                            Button { withAnimation { seccion += 1 } } label: { Label(L("ios_siguiente"), systemImage: "chevron.right").labelStyle(.titleAndIcon) }
                                .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(16)
            } else { ProgressView().padding(.top, 60) }
        }
        .fondoPapel()
        .navigationTitle(c?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { c = Contenido.cuaderno(id) }
    }
}

private func md(_ s: String?) -> Text {
    Text((try? AttributedString(markdown: s ?? "", options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s ?? ""))
}

private struct VistaBloque: View {
    @Environment(Almacen.self) private var a
    let b: Bloque, wb: String
    var body: some View {
        switch b.type {
        case "heading": md(b.text).font(b.level ?? 2 <= 2 ? .title3.weight(.semibold) : .headline).padding(.top, 6)
        case "paragraph": md(b.text).font(.body).foregroundStyle(Tema.tinta)
        case "bullet": HStack(alignment: .firstTextBaseline, spacing: 8) { Text(b.mark ?? "•").foregroundStyle(Tema.oro); md(b.text) }
        case "quote": md(b.text).font(Tema.serif(.body)).italic().padding(.leading, 12).overlay(alignment: .leading) { Rectangle().fill(Tema.oro).frame(width: 2) }
        case "callout":
            VStack(alignment: .leading, spacing: 8) { ForEach(b.blocks ?? [], id: \.self) { VistaBloque(b: $0, wb: wb) } }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Tema.oroSuave, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        case "table": TablaFija(b: b)
        case "prompt": Escribir(b: b, wb: wb)
        case "check":
            let si = !a.respuesta(b.id ?? "").isEmpty
            Button { a.responder(wb, b.id ?? "", si ? "" : "1") } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: si ? "checkmark.square.fill" : "square").foregroundStyle(si ? Tema.burdeos : Tema.tintaSuave)
                    md(b.label).foregroundStyle(Tema.tinta).multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
        case "choice":
            let v = a.respuesta(b.id ?? "")
            VStack(alignment: .leading, spacing: 8) {
                md(b.label).font(.subheadline.weight(.medium))
                FlowOpciones(opciones: b.options ?? [], elegida: v) { o in a.responder(wb, b.id ?? "", v == o ? "" : o) }
            }
        case "scale":
            let v = Int(a.respuesta(b.id ?? "")) ?? 0
            VStack(alignment: .leading, spacing: 8) {
                md(b.label).font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    ForEach((b.min ?? 1)...(b.max ?? 10), id: \.self) { i in
                        Button { a.responder(wb, b.id ?? "", v == i ? "" : String(i)) } label: {
                            Text("\(i)").font(.footnote.monospacedDigit().weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
                                .background(v == i ? Tema.burdeos : Tema.hoja, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(v == i ? Tema.sobreColor : Tema.tinta)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case "inputTable": TablaEntrada(b: b, wb: wb)
        default: EmptyView()
        }
    }
}

private struct Escribir: View {
    @Environment(Almacen.self) private var a
    let b: Bloque, wb: String
    @State private var texto = ""
    @FocusState private var foco: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let t = b.title { md((b.number.map { $0 + " " } ?? "") + t).font(.subheadline.weight(.semibold)) }
            if let l = b.label { md(l).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
            TextField(L("ios_escribe_aqui"), text: $texto, axis: .vertical).lineLimit(3...10).focused($foco)
                .padding(12).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: foco) { _, f in if !f { a.responder(wb, b.id ?? "", texto.trimmingCharacters(in: .whitespacesAndNewlines)) } }
                .onSubmit { a.responder(wb, b.id ?? "", texto) }
        }
        .onAppear { texto = a.respuesta(b.id ?? "") }
        .onDisappear { if texto != a.respuesta(b.id ?? "") { a.responder(wb, b.id ?? "", texto.trimmingCharacters(in: .whitespacesAndNewlines)) } }
    }
}

private struct FlowOpciones: View {
    let opciones: [String], elegida: String
    let elegir: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(opciones, id: \.self) { o in
                Button { elegir(o) } label: {
                    HStack {
                        Image(systemName: elegida == o ? "largecircle.fill.circle" : "circle").foregroundStyle(elegida == o ? Tema.burdeos : Tema.tintaSuave)
                        md(o).foregroundStyle(Tema.tinta)
                        Spacer()
                    }
                    .frame(minHeight: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TablaFija: View {
    let b: Bloque
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                if let h = b.headers { GridRow { ForEach(h, id: \.self) { md($0).font(.caption.weight(.semibold)).foregroundStyle(Tema.tintaSuave) } }; Divider() }
                ForEach(Array((b.tabla ?? []).enumerated()), id: \.offset) { _, fila in
                    GridRow { ForEach(Array(fila.enumerated()), id: \.offset) { _, x in md(x).font(.footnote).frame(maxWidth: 220, alignment: .leading) } }
                }
            }
            .padding(12)
        }
        .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TablaEntrada: View {
    @Environment(Almacen.self) private var a
    let b: Bloque, wb: String
    var body: some View {
        let etiquetas = b.rowLabels ?? [], con = !etiquetas.isEmpty
        let cols = con ? Array((b.headers ?? []).dropFirst()) : (b.headers ?? [])
        let filas = con ? etiquetas.count : (Int(a.respuesta((b.id ?? "") + "#n")) ?? (b.rows ?? 3))
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<filas, id: \.self) { r in
                VStack(alignment: .leading, spacing: 6) {
                    if con { md(etiquetas[r]).font(.subheadline.weight(.semibold)) }
                    ForEach(cols.indices, id: \.self) { c in
                        Celda(clave: "\(b.id ?? "")#\(r)_\(c)", titulo: cols[c], wb: wb)
                    }
                }
                .padding(12).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if !con {
                Button { a.responder(wb, (b.id ?? "") + "#n", String(filas + 1)) } label: { Label(L("ios_fila"), systemImage: "plus") }.font(.footnote)
            }
        }
    }
}

private struct Celda: View {
    @Environment(Almacen.self) private var a
    let clave: String, titulo: String, wb: String
    @State private var t = ""
    var body: some View {
        TextField(titulo, text: $t).font(.subheadline)
            .onAppear { t = a.respuesta(clave) }
            .onSubmit { a.responder(wb, clave, t) }
            .onDisappear { if t != a.respuesta(clave) { a.responder(wb, clave, t) } }
    }
}
