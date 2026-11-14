import SwiftUI
import Contacts
import CryptoKit
import Supabase

/// Agregar contactos (igual que Android y la web): revisar quién de la agenda ya está en SuRoute sin que los números
/// ni los correos salgan del teléfono (solo viajan huellas SHA-256 "suroute|tel|3001234567"), dejar que me encuentren
/// e invitar al resto con el enlace.
enum Huella {
    static func tel(_ t: String) -> String? { let d = t.filter(\.isNumber); return d.count >= 7 ? String(d.suffix(10)) : nil }
    static func correo(_ c: String) -> String? { let x = c.trimmingCharacters(in: .whitespaces).lowercased(); return x.contains("@") ? x : nil }
    static func de(_ tipo: String, _ v: String) -> String {
        SHA256.hash(data: Data("suroute|\(tipo)|\(v)".utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct ContactosVista: View {
    struct Agenda: Identifiable { let id = UUID(); let nombre: String; let telefono: String; let correo: String; let huellas: [String] }
    struct Encontrado: Decodable, Identifiable { let hash: String; let id: String; let nombre: String?; let username: String?; let avatar_url: String?; let cumbre: String? }
    @State private var encontrable = false
    @State private var tel = ""
    @State private var revisando = false
    @State private var encontrados: [Encontrado] = []
    @State private var invitar: [Agenda] = []
    @State private var revisado = false
    @State private var aviso: String?
    @State private var usuario = ""
    @Environment(\.openURL) private var abrir
    var enlace: URL { URL(string: usuario.isEmpty ? "https://suroute.com/descargar.html" : "https://suroute.com/?invita=" + (usuario.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? usuario))! }
    var invitacion: String { L("contactos_invitacion", enlace.absoluteString) }

    var body: some View {
        List {
            Section { Text(L("contactos_sub")).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
            if Red.yo == nil || Config.demo {
                Section { Text(L("contactos_sin_cuenta")).foregroundStyle(Tema.tintaSuave) }
            } else {
                Section {
                    Toggle(L("contactos_encontrable"), isOn: $encontrable).tint(Tema.ok)
                    if encontrable {
                        TextField(L("contactos_tu_numero"), text: $tel).keyboardType(.phonePad)
                        Button(L("contactos_guardar")) { Task { await guardarEncontrable() } }
                    }
                } footer: { Text(L("contactos_encontrable_texto")) }
                Section {
                    Button { Task { await revisar() } } label: { Label(L("contactos_revisar"), systemImage: "person.crop.circle.badge.checkmark") }.disabled(revisando)
                    if revisando { ProgressView() }
                    if let aviso { Text(aviso).font(.footnote).foregroundStyle(Tema.burdeos) }
                } header: { Text(L("contactos_telefono")) } footer: { Text(L("contactos_telefono_texto")) }
                if revisado {
                    Section(L("contactos_encontrados", encontrados.count)) {
                        if encontrados.isEmpty { Text(L("contactos_ninguno")).foregroundStyle(Tema.tintaSuave) }
                        ForEach(encontrados) { p in
                            NavigationLink(value: Destino.persona(p.id)) {
                                HStack(spacing: 12) {
                                    Avatar(url: p.avatar_url, nombre: p.nombre ?? p.username ?? "?", tam: 40)
                                    VStack(alignment: .leading) {
                                        Text(p.nombre?.isEmpty == false ? p.nombre! : (p.username ?? "")).font(.subheadline.weight(.semibold))
                                        if let c = p.cumbre, !c.isEmpty { Text(c).font(.caption).foregroundStyle(Tema.tintaSuave).lineLimit(1) }
                                    }
                                }
                            }
                        }
                    }
                    if !invitar.isEmpty {
                        Section(L("contactos_invitalos")) {
                            ForEach(invitar.prefix(200)) { c in
                                HStack {
                                    VStack(alignment: .leading) { Text(c.nombre); Text(c.telefono.isEmpty ? c.correo : c.telefono).font(.caption).foregroundStyle(Tema.tintaSuave) }
                                    Spacer()
                                    Button(L("contactos_invitar")) { invitarA(c) }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                ShareLink(item: invitacion) { Label(L("contactos_mas"), systemImage: "square.and.arrow.up") }
                Button { UIPasteboard.general.string = enlace.absoluteString; aviso = L("contactos_copiado") } label: { Label(L("contactos_copiar"), systemImage: "doc.on.doc") }
            } header: { Text(L("contactos_redes")) } footer: { Text(L("contactos_redes_texto")) }
        }
        .fondoPapel()
        .navigationTitle(L("contactos_titulo"))
        .task {
            guard let sb = Red.sb, let yo = Red.yo else { return }
            let e: Bool? = try? await sb.rpc("soy_encontrable").execute().value
            encontrable = e ?? false
            struct U: Decodable { let username: String? }
            let u: [U]? = try? await sb.from("profiles").select("username").eq("id", value: yo).execute().value
            usuario = u?.first?.username ?? ""
        }
    }

    private func guardarEncontrable() async {
        struct P: Encodable { let activo: Bool; let tel_hash: String? }
        let h = Huella.tel(tel).map { Huella.de("tel", $0) }
        do { try await Red.sb?.rpc("hacerme_encontrable", params: P(activo: encontrable, tel_hash: encontrable ? h : nil)).execute(); aviso = L("contactos_guardado") }
        catch { aviso = L("contactos_error") }
    }
    private func revisar() async {
        revisando = true; defer { revisando = false }
        let tienda = CNContactStore()
        guard (try? await tienda.requestAccess(for: .contacts)) == true else { aviso = L("contactos_permiso"); return }
        let claves = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        var agenda: [Agenda] = []
        try? tienda.enumerateContacts(with: CNContactFetchRequest(keysToFetch: claves)) { c, _ in
            let tels = c.phoneNumbers.map(\.value.stringValue), correos = c.emailAddresses.map { $0.value as String }
            let h = Array(Set(tels.compactMap(Huella.tel))).map { Huella.de("tel", $0) } + Array(Set(correos.compactMap(Huella.correo))).map { Huella.de("correo", $0) }
            guard !h.isEmpty else { return }
            let n = (c.givenName + " " + c.familyName).trimmingCharacters(in: .whitespaces)
            agenda.append(Agenda(nombre: n.isEmpty ? (tels.first ?? correos.first ?? "") : n, telefono: tels.first ?? "", correo: correos.first ?? "", huellas: h))
        }
        struct P: Encodable { let hashes: [String] }
        do {
            let xs: [Encontrado] = try await Red.sb?.rpc("encontrar_contactos", params: P(hashes: Array(agenda.flatMap(\.huellas).prefix(3000)))).execute().value ?? []
            var vistos = Set<String>(); encontrados = xs.filter { $0.id != Red.yo && vistos.insert($0.id).inserted }
            let ya = Set(xs.map(\.hash))
            invitar = agenda.filter { !$0.huellas.contains(where: ya.contains) }.sorted { $0.nombre.localizedCompare($1.nombre) == .orderedAscending }
            revisado = true; aviso = nil
        } catch { aviso = L("contactos_error") }
    }
    private func invitarA(_ c: Agenda) {
        let t = invitacion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let u = c.telefono.isEmpty ? URL(string: "mailto:\(c.correo)?body=\(t)") : URL(string: "sms:\(c.telefono.filter { $0.isNumber || $0 == "+" })&body=\(t)")
        if let u { abrir(u) }
    }
}
