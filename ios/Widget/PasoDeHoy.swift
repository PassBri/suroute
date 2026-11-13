import WidgetKit
import SwiftUI

/// «Tu paso de hoy»: los hábitos marcados hoy y el siguiente que falta, en la pantalla de inicio y la de bloqueo.
struct Entrada: TimelineEntry { let date: Date; let r: ResumenWidget? }

struct Proveedor: TimelineProvider {
    func placeholder(in context: Context) -> Entrada { Entrada(date: Date(), r: ResumenWidget(hechos: 3, total: 18, cumbre: "Vivir con salud y propósito", siguiente: "", fecha: "")) }
    func getSnapshot(in context: Context, completion: @escaping (Entrada) -> Void) { completion(Entrada(date: Date(), r: ResumenWidget.leer() ?? placeholder(in: context).r)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entrada>) -> Void) {
        // Se renueva a medianoche (el día nuevo empieza en cero)
        let manana = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [Entrada(date: Date(), r: ResumenWidget.leer())], policy: .after(manana)))
    }
}

struct VistaPaso: View {
    @Environment(\.widgetFamily) private var familia
    let e: Entrada
    private let burdeos = Color(red: 0.42, green: 0.16, blue: 0.10)
    var body: some View {
        let hoy = { () -> String in let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }()
        let r = e.r, hechos = r?.fecha == hoy ? (r?.hechos ?? 0) : 0, total = max(1, r?.total ?? 18)
        switch familia {
        case .accessoryCircular:
            Gauge(value: Double(hechos), in: 0...Double(total)) { Image(systemName: "mountain.2") } currentValueLabel: { Text("\(hechos)") }
                .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "checklist_hoy")).font(.headline)
                Text("\(hechos) / \(total)").font(.title3.monospacedDigit())
                if let s = r?.siguiente, !s.isEmpty, hechos < total { Text(s).font(.caption).lineLimit(1) }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "mountain.2.fill").foregroundStyle(burdeos)
                    Spacer()
                    Text("\(hechos)/\(total)").font(.headline.monospacedDigit())
                }
                ProgressView(value: Double(hechos), total: Double(total)).tint(burdeos)
                if familia != .systemSmall, let c = r?.cumbre, !c.isEmpty {
                    Text(c).font(.system(.subheadline, design: .serif)).lineLimit(2)
                }
                Spacer(minLength: 0)
                if let s = r?.siguiente, !s.isEmpty, hechos < total {
                    Text(s).font(.caption).foregroundStyle(.secondary).lineLimit(familia == .systemSmall ? 3 : 2)
                } else if hechos >= total {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(burdeos)
                }
            }
        }
    }
}

@main
struct PasoDeHoy: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PasoDeHoy", provider: Proveedor()) { e in
            VistaPaso(e: e).containerBackground(for: .widget) { Color(UIColor.systemBackground) }
        }
        .configurationDisplayName("SuRoute")
        .description(String(localized: "checklist_hoy"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
