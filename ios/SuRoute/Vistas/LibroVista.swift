import SwiftUI

/// Libro de cumbres (igual que Android y la web): las páginas que se firman (campamentos con sus 8 pasos, la cumbre
/// con los 64, metas del año cumplidas), una cápsula por mes que se sella al terminar y se abre después, la carta al
/// año que sigue y el libro del año en PDF. Cuaderno "libro": "libro#firma#<clave>", "libro#capsula#aaaa-mm",
/// "libro#frase#aaaa-mm" y "libro#carta#aaaa".
@MainActor
enum LibroCumbres {
    static let wb = "libro"
    enum Tipo { case campamento, cumbre, meta }
    struct Hito: Identifiable, Hashable {
        let clave: String; let tipo: Tipo; let titulo: String; let cod: String?; let fecha: String?
        var id: String { clave }
    }
    struct Firma { let fecha: String; let texto: String }

    static func hitos(_ a: Almacen) -> [Hito] {
        var h: [Hito] = []
        let b = Brujula(a, anio: nil)
        var todos = 0, fechas: [String] = []
        for (i, c) in b.campamentos.enumerated() {
            guard let c else { continue }
            let fs = (0..<8).map { a.respuesta(Brujula.claveHecho(c.clave, $0)).trimmingCharacters(in: .whitespaces) }
            let hechos = fs.filter { !$0.isEmpty }
            todos += hechos.count; fechas += hechos
            if hechos.count == 8 { h.append(Hito(clave: "camp:\(c.clave)", tipo: .campamento, titulo: L("lb_campamento_x", Campamento.nombre(Campamento.fijos[i])), cod: Campamento.fijos[i], fecha: hechos.max().map { String($0.prefix(10)) })) }
        }
        if todos == 64 { h.append(Hito(clave: "cumbre", tipo: .cumbre, titulo: L("lb_mi_cumbre"), cod: nil, fecha: fechas.max().map { String($0.prefix(10)) })) }
        for m in Cascada(a).anuales where m.cumplida {
            h.append(Hito(clave: "meta:\(m.clave)", tipo: .meta, titulo: m.titulo, cod: m.eje?.rawValue, fecha: "\(m.anio)-12-31"))
        }
        return h.sorted { ($0.fecha ?? "") > ($1.fecha ?? "") }
    }
    static func firma(_ a: Almacen, _ h: Hito) -> Firma? {
        let v = a.respuesta("libro#firma#\(h.clave)")
        guard let d = v.data(using: .utf8), let o = try? JSONDecoder().decode([String: String].self, from: d) else { return nil }
        return Firma(fecha: o["fecha"] ?? "", texto: o["texto"] ?? "")
    }
    static func firmar(_ a: Almacen, _ h: Hito, _ texto: String) {
        let o = ["fecha": firma(a, h)?.fecha ?? h.fecha ?? Fecha.iso(), "texto": texto, "foto": ""]
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        a.responder(wb, "libro#firma#\(h.clave)", (try? e.encode(o)).flatMap { String(data: $0, encoding: .utf8) } ?? "")
    }

    struct Mes { let ym: String; let constancia: Int; let pasos: [(String, String)]; let alto: [(String, String, String)]; let firmas: [Hito]; let frase: String
        var vacio: Bool { constancia == 0 && pasos.isEmpty && alto.isEmpty && firmas.isEmpty } }
    static func mes(_ a: Almacen, _ ym: String) -> Mes {
        let p = ym.split(separator: "-").compactMap { Int($0) }
        let n = Fecha.cal.range(of: .day, in: .month, for: Fecha.cal.date(from: DateComponents(year: p[0], month: p[1], day: 1))!)?.count ?? 30
        let constancia = (1...n).filter { !Habitos.marcados(a, String(format: "%@-%02d", ym, $0)).isEmpty }.count
        var pasos: [(String, String)] = []
        let b = Brujula(a, anio: nil)
        for c in b.campamentos.compactMap({ $0 }) { for i in 0..<8 {
            let f = a.respuesta(Brujula.claveHecho(c.clave, i))
            if f.hasPrefix(ym) { pasos.append((b.paso(a, c, i), String(f.prefix(10)))) }
        } }
        var alto: [(String, String, String)] = []
        if let bn = Alto.banco() {
            for (i, q) in Alto.delMes(bn, anio: p[0], mes: p[1]).enumerated() {
                let r = a.respuesta(Alto.clave(ym, i)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !r.isEmpty { alto.append((q.nombre, q.texto, r)) }
            }
        }
        let firmas = hitos(a).filter { firma(a, $0) != nil && ($0.fecha ?? "").hasPrefix(ym) }
        return Mes(ym: ym, constancia: constancia, pasos: pasos, alto: alto, firmas: firmas, frase: a.respuesta("libro#frase#\(ym)"))
    }
    static func nombreMes(_ ym: String) -> String { let p = ym.split(separator: "-").compactMap { Int($0) }; return Fecha.nombreMes(p[1]) + " \(p[0])" }

    /// El libro del año en PDF (A4, solo texto): portada, cumbres firmadas, cada mes y la carta.
    static func pdf(_ a: Almacen, anio: Int) -> URL? {
        let meses = (1...12).map { String(format: "%04d-%02d", anio, $0) }.filter { $0 <= String(Fecha.iso().prefix(7)) }.map { mes(a, $0) }
        let firmadas = hitos(a).filter { ($0.fecha ?? "").hasPrefix(String(anio)) && firma(a, $0) != nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SuRoute-\(anio).pdf")
        let ancho: CGFloat = 595, alto: CGFloat = 842, margen: CGFloat = 48
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: ancho, height: alto))
        do {
            try r.writePDF(to: url) { ctx in
                var y: CGFloat = margen
                ctx.beginPage()
                func escribir(_ s: String, _ f: UIFont, despues: CGFloat = 6) {
                    let at = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: UIColor(hex: 0x2B1D17)])
                    let h = at.boundingRect(with: CGSize(width: ancho - 2 * margen, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height
                    if y + h > alto - margen { ctx.beginPage(); y = margen }
                    at.draw(with: CGRect(x: margen, y: y, width: ancho - 2 * margen, height: h), options: [.usesLineFragmentOrigin], context: nil)
                    y += h + despues
                }
                let serif = UIFont(descriptor: UIFont.systemFont(ofSize: 26).fontDescriptor.withDesign(.serif)!, size: 26)
                let sub = UIFont(descriptor: UIFont.boldSystemFont(ofSize: 17).fontDescriptor.withDesign(.serif)!, size: 17)
                let tx = UIFont.systemFont(ofSize: 11.5)
                escribir(L("lb_libro_de", anio), serif, despues: 14)
                escribir("\(meses.reduce(0) { $0 + $1.constancia }) \(L("lb_pdf_dias")) · \(meses.reduce(0) { $0 + $1.pasos.count }) \(L("lb_pasos_ganados")) · \(firmadas.count) \(L("lb_cumbres_firmadas"))", tx, despues: 18)
                for h in firmadas {
                    escribir("\(h.titulo) · \(h.fecha ?? "")", sub, despues: 4)
                    if let t = firma(a, h)?.texto, !t.isEmpty { escribir("“\(t)”", tx, despues: 12) }
                }
                for d in meses.reversed() {
                    escribir(nombreMes(d.ym), sub, despues: 4)
                    if d.vacio { escribir(L("lb_un_mes_silencio"), tx, despues: 12); continue }
                    escribir("\(d.constancia) \(L("lb_pdf_dias")) · \(d.pasos.count) \(L("lb_pasos_ganados"))", tx, despues: 4)
                    for (t, f) in d.pasos { escribir("• \(t) (\(f))", tx, despues: 2) }
                    for (n, q, rr) in d.alto { escribir("\(n) — \(q)\n\(rr)", tx, despues: 4) }
                    if !d.frase.isEmpty { escribir("“\(d.frase)”", tx, despues: 4) }
                    y += 8
                }
                let carta = a.respuesta("libro#carta#\(anio)")
                if !carta.isEmpty { escribir(L("lb_carta_a", anio + 1), sub, despues: 4); escribir(carta, tx) }
            }
            return url
        } catch { return nil }
    }
}

struct LibroVista: View {
    @Environment(Almacen.self) private var a
    @State private var anio = Fecha.anio
    @State private var firmando: LibroCumbres.Hito?
    @State private var pdf: URL?
    var body: some View {
        let _ = a.version
        let hitos = LibroCumbres.hitos(a), porFirmar = hitos.filter { LibroCumbres.firma(a, $0) == nil }.count
        let hoyYm = String(Fecha.iso().prefix(7))
        List {
            Section { Text(L("lb_sub")).font(.footnote).foregroundStyle(Tema.tintaSuave) }
            Section {
                if hitos.isEmpty { Text(L("lb_sin_paginas")).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
                ForEach(hitos) { h in
                    let f = LibroCumbres.firma(a, h)
                    Button { firmando = h } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: h.tipo == .cumbre ? "mountain.2.fill" : h.tipo == .campamento ? "flag.fill" : "checkmark.seal.fill").font(.title3)
                                .foregroundStyle(h.cod.map(Tema.eje) ?? Tema.oro).frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.titulo).font(Tema.serif(.headline)).foregroundStyle(Tema.tinta)
                                Text(h.tipo == .campamento ? L("lb_sub_camp") : h.tipo == .cumbre ? L("lb_sub_cumbre") : L("lb_sub_meta", String((h.fecha ?? "").prefix(4))))
                                    .font(.caption).foregroundStyle(Tema.tintaSuave)
                                if let f, !f.texto.isEmpty { Text("“" + f.texto + "”").font(Tema.serif(.subheadline)).italic().foregroundStyle(Tema.tinta) }
                                else { Text(L("lb_firmar_pagina")).font(.caption.weight(.semibold)).foregroundStyle(Tema.burdeos) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: { HStack { Text(L("lb_paginas")); Spacer(); if porFirmar > 0 { Text(L("lb_por_firmar", porFirmar)) } } }
            Section {
                ForEach((1...12).reversed().map { String(format: "%04d-%02d", anio, $0) }.filter { $0 <= hoyYm }, id: \.self) { ym in
                    let abierta = !a.respuesta("libro#capsula#\(ym)").isEmpty
                    NavigationLink { CapsulaVista(ym: ym) } label: {
                        HStack {
                            Image(systemName: ym == hoyYm ? "hourglass" : abierta ? "envelope.open" : "envelope.fill").foregroundStyle(ym == hoyYm ? Tema.tintaSuave : Tema.burdeos).frame(width: 26)
                            Text(LibroCumbres.nombreMes(ym))
                            Spacer()
                            Text(ym == hoyYm ? L("lb_llenandose") : abierta ? L("lb_abierta") : L("lb_sellada")).font(.caption).foregroundStyle(Tema.tintaSuave)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(L("lb_capsulas_de", anio))
                    Spacer()
                    Picker("", selection: $anio) { ForEach((Fecha.anio - 5)...Fecha.anio, id: \.self) { Text(String($0)).tag($0) } }.pickerStyle(.menu)
                }
            }
            Section(L("lb_carta_a", anio + 1)) {
                CampoGuardado(titulo: L("lb_carta_ph", anio + 1), valor: a.respuesta("libro#carta#\(anio)"), lineas: 4...12) { a.responder(LibroCumbres.wb, "libro#carta#\(anio)", $0) }
                    .font(Tema.serif(.body))
            }
            Section {
                Button { pdf = LibroCumbres.pdf(a, anio: anio) } label: { Label(L("lb_pdf"), systemImage: "doc.richtext") }
                if let pdf { ShareLink(item: pdf) { Label(L("lb_pdf_ok"), systemImage: "square.and.arrow.up") } }
            }
        }
        .fondoPapel()
        .navigationTitle(L("lb_titulo"))
        .onChange(of: anio) { _, _ in pdf = nil }
        .sheet(item: $firmando) { h in FirmarHito(h: h) }
    }
}

private struct FirmarHito: View {
    let h: LibroCumbres.Hito
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(h.titulo).font(Tema.serif(.title3, .semibold)) }
                Section(L("lb_que_costo")) { TextField(L("lb_que_costo_ph"), text: $texto, axis: .vertical).lineLimit(4...10).font(Tema.serif(.body)) }
            }
            .navigationTitle(L("lb_firmar_t")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("lb_firmar")) { LibroCumbres.firmar(a, h, texto.trimmingCharacters(in: .whitespacesAndNewlines)); cerrar() } }
            }
            .onAppear { texto = LibroCumbres.firma(a, h)?.texto ?? "" }
        }
        .presentationDetents([.medium, .large])
    }
}

/// La cápsula de un mes: se llena durante el mes, se sella al terminar y se abre rompiendo el sello.
struct CapsulaVista: View {
    let ym: String
    @Environment(Almacen.self) private var a
    var body: some View {
        let actual = ym == String(Fecha.iso().prefix(7)), abierta = !a.respuesta("libro#capsula#\(ym)").isEmpty, d = LibroCumbres.mes(a, ym)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if actual {
                    Hoja {
                        Text(L("lb_llenando_t", LibroCumbres.nombreMes(ym))).font(Tema.serif(.title3, .semibold))
                        let p = ym.split(separator: "-").compactMap { Int($0) }
                        let abre = Fecha.cal.date(from: DateComponents(year: p[0], month: p[1] + 1, day: 1)) ?? Date()
                        Text(L("lb_llenando_d", abre.formatted(date: .long, time: .omitted))).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                    }
                } else if !abierta {
                    Hoja {
                        VStack(spacing: 14) {
                            Image("Sello").resizable().scaledToFit().frame(width: 96, height: 96)
                            Text(L("lb_capsula_lista", LibroCumbres.nombreMes(ym))).font(Tema.serif(.title3, .semibold)).multilineTextAlignment(.center)
                            Text(L("lb_capsula_lista_d")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                            Button(L("lb_romper")) { withAnimation(.easeOut(duration: 0.5)) { a.responder(LibroCumbres.wb, "libro#capsula#\(ym)", Fecha.iso()) } }
                                .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: abierta)
                }
                if actual || abierta {
                    Hoja {
                        HStack(spacing: 18) {
                            Cifra(n: d.constancia, t: L("lb_dias_constancia", Fecha.cal.range(of: .day, in: .month, for: Fecha.de(ym + "-01") ?? Date())?.count ?? 30))
                            Cifra(n: d.pasos.count, t: L("lb_pasos_ganados"))
                            Cifra(n: d.firmas.count, t: L("lb_cumbres_firmadas"))
                        }
                        if d.vacio { Text(L("lb_mes_silencio")).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
                    }
                    if !d.pasos.isEmpty {
                        Hoja {
                            Text(L("lb_pasos_que")).font(.headline)
                            ForEach(Array(d.pasos.enumerated()), id: \.offset) { _, p in Label(p.0.isEmpty ? L("lb_paso_ganado") : p.0, systemImage: "checkmark.circle.fill").font(.subheadline) }
                        }
                    }
                    if !d.alto.isEmpty {
                        Hoja {
                            Text(L("lb_tu_alto")).font(.headline)
                            ForEach(Array(d.alto.enumerated()), id: \.offset) { _, x in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(x.0).font(.caption.weight(.semibold)).foregroundStyle(Tema.burdeos)
                                    Text(x.1).font(Tema.serif(.subheadline, .semibold))
                                    Text(x.2).font(.subheadline)
                                }
                            }
                        }
                    }
                    Hoja {
                        Text(L("lb_frase_mes")).font(.headline)
                        CampoGuardado(titulo: L("lb_frase_ph"), valor: d.frase, lineas: 1...4) { a.responder(LibroCumbres.wb, "libro#frase#\(ym)", $0) }.font(Tema.serif(.body))
                    }
                }
            }
            .padding(16)
        }
        .fondoPapel()
        .navigationTitle(L("lb_capsula_de", LibroCumbres.nombreMes(ym)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Cifra: View {
    let n: Int, t: String
    var body: some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.title.weight(.bold).monospacedDigit()).foregroundStyle(Tema.burdeos)
            Text(t).font(.caption2).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
