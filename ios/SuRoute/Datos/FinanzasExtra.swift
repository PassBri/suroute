import SwiftUI
import PhotosUI
import Supabase
import UniformTypeIdentifiers

/// Más del Ascenso financiero, con los mismos datos de Android y la web:
/// categorías propias ("fin#cats": {tipo: [{c:"u_…", n, mo}]}), movimientos frecuentes (lo que más se anota a mano
/// en 120 días) y recibos (fotos o PDF en el depósito privado "recibos", campo "r" del movimiento).

// MARK: Categorías propias

@MainActor
enum Propias {
    static let clave = "fin#cats"
    struct Cat: Codable, Hashable { var c: String; var n: String; var mo: String? }
    static func todas() -> [String: [Cat]] { Fin.shared.json(clave, [String: [Cat]].self) ?? [:] }
    static func de(_ t: TipoMov) -> [Cat] { todas()[t.rawValue] ?? [] }
    static func crear(_ t: TipoMov, nombre: String, esencial: Bool) -> String {
        var x = todas()
        let c = "u_" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        x[t.rawValue, default: []].append(Cat(c: c, n: String(nombre.prefix(40)), mo: t == .gas ? (esencial ? "verde" : "amarilla") : nil))
        Fin.shared.guardarJSON(clave, x)
        return c
    }
}

extension TipoMov {
    /// Las de siempre (sin "otro"), las propias y "otro" al final.
    @MainActor var todasCategorias: [String] {
        categorias.filter { $0 != "otro" } + Propias.de(self).map(\.c) + ["otro"]
    }
    /// El nombre de una categoría, también de las propias.
    @MainActor func nombreCat(_ c: String) -> String {
        if c.hasPrefix("u_") { return Propias.de(self).first { $0.c == c }?.n ?? L("cu_cat_\(rawValue)_otro") }
        return categoria(c)
    }
}

// MARK: Frecuentes

struct Frecuente: Identifiable, Hashable { let t: String; let c: String; let n: String; let m: Double; let veces: Int; let ultimo: String
    var id: String { "\(t)|\(c)|\(n.lowercased())" } }

@MainActor
enum Frecuentes {
    static func lista() -> [Frecuente] {
        let hoy = Fecha.iso(), desde = Fecha.iso(Fecha.cal.date(byAdding: .day, value: -120, to: Date())!)
        var g: [String: Frecuente] = [:]
        for f in Movs.dias("").filter({ $0 >= desde && $0 <= hoy }).sorted() {
            for x in Movs.guardados(f) where x.d["fx"] == nil && x.m > 0 {
                let k = "\(x.t)|\(x.c)|\(x.n.trimmingCharacters(in: .whitespaces).lowercased())"
                g[k] = Frecuente(t: x.t, c: x.c, n: x.n.trimmingCharacters(in: .whitespaces), m: x.m, veces: (g[k]?.veces ?? 0) + 1, ultimo: f)
            }
        }
        return g.values.filter { $0.veces >= 2 }.sorted { $0.veces != $1.veces ? $0.veces > $1.veces : $0.ultimo > $1.ultimo }.prefix(6).map { $0 }
    }
}

struct FilaFrecuentes: View {
    let fecha: String
    let anotado: () -> Void
    var body: some View {
        let xs = Frecuentes.lista()
        if !xs.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("fr_titulo")).font(.subheadline.weight(.semibold))
                Text(L("fr_ayuda")).font(.caption).foregroundStyle(Tema.tintaSuave)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(xs) { x in
                            let tt = TipoMov(rawValue: x.t) ?? .gas
                            Button {
                                Movs.agregar(fecha, t: tt, m: x.m, c: x.c, n: x.n); anotado()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(x.n.isEmpty ? tt.nombreCat(x.c) : x.n).font(.caption.weight(.medium)).lineLimit(1).frame(maxWidth: 150, alignment: .leading)
                                    Text(Plata.texto(x.m)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(tt == .ing ? Tema.ok : Tema.tinta)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Tema.hoja2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Tema.linea))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: Recibos

struct Recibo: Identifiable, Hashable { let id: String; let nom: String; let tipo: String; let ruta: String }

@MainActor
enum Recibos {
    static func de(_ m: Mov) -> [Recibo] {
        (m.d["r"]?.lista ?? []).compactMap { v in
            guard case .objeto(let o) = v, let id = o["id"]?.texto else { return nil }
            return Recibo(id: id, nom: o["nom"]?.texto ?? "", tipo: o["tipo"]?.texto ?? "", ruta: o["ruta"]?.texto ?? "")
        }
    }
    /// Sube la foto o el PDF a la carpeta privada y lo une al movimiento (un fijo de este mes queda propio, con su recibo).
    static func agregar(_ fecha: String, _ m: Mov, datos: Data, tipo: String, nombre: String) async throws {
        guard let sb = Red.sb, let yo = Red.yo, datos.count <= 15_000_000 else { throw URLError(.cannotCreateFile) }
        let id = "r\(Int(Date().timeIntervalSince1970 * 1000))"
        let ext = tipo == "application/pdf" ? "pdf" : "jpg"
        let ruta = "\(yo)/\(id).\(ext)"
        _ = try await sb.storage.from("recibos").upload(ruta, data: datos, options: FileOptions(contentType: tipo))
        let r: Valor = .objeto(["id": .texto(id), "nom": .texto(String(nombre.prefix(80))), "tipo": .texto(tipo), "ruta": .texto(ruta)])
        if m.virtual {
            var d = m.d; d["id"] = .texto("m\(Int(Date().timeIntervalSince1970 * 1000))"); d["r"] = .lista([r])
            Movs.guardar(fecha, Movs.guardados(fecha) + [Mov(d: d)])
        } else {
            Movs.guardar(fecha, Movs.guardados(fecha).map { x in
                guard x.id == m.id else { return x }
                var y = x; y.d["r"] = .lista((x.d["r"]?.lista ?? []) + [r]); return y
            })
        }
    }
    static func quitar(_ fecha: String, _ m: Mov, _ r: Recibo) {
        Movs.guardar(fecha, Movs.guardados(fecha).map { x in
            guard x.id == m.id else { return x }
            var y = x; y.d["r"] = .lista(recibosSin(x, r)); return y
        })
        if !r.ruta.hasPrefix("local:") { Task { _ = try? await Red.sb?.storage.from("recibos").remove(paths: [r.ruta]) } }
    }
    private static func recibosSin(_ m: Mov, _ r: Recibo) -> [Valor] {
        (m.d["r"]?.lista ?? []).filter { v in if case .objeto(let o) = v { return o["id"]?.texto != r.id }; return true }
    }
    static func url(_ r: Recibo) async -> URL? {
        guard !r.ruta.hasPrefix("local:") else { return nil }
        return try? await Red.sb?.storage.from("recibos").createSignedURL(path: r.ruta, expiresIn: 600)
    }
}

/// Los recibos de un movimiento: verlos, agregar una foto o un PDF y quitarlos.
struct RecibosVista: View {
    let fecha: String
    let mov: Mov
    @Environment(Almacen.self) private var a
    @Environment(\.openURL) private var abrir
    @State private var foto: PhotosPickerItem?
    @State private var pdf = false
    @State private var subiendo = false
    @State private var aviso: String?
    var body: some View {
        let _ = a.version
        let m = Movs.guardados(fecha).first { $0.id == mov.id } ?? mov
        let tt = TipoMov(rawValue: m.t) ?? .gas
        List {
            Section {
                HStack { Text(m.n.isEmpty ? tt.nombreCat(m.c) : m.n); Spacer(); Text(Plata.texto(m.m)).monospacedDigit().bold() }
            }
            Section {
                ForEach(Recibos.de(m)) { r in
                    Button {
                        Task { if let u = await Recibos.url(r) { abrir(u) } else { aviso = L("cu_recibo_no_abre") } }
                    } label: { Label(r.nom.isEmpty ? L("cu_recibos") : r.nom, systemImage: r.tipo == "application/pdf" ? "doc.richtext" : "photo") }
                    .swipeActions { Button(L("cu_quitar_recibo"), role: .destructive) { Recibos.quitar(fecha, m, r) } }
                }
                if Red.yo != nil && !Config.demo {
                    PhotosPicker(selection: $foto, matching: .images) { Label(L("cu_agregar_recibo"), systemImage: "camera") }
                    Button { pdf = true } label: { Label("PDF", systemImage: "doc.badge.plus") }
                }
                if subiendo { ProgressView() }
                if let aviso { Text(aviso).font(.footnote).foregroundStyle(Tema.burdeos) }
            } header: { Text(L("cu_recibos")) } footer: { Text(L("cu_recibos_privados")) }
        }
        .fondoPapel()
        .navigationTitle(L("cu_recibos"))
        .onChange(of: foto) { _, it in
            guard let it else { return }
            Task {
                subiendo = true; defer { subiendo = false; foto = nil }
                guard let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d),
                      let jpg = img.reducida(2000).jpegData(compressionQuality: 0.8) else { aviso = L("cu_recibo_error"); return }
                do { try await Recibos.agregar(fecha, m, datos: jpg, tipo: "image/jpeg", nombre: L("cu_recibos") + " " + fecha); aviso = L("cu_recibo_guardado") }
                catch { aviso = L("cu_recibo_error") }
            }
        }
        .fileImporter(isPresented: $pdf, allowedContentTypes: [.pdf]) { r in
            guard case .success(let u) = r else { return }
            Task {
                subiendo = true; defer { subiendo = false }
                let ok = u.startAccessingSecurityScopedResource(); defer { if ok { u.stopAccessingSecurityScopedResource() } }
                guard let d = try? Data(contentsOf: u) else { aviso = L("cu_recibo_error"); return }
                do { try await Recibos.agregar(fecha, m, datos: d, tipo: "application/pdf", nombre: u.lastPathComponent); aviso = L("cu_recibo_guardado") }
                catch { aviso = L("cu_recibo_error") }
            }
        }
    }
}

extension UIImage {
    func reducida(_ lado: CGFloat) -> UIImage {
        let m = max(size.width, size.height); guard m > lado else { return self }
        let s = lado / m, n = CGSize(width: size.width * s, height: size.height * s)
        return UIGraphicsImageRenderer(size: n).image { _ in draw(in: CGRect(origin: .zero, size: n)) }
    }
}

// MARK: Análisis financiero completo (PDF)

@MainActor
enum InformeFin {
    static func pdf(_ a: Almacen) -> URL? {
        let s = SaludFin.de(a, anio: nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SuRoute-analisis-financiero.pdf")
        let ancho: CGFloat = 595, alto: CGFloat = 842, mg: CGFloat = 48
        do {
            try UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: ancho, height: alto)).writePDF(to: url) { ctx in
                var y = mg
                ctx.beginPage()
                func t(_ s: String, _ f: UIFont, _ c: UIColor = UIColor(hex: 0x2B1D17), d: CGFloat = 6) {
                    let at = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c])
                    let h = at.boundingRect(with: CGSize(width: ancho - 2 * mg, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).height
                    if y + h > alto - mg { ctx.beginPage(); y = mg }
                    at.draw(with: CGRect(x: mg, y: y, width: ancho - 2 * mg, height: h), options: .usesLineFragmentOrigin, context: nil); y += h + d
                }
                let titulo = UIFont(descriptor: UIFont.systemFont(ofSize: 24).fontDescriptor.withDesign(.serif)!, size: 24)
                let sub = UIFont.boldSystemFont(ofSize: 14), tx = UIFont.systemFont(ofSize: 11.5)
                t(L("cu_informe_titulo"), titulo, d: 4)
                t(L("cu_informe_periodo", "12 " + L("ios_meses")) + " · " + Date().formatted(date: .long, time: .omitted), tx, .gray, d: 16)
                if let i = s.isf { t(L("cu_salud") + ": ISF \(i)", sub, d: 2); t(L("cu_isf_escala"), tx, .gray, d: 14) }
                t(L("cu_informe_estado_cuentas"), sub)
                for (k, v) in [(L("cu_c_ing_tot"), s.ing), (L("cu_c_egresos"), s.egresos), (L("cu_c_flujo"), s.ing - s.egresos),
                               (L("cu_c_activos"), s.activos), (L("cu_c_pasivos"), s.pasivos), (L("cu_c_neto"), s.activos - s.pasivos)] {
                    t("\(k): \(Plata.texto(v))", tx, d: 2)
                }
                y += 10
                t(L("cu_salud"), sub)
                for i in s.indicadores {
                    let e = i.estado == .ok ? L("cu_est_ok") : i.estado == .medio ? L("cu_est_medio") : L("cu_est_bajo")
                    t("• \(L("cu_ind_" + i.clave)): \(SaludFin.valor(i)) — \(e)", tx, d: 2)
                }
                y += 10
                t(L("cu_informe_que_hacer"), sub)
                let malos = s.indicadores.filter { $0.estado != .ok && $0.estado != .na }
                if malos.isEmpty { t(L("cu_informe_todo_bien"), tx) }
                for i in malos { t("• " + L("cu_ind_" + i.clave) + ": " + L("cu_est_" + (i.estado == .medio ? "medio" : "bajo")), tx, d: 2) }
                let ds = Deudas.hoy(Libro.todos())
                if ds.contains(where: { $0.actual > 0 }) {
                    let p = Deudas.plan(ds, metodo: Deudas.metodo, extra: Deudas.extra)
                    if let ms = p.meses, let f = Fecha.cal.date(byAdding: .month, value: ms, to: Date()) {
                        y += 6; t(L("cu_informe_plan", f.formatted(.dateTime.month(.wide).year()), Plata.texto(p.interes)), tx)
                    }
                }
                y += 16
                t(L("cu_informe_pie"), UIFont.italicSystemFont(ofSize: 9.5), .gray)
            }
            return url
        } catch { return nil }
    }
}
