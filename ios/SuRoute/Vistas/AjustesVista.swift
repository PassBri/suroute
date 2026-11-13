import SwiftUI
import UserNotifications

/// Ajustes (igual que Android, con lo propio de iPhone): idioma, dónde se abre la app, el recordatorio
/// del día y tu perfil (nombre, cumbre, nacimiento y meta de vida). La cuenta sigue en el perfil.
struct AjustesVista: View {
    @Environment(Almacen.self) private var a
    @Environment(\.openURL) private var abrir
    @AppStorage("abrir_en") private var abrirEn = "auto"
    @AppStorage("frase_modo") private var fraseModo = "toque"
    @State private var recActivo = Recordatorios.activo
    @State private var recHora = Recordatorios.hora
    @State private var sinPermiso = false
    @State private var nombre = ""
    @State private var cumbre = ""
    @State private var conFecha = false
    @State private var nacimiento = Fecha.cal.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
    @State private var esperanza = 100.0
    @State private var guardado = false

    var body: some View {
        Form {
            Section {
                Button { abrir(URL(string: UIApplication.openSettingsURLString)!) } label: {
                    LabeledContent(L("idioma"), value: Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "es")?.capitalizedPrimeraLetra ?? "")
                }
            } header: { Text(L("idioma")) } footer: { Text(L("ios_idioma_ayuda")) }

            Section {
                Picker(L("inicio_abrir_en"), selection: $abrirEn) {
                    Text(L("inicio_auto")).tag("auto")
                    Text(L("tab_hoy")).tag("hoy")
                    Text(L("tab_ruta")).tag("ruta")
                    Text(L("tab_comunidad")).tag("comunidad")
                }
            } footer: { Text(L("inicio_ayuda")) }

            Section {
                Picker(L("bloqueo_titulo"), selection: $fraseModo) {
                    Text(L("bloqueo_rostro")).tag("rostro")
                    Text(L("bloqueo_toque")).tag("toque")
                }
                NavigationLink(L("mis_frases")) { MisFrasesVista() }
            } footer: { Text(L("bloqueo_ayuda")) }

            Section {
                Toggle(L("recordatorio_ajuste"), isOn: $recActivo).tint(Tema.ok)
                if recActivo {
                    Picker(L("recordatorio_hora"), selection: $recHora) {
                        ForEach(Recordatorios.horas, id: \.self) { h in Text(String(format: "%02d:00", h)).tag(h) }
                    }
                    Button(L("recordatorio_probar")) { Task { await Recordatorios.probar(); await revisarPermiso() } }
                }
                if sinPermiso {
                    Button(L("ios_permiso_avisos")) { abrir(URL(string: UIApplication.openSettingsURLString)!) }.foregroundStyle(Tema.burdeos)
                }
            } header: { Text(L("recordatorio_titulo")) }

            Section(L("mi_perfil")) {
                TextField(L("tu_nombre"), text: $nombre).textContentType(.name)
                TextField(L("mi_cumbre_es"), text: $cumbre, axis: .vertical).lineLimit(2...4)
                Toggle(L("fecha_nacimiento"), isOn: $conFecha.animation()).tint(Tema.ok)
                if conFecha {
                    DatePicker(L("fecha_nacimiento"), selection: $nacimiento, in: ...Date(), displayedComponents: .date).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("esperanza_vida", Int(esperanza))).font(.subheadline.weight(.medium))
                    Slider(value: $esperanza, in: 60...120, step: 1).tint(Tema.burdeos)
                    Text(L("esperanza_ayuda", Vida.delPais)).font(.caption).foregroundStyle(Tema.tintaSuave)
                }
                Button { guardar() } label: { Label(guardado ? L("ios_guardado") : L("guardar"), systemImage: guardado ? "checkmark" : "square.and.arrow.down") }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section {
                NavigationLink { CartaBienvenidaVista(releer: true) } label: { Label(L("ios_releer_carta"), systemImage: "envelope.open") }
            } footer: {
                Text(L("acerca_texto", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
            }
        }
        .scrollContentBackground(.hidden)
        .fondoPapel()
        .navigationTitle(L("ajustes"))
        .onAppear(perform: cargar)
        .task { await revisarPermiso() }
        .onChange(of: recActivo) { _, v in Task { await Recordatorios.configurar(activo: v, hora: recHora); await revisarPermiso() } }
        .onChange(of: recHora) { _, h in Task { await Recordatorios.configurar(activo: recActivo, hora: h) } }
    }

    private func revisarPermiso() async {
        let estado = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        sinPermiso = recActivo && !Config.demo && estado == .denied
    }
    private func cargar() {
        let p = Perfil(a)
        nombre = p.nombre; cumbre = p.cumbre; esperanza = Double(p.esperanza)
        if let y = p.anioNacimiento, let f = Fecha.cal.date(from: DateComponents(year: y, month: p.mesNacimiento, day: 1)) { nacimiento = f; conFecha = true }
    }
    private func guardar() {
        let n = nombre.trimmingCharacters(in: .whitespacesAndNewlines), c = cumbre.trimmingCharacters(in: .whitespacesAndNewlines)
        var cambios: Doc = ["nombre": .texto(n), "cumbreFrase": .texto(c), "esperanzaVida": .entero(Int64(esperanza))]
        if conFecha {
            let comp = Fecha.cal.dateComponents([.year, .month], from: nacimiento)
            cambios["anioNacimiento"] = .entero(Int64(comp.year ?? 1990)); cambios["mesNacimiento"] = .entero(Int64(comp.month ?? 1))
        } else { cambios["anioNacimiento"] = .nulo; cambios["mesNacimiento"] = .nulo }
        a.cambiar("perfil", "1", cambios)
        // El nombre también se ve en la comunidad
        if let sb = Red.sb, let yo = Red.yo { Task { _ = try? await sb.from("profiles").update(["nombre": n]).eq("id", value: yo).execute() } }
        Task { await Recordatorios.programar() }
        guardado = true
        Task { try? await Task.sleep(for: .seconds(2)); guardado = false }
    }
}
