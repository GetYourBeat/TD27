import SwiftUI

struct TD27BrowserView: View {
    @EnvironmentObject private var midi: MIDIManager
    @ObservedObject var model: TD27StudioModel
    @State private var sourceNumber = 50
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                GroupBox("USB · Kit im Modul ansehen") {
                    VStack(alignment:.leading,spacing:10) {
                        HStack {
                            Button("100 Kitnamen lesen") { midi.readTD27KitNames() }.disabled(midi.isOperationInProgress)
                            Picker("Quellkit",selection:$sourceNumber) {
                                ForEach(1...100,id:\.self) { number in
                                    Text("\(number) · \(midi.td27KitNames.first(where: { $0.number == number })?.name ?? "noch nicht gelesen")").tag(number)
                                }
                            }.frame(maxWidth:360)
                            Button("Belegung lesen") { midi.readTD27Kit(sourceNumber) }.disabled(midi.isOperationInProgress)
                            if midi.td27BrowserBusy {
                                ProgressView().controlSize(.small)
                                Button("Abbrechen") { midi.cancelTD27Browser() }
                            }
                        }
                        Text(midi.td27BrowserStatus).textSelection(.enabled)
                        Text("Liest die gespeicherten Zuordnungen, ohne das Kit umzuschalten oder zu verändern. Kein vollständiger Backup: Sample-Audio und globale Effekte müssen aus einer TD0-Sicherung geladen werden.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let kit = midi.td27KitSnapshot {
                            Text("Gelesen: Kit \(kit.kitNumber) · \(kit.name)").font(.headline)
                            if sourceNumber != kit.kitNumber { Text("Auswahl geändert — angezeigt wird noch Kit \(kit.kitNumber). Belegung erneut lesen.").foregroundStyle(.orange) }
                            Grid(alignment:.leading,horizontalSpacing:20,verticalSpacing:8) {
                                GridRow { Text("Zone").bold(); Text("Main").bold(); Text("Sub").bold() }
                                ForEach(kit.zones) { zone in
                                    GridRow {
                                        Text(TD27ZoneCatalog.names[zone.index])
                                        VStack(alignment:.leading) {
                                            Text(zone.main.label)
                                            if zone.main.bank == 1 { Text(sampleParameters(zone.mainVEdit)).font(.caption) }
                                        }
                                        VStack(alignment:.leading) {
                                            Text((zone.subEnabled ? "AN · " : "AUS · ")+zone.sub.label)
                                            if zone.sub.bank == 1 { Text(sampleParameters(zone.subVEdit)).font(.caption) }
                                        }
                                    }
                                }
                            }.font(.callout).textSelection(.enabled)
                        }
                    }.padding(8)
                }
                GroupBox("SD / Computer · vollständiges Kit öffnen") {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Am Modul einmal: SYSTEM → SD CARD → 1 KIT SAVE → With User Sample aktivieren. Dann die SD-Karte am Mac öffnen. Eine SD-Dateinummer ist nicht automatisch die ursprüngliche Modul-Kitnummer.")
                        HStack {
                            Button("Kitordner / SD-Karte durchsuchen…",action:model.scanKitFolder)
                            Button("Einzelne TD0 öffnen…",action:model.openKit)
                        }
                        if !model.kitLibrary.isEmpty {
                            Picker("TD0-Datei",selection:$model.selectedLibraryKit) {
                                ForEach(model.kitLibrary) { file in
                                    Text("\(file.url.lastPathComponent) · \(file.name) · \(file.sampleCount) Samples · Format \(file.version)")
                                        .tag(Optional(file.url))
                                }
                            }
                            Button("Ausgewählte Datei vollständig im Editor öffnen",action:model.openLibraryKit)
                                .disabled(model.selectedLibraryKit == nil)
                        }
                        Text("Format 1.01/1.02: bearbeiten und mit Samples exportieren. Format 2.21: anzeigen und Originalkopie; sein Samplecontainer bleibt unverifiziert.").font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
                GroupBox("Quelle und Ziel getrennt halten") {
                    VStack(alignment:.leading) {
                        Picker("Quellplatz der geöffneten Datei (manuell zuordnen)",selection:Binding(
                            get:{ model.project.sourceKitNumber ?? 0 },set:{ model.project.sourceKitNumber = $0 == 0 ? nil : $0 })) {
                            Text("Unbekannt / neues Kit").tag(0)
                            ForEach(1...100,id:\.self) { Text("Kit \($0)").tag($0) }
                        }
                        Text("Diese Angabe dokumentiert die Herkunft. Sie lädt keine Daten und wird nicht aus dem Dateinamen abgeleitet.").font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
                if midi.profile.kind == .td27 {
                    DisclosureGroup("Bestätigte USB-Snare-Steuerung · ausschließlich Kit 76") {
                        TD27USBTestView()
                    }
                }
            }.padding(8)
        }
    }
    private func sampleParameters(_ bytes: [UInt8]) -> String {
        guard bytes.count >= 5,
              let pitch = TD27USBTest.Parameter.pitch.decode(Array(bytes[1...2])),
              let decay = TD27USBTest.Parameter.decay.decode(Array(bytes[3...4])) else { return "Parameter nicht dekodiert" }
        return "Pitch \(pitch) · Decay \(decay)"
    }
}
