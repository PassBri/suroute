import SwiftUI
import Foundation
import Supabase

/// Comunidad viva (igual que Android y la web): aquí no se premia la atención sino el avance real.
/// Cada publicación puede traer el camino que hay detrás (racha y pasos ganados de la Brújula), un compromiso
/// con fecha, una carta sellada que se abre en una fecha y el paso a paso de una meta lograda (columnas
/// camino, compromiso, sello y pasos de posts). Las reacciones son luces (votes.luz).
@MainActor
enum ComunidadViva {
    static let luces = ["vela", "fogata", "estrella", "fugaz", "luna", "sol"]
    static func iconoLuz(_ k: String) -> String {
        switch k {
        case "vela": return "flame"; case "fogata": return "flame.fill"; case "estrella": return "star.fill"
        case "fugaz": return "sparkle"; case "luna": return "moon.fill"; default: return "sun.max.fill"
        }
    }
    static var ultimaLuz: String {
        get { let k = UserDefaults.standard.string(forKey: "luz_ultima") ?? "sol"; return luces.contains(k) ? k : "sol" }
        set { UserDefaults.standard.set(newValue, forKey: "luz_ultima") }
    }

    /// El camino de hoy: días seguidos con hábitos y los pasos ganados de la Brújula general (mapa de 64).
    static func caminoActual(_ a: Almacen) -> Doc {
        var dias: Set<String> = []
        for (f, d) in a.docs["checklist"] ?? [:] where !d.t("marcados").isEmpty { dias.insert(f) }
        var d = Date(), racha = 0
        if !dias.contains(Fecha.iso(d)) { d = Fecha.cal.date(byAdding: .day, value: -1, to: d)! }
        while dias.contains(Fecha.iso(d)) { racha += 1; d = Fecha.cal.date(byAdding: .day, value: -1, to: d)! }
        let b = Brujula(a, anio: nil)
        var mapa = ""
        for c in b.campamentos { for p in 0..<8 { mapa += (c.map { b.hecho(a, $0, p) } ?? false) ? "1" : "0" } }
        let ganados = mapa.filter { $0 == "1" }.count
        var r: Doc = ["racha": .entero(Int64(racha)), "ganados": .entero(Int64(ganados))]
        if mapa.contains("1") { r["mapa"] = .texto(mapa) }
        return r
    }

    /// Sellada para quien no es el autor, hasta la fecha en que se abre.
    static func sellada(_ p: Post) -> Bool { p.user_id != Red.yo && (p.selloAbre.map { Fecha.iso() < $0 } ?? false) }

    static func cerrarCompromiso(_ p: Post, _ estado: String) async {
        guard let sb = Red.sb, let yo = Red.yo, var k = p.compromisoDoc else { return }
        k["estado"] = .texto(estado)
        struct Fila: Encodable { let compromiso: Doc }
        _ = try? await sb.from("posts").update(Fila(compromiso: k)).eq("id", value: p.id).eq("user_id", value: yo).execute()
    }

    /// Mi luz en cada publicación (si aún no existe la columna luz, cada impulso cuenta como sol).
    static func misLuces(_ ids: [String]) async -> [String: String] {
        guard let sb = Red.sb, let yo = Red.yo, !ids.isEmpty else { return [:] }
        struct V: Decodable { let post_id: String; let luz: String? }
        if let xs: [V] = try? await sb.from("votes").select("post_id,luz").eq("user_id", value: yo).in("post_id", values: ids).execute().value {
            return Dictionary(xs.map { ($0.post_id, $0.luz ?? "sol") }, uniquingKeysWith: { a, _ in a })
        }
        return Dictionary((await Red.misImpulsos(ids)).map { ($0, "sol") }, uniquingKeysWith: { a, _ in a })
    }
    /// Dar (o quitar con nil) una luz.
    static func darLuz(_ post: String, _ luz: String?) async throws {
        guard let sb = Red.sb, let yo = Red.yo else { return }
        try await sb.from("votes").delete().eq("post_id", value: post).eq("user_id", value: yo).execute()
        guard let luz else { return }
        ultimaLuz = luz
        do { try await sb.from("votes").insert(["post_id": post, "user_id": yo, "luz": luz]).execute() }
        catch { try await sb.from("votes").insert(["post_id": post, "user_id": yo]).execute() }
    }
}

extension Post {
    private func obj(_ v: Valor?) -> Doc? {
        guard let v else { return nil }
        if case .objeto(let o) = v { return o }
        if case .texto(let s) = v, s.hasPrefix("{"), let d = s.data(using: .utf8) { return try? JSONDecoder().decode(Doc.self, from: d) }
        return nil
    }
    var caminoDoc: Doc? { obj(camino) }
    var compromisoDoc: Doc? { obj(compromiso) }
    var selloAbre: String? { obj(sello)?["abre"]?.texto }
    var pasoAPaso: (meta: String, pasos: [(t: String, f: String, d: String)])? {
        guard let o = obj(pasos), let l = o["pasos"]?.lista else { return nil }
        let ps = l.compactMap { v -> (String, String, String)? in
            guard case .objeto(let x) = v, let t = x["t"]?.texto, !t.isEmpty else { return nil }
            return (t, x["f"]?.texto ?? "", x["d"]?.texto ?? "")
        }
        return ps.isEmpty ? nil : (o["meta"]?.texto ?? "", ps.map { (t: $0.0, f: $0.1, d: $0.2) })
    }
}

/// La carta al yo futuro, cerrada para los demás hasta su fecha.
struct CartaSellada: View {
    let abre: String
    var body: some View {
        let f = Fecha.de(abre) ?? Date(), faltan = max(0, Fecha.cal.dateComponents([.day], from: Fecha.cal.startOfDay(for: Date()), to: f).day ?? 0)
        HStack(spacing: 14) {
            Image("Sello").resizable().scaledToFit().frame(width: 54, height: 54).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("cv_carta_titulo")).font(Tema.serif(.headline))
                Text(L("cv_se_abre_faltan", f.formatted(date: .long, time: .omitted), faltan)).font(.caption).foregroundStyle(Tema.tintaSuave)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.oroSuave, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// El camino que hay detrás: días de constancia, pasos ganados y la mini-Brújula de 64.
struct CaminoFila: View {
    let c: Doc
    var body: some View {
        let racha = c.i("racha") ?? 0, ganados = c.i("ganados") ?? 0, mapa = Array(c.t("mapa"))
        HStack(spacing: 10) {
            if mapa.count == 64 {
                Grid(horizontalSpacing: 1.5, verticalSpacing: 1.5) {
                    ForEach(0..<8, id: \.self) { i in
                        GridRow { ForEach(0..<8, id: \.self) { p in Circle().fill(mapa[i * 8 + p] == "1" ? Tema.eje(Campamento.fijos[i]) : Tema.linea).frame(width: 3.5, height: 3.5) } }
                    }
                }
                .accessibilityHidden(true)
            }
            Text([racha > 0 ? L("cv_dia_constancia", racha) : nil, ganados > 0 ? L("cv_pasos", ganados) : nil].compactMap { $0 }.joined(separator: " · "))
                .font(.caption.weight(.medium)).foregroundStyle(Tema.tintaSuave)
        }
    }
}

/// Un compromiso con fecha: faltan N días, cumplido o replanteado; al autor, al vencer, le pregunta cómo le fue.
struct CompromisoFila: View {
    let post: Post, k: Doc
    @State private var estado: String?
    var body: some View {
        let e = estado ?? k.t("estado"), hasta = k.t("hasta"), hoy = Fecha.iso()
        let faltan = Fecha.de(hasta).map { max(0, Fecha.cal.dateComponents([.day], from: Fecha.cal.startOfDay(for: Date()), to: $0).day ?? 0) } ?? 0
        VStack(alignment: .leading, spacing: 6) {
            if e == "LOGRADO" { Label(L("cv_compromiso_cumplido"), systemImage: "checkmark.seal.fill").foregroundStyle(Tema.ok) }
            else if e == "REPLANTEO" { Label(L("cv_replanteo"), systemImage: "arrow.triangle.2.circlepath").foregroundStyle(Tema.tintaSuave) }
            else if hoy < hasta { Label(L("cv_compromiso_faltan", faltan), systemImage: "calendar.badge.clock").foregroundStyle(Tema.oro) }
            else if hoy == hasta { Label(L("cv_compromiso_hoy"), systemImage: "calendar.badge.exclamationmark").foregroundStyle(Tema.burdeos) }
            else if post.user_id == Red.yo {
                Text(L("cv_vencio_propio")).foregroundStyle(Tema.burdeos)
                HStack {
                    Button(L("cv_lo_logre")) { cerrar("LOGRADO") }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                    Button(L("cv_lo_replanteo")) { cerrar("REPLANTEO") }.buttonStyle(.bordered)
                }
            } else { Label(L("cv_vencio_esperando"), systemImage: "hourglass").foregroundStyle(Tema.tintaSuave) }
        }
        .font(.caption.weight(.medium))
    }
    private func cerrar(_ x: String) { estado = x; Task { await ComunidadViva.cerrarCompromiso(post, x) } }
}

/// El paso a paso de una meta lograda: de la salida a la cumbre.
struct PasoAPasoTarjeta: View {
    let meta: String
    let pasos: [(t: String, f: String, d: String)]
    var completa = false
    @State private var abierto = false
    var body: some View {
        let ver = completa || abierto ? pasos : Array(pasos.prefix(3))
        VStack(alignment: .leading, spacing: 8) {
            Label(L("pap_como"), systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.caption.weight(.semibold)).foregroundStyle(Tema.oro)
            ForEach(Array(ver.enumerated()), id: \.offset) { i, p in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle().fill(i == 0 ? Tema.tintaSuave : Tema.oro).frame(width: 9, height: 9).padding(.top, 4)
                        if i < ver.count - 1 { Rectangle().fill(Tema.linea).frame(width: 2) }
                    }
                    .frame(width: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.t).font(.subheadline)
                        if !p.f.isEmpty { Text(p.f).font(.caption2.monospacedDigit()).foregroundStyle(Tema.tintaSuave) }
                        if !p.d.isEmpty { Text(p.d).font(.caption).foregroundStyle(Tema.tintaSuave) }
                    }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "flag.fill").foregroundStyle(Tema.burdeos).frame(width: 10)
                Text(meta.isEmpty ? L("pap_cumbre_sola") : L("pap_cumbre", meta)).font(.subheadline.weight(.semibold))
            }
            if !completa && pasos.count > 3 && !abierto {
                Button(L("pap_ver_todos", pasos.count)) { withAnimation { abierto = true } }.font(.caption)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.hoja2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
