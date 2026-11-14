import SwiftUI
import AVFoundation
import Supabase

/// El audiolibro (igual que Android): si el autor grabó el capítulo (tabla `audios`), suena su voz;
/// si no, el iPhone lo lee con su propia voz, en el idioma del teléfono. Sigue sonando con la pantalla apagada.
@MainActor @Observable
final class Audiolibro: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Audiolibro()
    private(set) var activo: (guia: String, seccion: Int)?
    private(set) var sonando = false
    private(set) var deAutor = false
    var velocidad: Float = 1 { didSet { aplicarVelocidad() } }
    private let voz = AVSpeechSynthesizer()
    private var reproductor: AVPlayer?
    private var remotos: [String: String] = [:]
    private var cargado = false
    private var texto = ""

    override init() { super.init(); voz.delegate = self }

    func cargarRemotos() async {
        guard !cargado, let sb = Red.sb else { return }
        struct Fila: Decodable { let workbook_id: String; let seccion: Int; let url: String }
        let xs: [Fila] = (try? await sb.from("audios").select("workbook_id,seccion,url").limit(2000).execute().value) ?? []
        remotos = Dictionary(xs.map { ("\($0.workbook_id)/\($0.seccion)", $0.url) }, uniquingKeysWith: { a, _ in a }); cargado = true
    }
    func hayGrabacion(_ guia: String, _ seccion: Int) -> Bool { remotos["\(guia)/\(seccion)"] != nil }
    func esEste(_ guia: String, _ seccion: Int) -> Bool { activo?.guia == guia && activo?.seccion == seccion }

    func reproducir(guia: String, seccion: Int, texto: String) {
        detener()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        activo = (guia, seccion); sonando = true
        if let u = remotos["\(guia)/\(seccion)"].flatMap(URL.init(string:)) {
            deAutor = true
            let p = AVPlayer(url: u); reproductor = p; p.play(); p.rate = velocidad
        } else {
            deAutor = false; self.texto = texto
            hablar(texto)
        }
    }
    private func hablar(_ t: String) {
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
            ?? AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "es")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * min(1.6, max(0.6, velocidad))
        voz.speak(u)
    }
    func alternar() {
        if deAutor { if sonando { reproductor?.pause() } else { reproductor?.play(); reproductor?.rate = velocidad } }
        else if sonando { voz.pauseSpeaking(at: .word) } else { voz.continueSpeaking() }
        sonando.toggle()
    }
    func saltar(_ s: Double) {
        guard deAutor, let p = reproductor else { return }
        p.seek(to: CMTime(seconds: max(0, p.currentTime().seconds + s), preferredTimescale: 600))
    }
    func detener() {
        voz.stopSpeaking(at: .immediate); reproductor?.pause(); reproductor = nil
        activo = nil; sonando = false
    }
    private func aplicarVelocidad() {
        if deAutor { if sonando { reproductor?.rate = velocidad } }
        else if activo != nil && sonando, let a = activo { reproducir(guia: a.guia, seccion: a.seccion, texto: texto) }   // la voz del teléfono empieza de nuevo con la velocidad nueva
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.sonando = false; self.activo = nil }
    }

    /// El texto de un capítulo para leerlo en voz alta.
    static func texto(de bloques: [Bloque]) -> String {
        bloques.map { b -> String in
            var p: [String] = []
            for x in [b.title, b.text, b.label] { if let x, !x.isEmpty { p.append(x) } }
            if let o = b.options, ["list", "bullets", "checklist"].contains(b.type) { p += o }
            if let hijos = b.blocks { p.append(texto(de: hijos)) }
            return p.joined(separator: ". ")
        }
        .filter { !$0.isEmpty }.joined(separator: "\n")
        .replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "#", with: "")
    }
}

/// La barra del audiolibro en un capítulo: «Escuchar este capítulo» o, si ya suena, sus controles.
struct BarraAudio: View {
    let guia: String, seccion: Int, bloques: [Bloque]
    @State private var audio = Audiolibro.shared
    var body: some View {
        let t = Audiolibro.texto(de: bloques), minutos = max(1, t.split(separator: " ").count / 150)
        Group {
            if audio.esEste(guia, seccion) {
                HStack(spacing: 14) {
                    if audio.deAutor { Button { audio.saltar(-15) } label: { Image(systemName: "gobackward.15") }.accessibilityLabel(L("audio_atras")) }
                    Button { audio.alternar() } label: { Image(systemName: audio.sonando ? "pause.circle.fill" : "play.circle.fill").font(.title) }
                        .accessibilityLabel(L(audio.sonando ? "audio_pausar" : "audio_reanudar"))
                    if audio.deAutor { Button { audio.saltar(15) } label: { Image(systemName: "goforward.15") }.accessibilityLabel(L("audio_adelante")) }
                    Text(L(audio.deAutor ? "audio_voz_autor" : "audio_voz_app")).font(.caption).foregroundStyle(Tema.tintaSuave)
                    Spacer()
                    Menu {
                        ForEach([0.75, 1, 1.25, 1.5, 2] as [Float], id: \.self) { v in Button("\(v.formatted())×") { audio.velocidad = v } }
                    } label: { Text("\(audio.velocidad.formatted())×").font(.subheadline.monospacedDigit()) }
                        .accessibilityLabel(L("audio_velocidad_n", "\(audio.velocidad.formatted())×"))
                    Button { audio.detener() } label: { Image(systemName: "xmark") }.accessibilityLabel(L("audio_cerrar"))
                }
                .foregroundStyle(Tema.burdeos)
            } else {
                Button { audio.reproducir(guia: guia, seccion: seccion, texto: t) } label: {
                    Label(L("audio_escuchar_capitulo", minutos), systemImage: audio.hayGrabacion(guia, seccion) ? "waveform" : "headphones")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.oroSuave, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task { await audio.cargarRemotos() }
    }
}
