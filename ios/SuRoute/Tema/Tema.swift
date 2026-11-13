import SwiftUI
import UIKit

/// El mundo de la marca en iPhone: papel, tinta, sello burdeos y oro viejo (los mismos tokens de
/// web/estilos.css), con su versión para el modo oscuro. La estructura es la de iOS.
enum Tema {
    static let fondo = Color.dinamico(0xEEF1F2, 0x0A0E12)
    static let hoja = Color.dinamico(0xFFFFFF, 0x161D23)
    static let hoja2 = Color.dinamico(0xF7F9F9, 0x0E1418)
    static let tinta = Color.dinamico(0x1D2427, 0xE8EDEF)
    static let tintaSuave = Color.dinamico(0x5A666B, 0x98A6AD)
    static let linea = Color.dinamico(0xDCE2E4, 0x243039)
    static let burdeos = Color.dinamico(0x6B2A1A, 0xF0B3A1)
    static let burdeosSuave = Color.dinamico(0xF3E3DC, 0x3A2420)
    static let oro = Color.dinamico(0x86683A, 0xC9AE84)
    static let oroSuave = Color.dinamico(0xF6EAD3, 0x2E2817)
    static let ok = Color.dinamico(0x3F7A4A, 0x86C792)
    /// Texto sobre un color lleno (burdeos, el color de un eje): blanco de día, tinta oscura de noche (los rellenos se aclaran).
    static let sobreColor = Color.dinamico(0xFFFFFF, 0x1A0F0C)

    static func eje(_ cod: String) -> Color {
        switch cod {
        case "VOL": return .dinamico(0x8E3B26, 0xE59A84)
        case "MAE": return .dinamico(0x5C4A8A, 0xB3A3E0)
        case "VOZ": return .dinamico(0x2F6F7A, 0x86C5CF)
        case "VAL": return .dinamico(0x6B5530, 0xD3B886)
        case "EVO": return .dinamico(0x3F7A4A, 0x8FCB98)
        case "TRA": return .dinamico(0x6B2A1A, 0xE8A28C)
        case "CON": return .dinamico(0x7A4A6B, 0xD39BC2)
        case "CAM": return .dinamico(0x4A5E7A, 0xA3B6D3)
        default: return burdeos
        }
    }

    /// Títulos de carta (los momentos humanos): la serif del sistema, como Roboto Serif en Android.
    static func serif(_ estilo: Font.TextStyle, _ peso: Font.Weight = .regular) -> Font { .system(estilo, design: .serif, weight: peso) }
}

extension Color {
    static func dinamico(_ claro: UInt32, _ oscuro: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: oscuro) : UIColor(hex: claro) })
    }
}
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Una hoja de papel sobre la mesa: el contenedor de las secciones (sombra suave, sin bordes gruesos).
struct Hoja<Contenido: View>: View {
    var relleno: CGFloat = 16
    @ViewBuilder var contenido: Contenido
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { contenido }
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

/// Barra de avance fina, con el color que se le dé.
struct Avance: View {
    var valor: Double
    var color: Color = Tema.burdeos
    var alto: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color).frame(width: max(alto, g.size.width * min(1, max(0, valor))))
            }
        }
        .frame(height: alto)
        .accessibilityValue(Text("\(Int(valor * 100)) %"))
    }
}

/// El fondo de todas las pantallas: la niebla de altura.
struct FondoPapel: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(Tema.fondo.ignoresSafeArea())
    }
}
extension View { func fondoPapel() -> some View { modifier(FondoPapel()) } }
