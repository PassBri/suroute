import SwiftUI

/// Libro de cumbres: como el libro que hay arriba en las montañas, aquí quedan firmadas tus llegadas.
/// Cada campamento con sus 8 pasos cumplidos y cada meta del mes cumplida es una página.
/// (Las cápsulas del mes y el libro del año en PDF siguen en Android y en SuRoute Web.)
struct LibroVista: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let _ = a.version
        let paginas = Pagina.todas(a)
        List {
            Section { Text(L("ios_libro_intro")).font(.footnote).foregroundStyle(Tema.tintaSuave) }
            if paginas.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(Tema.oro)
                        Text(L("ios_libro_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            }
            ForEach(paginas) { p in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: p.icono).font(.title3).foregroundStyle(p.color).frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.titulo).font(Tema.serif(.headline))
                        Text(p.detalle).font(.footnote).foregroundStyle(Tema.tintaSuave)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .fondoPapel()
        .navigationTitle(L("ios_libro"))
    }

    struct Pagina: Identifiable {
        let id: String, titulo: String, detalle: String, icono: String, color: Color, orden: String
        @MainActor static func todas(_ a: Almacen) -> [Pagina] {
            var r: [Pagina] = []
            for anio in [nil] + Brujula.anios(a).map(Optional.some) {
                let b = Brujula(a, anio: anio)
                for (i, c) in b.campamentos.enumerated() {
                    guard let c, b.cuenta(a, c).hechos == 8 else { continue }
                    let f = (0..<8).map { a.respuesta(Brujula.claveHecho(c.clave, $0)) }.max() ?? ""
                    r.append(Pagina(id: "c" + c.clave, titulo: Campamento.nombre(Campamento.fijos[i]) + (anio.map { " · \($0)" } ?? ""),
                                    detalle: L("ios_libro_campamento") + (f.isEmpty ? "" : " · " + f), icono: "flag.fill", color: Tema.eje(Campamento.fijos[i]), orden: f))
                }
            }
            for m in (a.docs["meta_mes"] ?? [:]).map({ MetaMes(d: $0.value, clave: $0.key) }) where m.cumplida || m.dias.count >= m.objetivo {
                let ym = String(format: "%04d-%02d", m.anio, m.mes)
                r.append(Pagina(id: "m" + m.clave, titulo: m.texto, detalle: Fecha.nombreMes(m.mes) + " \(m.anio) · " + L("dias_de", m.dias.count, m.objetivo),
                                icono: "checkmark.seal.fill", color: Tema.oro, orden: ym))
            }
            return r.sorted { $0.orden > $1.orden }
        }
    }
}
