import SwiftUI
import Supabase
import LiveKit
import AVFoundation

/// Fogatas en vivo (igual que Android y la web): el registro vive en Supabase y el video en LiveKit.
/// Encender, entrar, el latido y apagar pasan por la función «fogata», que firma el permiso de LiveKit.
/// Quienes miran avivan la hoguera con leña, fósforos, piedras, chispas, café o una manta (mensajes de datos
/// {"t":"obj","k":…}); quien transmite manda el calor a todos cada 3 s ({"t":"calor","v","c","p"}).
struct Fogata: Identifiable, Hashable {
    let id: String, titulo: String, eje: String?, autorId: String, autor: String, avatar: String, empezo: Date
}
struct ConexionFogata: Identifiable { let fogata: Fogata; let url: String; let token: String; let anfitrion: Bool; var id: String { fogata.id } }

enum Fogatas {
    static let objetos = ["lena", "fosforo", "piedra", "chispa", "cafe", "manta"]
    static func calor(_ k: String) -> Double { k == "lena" ? 3 : (k == "fosforo" || k == "chispa") ? 2 : 1 }
    static func icono(_ k: String) -> String {
        switch k { case "lena": return "tree"; case "fosforo": return "flame"; case "piedra": return "mountain.2"; case "chispa": return "sparkle"; case "cafe": return "cup.and.saucer.fill"; default: return "heart.fill" }
    }

    private struct FilaF: Decodable {
        let id: String, titulo: String, eje: String?, user_id: String, empezo_at: String?
        let autor: Autor?
        func fogata(_ porDefecto: String = "") -> Fogata {
            Fogata(id: id, titulo: titulo, eje: eje, autorId: user_id,
                   autor: autor?.nombre?.isEmpty == false ? autor!.nombre! : (autor?.username ?? (porDefecto.isEmpty ? L("ios_senderista") : porDefecto)),
                   avatar: autor?.avatar_url ?? "", empezo: empezo_at.map(Red.fecha) ?? Date())
        }
    }
    /// Las fogatas encendidas ahora (con latido en los últimos 3 minutos).
    static func vivas() async -> [Fogata] {
        guard let sb = Red.sb, Red.yo != nil else { return [] }
        let desde = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-180))
        let xs: [FilaF] = (try? await sb.from("fogatas").select("id,titulo,eje,user_id,empezo_at,autor:profiles!fogatas_user_id_fkey(nombre,username,avatar_url)")
            .eq("estado", value: "EN_VIVO").gte("latido_at", value: desde).order("empezo_at", ascending: false).limit(12).execute().value) ?? []
        return xs.map { $0.fogata() }
    }
    static func puedeEncender() async -> Bool {
        guard let sb = Red.sb, Red.yo != nil else { return false }
        return (try? await sb.rpc("puede_encender").execute().value as Bool) ?? false
    }
    private struct Resp: Decodable { let error: String?; let fogata: FilaF?; let url: String?; let token: String?; let anfitrion: Bool? }
    private struct Pedido: Encodable { let accion: String; var id: String? = nil; var titulo: String? = nil; var eje: String? = nil; var personas: Int? = nil }
    private static func funcion<T: Decodable>(_ p: Pedido) async throws -> T {
        guard let sb = Red.sb else { throw URLError(.notConnectedToInternet) }
        return try await sb.functions.invoke("fogata", options: FunctionInvokeOptions(body: p))
    }
    private static func conexion(_ r: Resp, autor: String) throws -> ConexionFogata {
        if let e = r.error { throw NSError(domain: "fogata", code: 1, userInfo: [NSLocalizedDescriptionKey: e]) }
        guard let f = r.fogata, let url = r.url, let token = r.token else { throw URLError(.badServerResponse) }
        return ConexionFogata(fogata: f.fogata(autor), url: url, token: token, anfitrion: r.anfitrion ?? false)
    }
    static func encender(titulo: String, eje: String?, miNombre: String) async throws -> ConexionFogata {
        try conexion(try await funcion(Pedido(accion: "encender", titulo: titulo, eje: eje)), autor: miNombre)
    }
    static func entrar(_ f: Fogata) async throws -> ConexionFogata {
        let c = try conexion(try await funcion(Pedido(accion: "entrar", id: f.id)), autor: f.autor)
        return ConexionFogata(fogata: f, url: c.url, token: c.token, anfitrion: c.anfitrion)
    }
    struct Nada: Decodable {}
    static func latido(_ id: String, personas: Int) async { let _: Nada? = try? await funcion(Pedido(accion: "latido", id: id, personas: personas)) }
    static func apagar(_ id: String) async { let _: Nada? = try? await funcion(Pedido(accion: "apagar", id: id)) }
    static func llevo(_ id: String, _ texto: String) async {
        guard let sb = Red.sb, let yo = Red.yo else { return }
        _ = try? await sb.from("fogata_llevo").upsert(["fogata_id": id, "user_id": yo, "texto": String(texto.prefix(280))]).execute()
    }
    struct Llevo: Decodable { let texto: String; let autor: Autor? }
    static func llevaron(_ id: String) async -> [Llevo] {
        guard let sb = Red.sb else { return [] }
        return (try? await sb.from("fogata_llevo").select("texto,autor:profiles!fogata_llevo_user_id_fkey(nombre,username)").eq("fogata_id", value: id).order("created_at").execute().value) ?? []
    }
    static func reportar(_ f: Fogata, _ texto: String) async {
        guard let sb = Red.sb, let yo = Red.yo else { return }
        _ = try? await sb.from("reportes").insert(["quien": yo, "a_quien": f.autorId, "motivo": String("Fogata en vivo «\(f.titulo)» (\(f.id)): \(texto)".prefix(1000))]).execute()
    }
}

/// La franja «En vivo» arriba del muro: las fogatas encendidas ahora y, si se puede, encender una.
struct FranjaFogatas: View {
    @Binding var abierta: ConexionFogata?
    @State private var vivas: [Fogata] = []
    @State private var puede = false
    @State private var encendiendo = false
    @State private var entrando: String?
    @State private var error = false
    var body: some View {
        Group {
            if !vivas.isEmpty || puede {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if puede {
                            Button { encendiendo = true } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "flame.fill").font(.title2).foregroundStyle(Tema.oro)
                                    Text(L("fg_encender_t")).font(.caption.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(Tema.tinta)
                                }
                                .frame(width: 110, height: 96).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(vivas) { f in
                            Button { Task { await entrar(f) } } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Circle().fill(.red).frame(width: 7, height: 7)
                                        Text(L("fg_vivo").uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.red)
                                        Spacer()
                                        if entrando == f.id { ProgressView().controlSize(.small) }
                                    }
                                    Text(f.titulo).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    HStack(spacing: 6) { Avatar(url: f.avatar, nombre: f.autor, tam: 20); Text(f.autor).font(.caption).foregroundStyle(Tema.tintaSuave).lineLimit(1) }
                                }
                                .padding(12).frame(width: 190, height: 96, alignment: .topLeading)
                                .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder((f.eje.map { Tema.eje($0) } ?? Tema.oro).opacity(0.35)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(L("fg_vivo") + ": " + f.titulo + ", " + f.autor))
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
        .task { await cargar() }
        .sheet(isPresented: $encendiendo) { EncenderFogata { c in encendiendo = false; abierta = c } }
        .alert(L("fg_error"), isPresented: $error) { Button(L("listo")) {} }
    }
    func cargar() async { vivas = await Fogatas.vivas(); puede = await Fogatas.puedeEncender() }
    private func entrar(_ f: Fogata) async {
        entrando = f.id; defer { entrando = nil }
        do { abierta = try await Fogatas.entrar(f) } catch { self.error = true }
    }
}

/// Encender: el tema y el eje. Pide cámara y micrófono.
private struct EncenderFogata: View {
    let listo: (ConexionFogata) -> Void
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var titulo = ""
    @State private var eje: String? = nil
    @State private var ocupado = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(L("fg_encender_d")).font(.footnote).foregroundStyle(Tema.tintaSuave) }
                Section(L("fg_tema")) { TextField(L("fg_tema_ej"), text: $titulo, axis: .vertical).lineLimit(1...3) }
                Section {
                    Picker(L("cordadas_eje"), selection: $eje) {
                        Text(L("fg_sin_eje")).tag(String?.none)
                        ForEach(Eje.allCases) { e in Text(e.nombre).tag(String?.some(e.rawValue)) }
                    }
                } footer: { if let error { Text(error).foregroundStyle(Tema.burdeos) } }
            }
            .navigationTitle(L("fg_encender_t"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await encender() } } label: { if ocupado { ProgressView() } else { Text(L("fg_encender")).bold() } }
                        .disabled(titulo.trimmingCharacters(in: .whitespaces).count < 3 || ocupado)
                }
            }
        }
    }
    private func encender() async {
        ocupado = true; defer { ocupado = false }
        let cam = await AVCaptureDevice.requestAccess(for: .video), mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard cam && mic else { error = L("fg_permiso"); return }
        do { listo(try await Fogatas.encender(titulo: titulo.trimmingCharacters(in: .whitespaces), eje: eje, miNombre: Perfil(a).nombre)) }
        catch { self.error = L("fg_error") }
    }
}

/// La sala: el video, la hoguera que crece con lo que da la comunidad y, para quien transmite, sus controles.
@MainActor
final class SalaFogata: NSObject, ObservableObject, RoomDelegate {
    let c: ConexionFogata
    let room = Room()
    @Published var video: VideoTrack?
    @Published var personas = 1
    @Published var calor: Double
    @Published var cuenta: [String: Int] = [:]
    @Published var suben: [Sube] = []
    @Published var conectada = false
    @Published var terminada = false
    @Published var error = false
    @Published var mic = true
    @Published var cam = true
    var piedraHasta: Double = 0
    private var reloj: Timer?
    private var latido: Timer?
    private var envio = Date.distantPast
    private var inicio = Date()
    var minutos: Int { max(1, Int(Date().timeIntervalSince(inicio) / 60)) }
    var luces: Int { cuenta.values.reduce(0, +) }
    struct Sube: Identifiable { let id = UUID(); let k: String; let x: CGFloat }

    init(_ c: ConexionFogata) { self.c = c; calor = c.anfitrion ? 6 : 0; super.init(); room.add(delegate: self) }

    func conectar() async {
        do {
            try await room.connect(url: c.url, token: c.token)
            conectada = true
            personas = room.remoteParticipants.count + 1
            if c.anfitrion {
                try await room.localParticipant.setCamera(enabled: true)
                try await room.localParticipant.setMicrophone(enabled: true)
                video = room.localParticipant.firstCameraVideoTrack
                latido = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    Task { @MainActor in guard let self else { return }; await Fogatas.latido(self.c.id, personas: self.personas) }
                }
            } else {
                video = room.remoteParticipants.values.compactMap { $0.firstCameraVideoTrack }.first
            }
        } catch { self.error = true }
        // El fuego se enfría cada segundo; quien transmite comparte el calor cada 3 s
        reloj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tic() } }
    }
    private func tic() {
        let cuida = Date().timeIntervalSince1970 * 1000 < piedraHasta
        calor = max(0, calor * (cuida ? 0.995 : 0.985) - (cuida ? 0.01 : 0.03))
        if c.anfitrion && Date().timeIntervalSince(envio) > 3 {
            envio = Date()
            enviar(["t": "calor", "v": calor, "c": cuenta, "p": piedraHasta])
        }
    }
    func salir() async {
        reloj?.invalidate(); latido?.invalidate()
        await room.disconnect()
    }
    private func enviar(_ o: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: o) else { return }
        Task { try? await room.localParticipant.publish(data: d, options: DataPublishOptions(reliable: true)) }
    }
    func dar(_ k: String) { subir(k); enviar(["t": "obj", "k": k]) }
    private func subir(_ k0: String) {
        let k = Fogatas.objetos.contains(k0) ? k0 : "lena"
        cuenta[k, default: 0] += 1
        calor = min(48, calor + Fogatas.calor(k))
        if k == "piedra" { piedraHasta = Date().timeIntervalSince1970 * 1000 + 20_000 }
        suben.append(Sube(k: k, x: CGFloat.random(in: -60...60)))
        if suben.count > 24 { suben.removeFirst() }
    }
    func alternarMic() { mic.toggle(); let m = mic; Task { try? await room.localParticipant.setMicrophone(enabled: m) } }
    func alternarCam() { cam.toggle(); let v = cam; Task { try? await room.localParticipant.setCamera(enabled: v) } }
    func girar() {
        Task { if let t = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack, let cap = t.capturer as? CameraCapturer { _ = try? await cap.switchCameraPosition() } }
    }

    // MARK: RoomDelegate
    private var ultimoDato = (Data(), Date.distantPast)
    private func recibir(_ data: Data) {
        // Algunas versiones del SDK avisan por dos caminos: se cuenta una sola vez
        if ultimoDato.0 == data && Date().timeIntervalSince(ultimoDato.1) < 0.05 { return }
        ultimoDato = (data, Date())
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        switch o["t"] as? String {
        case "obj": subir(o["k"] as? String ?? "lena")
        case "calor":
            guard !c.anfitrion else { return }
            calor = (o["v"] as? Double) ?? calor
            piedraHasta = (o["p"] as? Double) ?? 0
            if let m = o["c"] as? [String: Int] { cuenta = m }
        default: break
        }
    }
    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        Task { @MainActor in self.recibir(data) }
    }
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in if let v = publication.track as? VideoTrack { self.video = v } }
    }
    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in self.personas = room.remoteParticipants.count + 1 }
    }
    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.personas = room.remoteParticipants.count + 1
            if participant.identity?.stringValue == self.c.fogata.autorId { self.terminada = true }
        }
    }
    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in self.terminada = true }
    }
}

/// El video de LiveKit dentro de SwiftUI.
private struct VideoLK: UIViewRepresentable {
    let track: VideoTrack?
    var espejo = false
    func makeUIView(context: Context) -> VideoView { let v = VideoView(); v.layoutMode = .fill; return v }
    func updateUIView(_ v: VideoView, context: Context) { v.track = track; v.mirrorMode = espejo ? .mirror : .off }
}

struct FogataVivoVista: View {
    @StateObject private var sala: SalaFogata
    @Environment(\.dismiss) private var cerrar
    @State private var preguntarApagar = false
    @State private var reportando = false
    @State private var textoReporte = ""
    @State private var llevar = false
    @State private var llevo = ""
    @State private var resumen = false
    @State private var llevaron: [Fogatas.Llevo] = []
    init(c: ConexionFogata) { _sala = StateObject(wrappedValue: SalaFogata(c)) }

    var body: some View {
        let f = sala.c.fogata
        ZStack {
            Color(red: 0.06, green: 0.05, blue: 0.08).ignoresSafeArea()
            if let v = sala.video { VideoLK(track: v, espejo: sala.c.anfitrion).ignoresSafeArea().opacity(sala.c.anfitrion && !sala.cam ? 0 : 1) }
            else { VStack(spacing: 10) { ProgressView().tint(.white); Text(L("fg_esperando")).foregroundStyle(.white.opacity(0.8)) } }
            // Lo que suben los que miran
            ForEach(sala.suben) { s in Subiendo(k: s.k, x: s.x) }
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(L("fg_vivo").uppercased()).font(.caption2.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 3).background(.red, in: Capsule()).foregroundStyle(.white)
                            Label("\(sala.personas)", systemImage: "eye").font(.caption.weight(.semibold)).foregroundStyle(.white)
                                .accessibilityLabel(Text(L("fg_personas") + " \(sala.personas)"))
                        }
                        Text(f.titulo).font(Tema.serif(.headline)).foregroundStyle(.white).lineLimit(2)
                        Text(f.autor).font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    if !sala.c.anfitrion {
                        Menu {
                            Button(L("fg_reportar"), systemImage: "flag") { reportando = true }
                        } label: { Image(systemName: "ellipsis").foregroundStyle(.white).frame(width: 40, height: 40).background(.black.opacity(0.35), in: Circle()) }
                    }
                    Button { if sala.c.anfitrion { preguntarApagar = true } else { Task { await sala.salir(); llevar = true } } } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(.white).frame(width: 40, height: 40).background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel(L(sala.c.anfitrion ? "fg_apagar" : "fg_salir"))
                }
                .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
                // La hoguera
                HStack(spacing: 8) {
                    Image(systemName: sala.calor < 1 ? "smoke" : "flame.fill").font(.system(size: 18 + min(18, sala.calor / 2)))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                    ProgressView(value: min(48, sala.calor), total: 48).tint(.orange)
                    Text(sala.calor < 1 ? L("fo_brasas") : L("fo_arde", Int(sala.calor / 48 * 100))).font(.caption2).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                }
                .padding(.horizontal, 16)
                if sala.c.anfitrion {
                    HStack(spacing: 22) {
                        Control(icono: sala.mic ? "mic.fill" : "mic.slash.fill", nombre: L("fg_mic")) { sala.alternarMic() }
                        Control(icono: sala.cam ? "video.fill" : "video.slash.fill", nombre: L("fg_cam")) { sala.alternarCam() }
                        Control(icono: "arrow.triangle.2.circlepath.camera", nombre: L("fg_girar")) { sala.girar() }
                    }
                    .padding(.vertical, 10)
                } else {
                    HStack(spacing: 8) {
                        ForEach(Fogatas.objetos, id: \.self) { k in
                            Button { sala.dar(k) } label: {
                                Image(systemName: Fogatas.icono(k)).font(.title3).foregroundStyle(.white).frame(width: 48, height: 48).background(.white.opacity(0.14), in: Circle())
                            }
                            .accessibilityLabel(L("fo_" + k))
                        }
                    }
                    .padding(.vertical, 10)
                    .sensoryFeedback(.impact(weight: .light), trigger: sala.luces)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .task { UIApplication.shared.isIdleTimerDisabled = true; await sala.conectar() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; Task { await sala.salir() } }
        .onChange(of: sala.terminada) { _, t in if t && !sala.c.anfitrion && !llevar { llevar = true } }
        .alert(L("fg_error"), isPresented: $sala.error) { Button(L("listo")) { cerrar() } }
        .confirmationDialog(L("fg_apagar_t"), isPresented: $preguntarApagar, titleVisibility: .visible) {
            Button(L("fg_apagar_si"), role: .destructive) {
                Task { await Fogatas.apagar(sala.c.id); await sala.salir(); llevaron = await Fogatas.llevaron(sala.c.id); resumen = true }
            }
            Button(L("fg_seguir"), role: .cancel) {}
        } message: { Text(L("fg_apagar_d")) }
        .alert(L("fg_reportar"), isPresented: $reportando) {
            TextField(L("fg_reportar_ph"), text: $textoReporte)
            Button(L("cancelar"), role: .cancel) {}
            Button(L("enviar")) { Task { await Fogatas.reportar(f, textoReporte) } }
        }
        .sheet(isPresented: $llevar, onDismiss: { cerrar() }) {
            NavigationStack {
                Form {
                    Section { Text(L("fg_llevo_d", f.autor)).font(.subheadline) }
                    Section { TextField(L("fg_llevo_ph"), text: $llevo, axis: .vertical).lineLimit(2...5) } footer: { Text(L("fg_llevo_nota", f.autor)) }
                }
                .navigationTitle(L("fg_llevo_t")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("fg_ahora_no")) { llevar = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L("fg_llevo_btn")) { Task { await Fogatas.llevo(f.id, llevo); llevar = false } }.disabled(llevo.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $resumen, onDismiss: { cerrar() }) {
            NavigationStack {
                List {
                    Section { Text(L("fg_resumen_d", sala.minutos, sala.luces)) }
                    Section(L("fo_recibio")) {
                        if sala.cuenta.isEmpty { Text(L("fo_nadie")).foregroundStyle(Tema.tintaSuave) }
                        ForEach(Fogatas.objetos.filter { (sala.cuenta[$0] ?? 0) > 0 }, id: \.self) { k in
                            Label("\(L("fo_" + k)) · \(sala.cuenta[k] ?? 0)", systemImage: Fogatas.icono(k))
                        }
                    }
                    Section(L("fg_llevaron")) {
                        if llevaron.isEmpty { Text(L("fg_llevaron_vacio")).foregroundStyle(Tema.tintaSuave) }
                        ForEach(Array(llevaron.enumerated()), id: \.offset) { _, x in
                            VStack(alignment: .leading) { Text(x.autor?.nombre ?? x.autor?.username ?? "").font(.footnote.weight(.semibold)); Text(x.texto) }
                        }
                    }
                }
                .navigationTitle(L("fg_resumen_t")).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(L("listo")) { resumen = false } }
            }
        }
    }
}

private struct Control: View {
    let icono: String, nombre: String, accion: () -> Void
    var body: some View {
        Button(action: accion) { Image(systemName: icono).font(.title3).foregroundStyle(.white).frame(width: 52, height: 52).background(.white.opacity(0.16), in: Circle()) }
            .accessibilityLabel(nombre)
    }
}

/// Un objeto que sube por la pantalla y se desvanece.
private struct Subiendo: View {
    let k: String, x: CGFloat
    @State private var arriba = false
    var body: some View {
        Image(systemName: Fogatas.icono(k)).font(.title).foregroundStyle(.orange)
            .offset(x: x, y: arriba ? -320 : 180).opacity(arriba ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 2.4)) { arriba = true } }
            .allowsHitTesting(false)
    }
}
