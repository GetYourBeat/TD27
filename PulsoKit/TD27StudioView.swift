import SwiftUI
import UniformTypeIdentifiers

struct TD27StudioView: View {
    @ObservedObject var model: TD27StudioModel
    @State private var browser = false
    @State private var overview = false
    @State private var targeted = false
    @State private var showCrossStick = false
    private let pads: [(String, [Int], Double, Double)] = [
        ("Crash 1",[11,12],0.15,0.15), ("Tom 1",[3,4],0.36,0.29),
        ("Tom 2",[5,6],0.60,0.29), ("Crash 2",[13,14],0.83,0.15),
        ("Hi-hat",[9,10],0.13,0.48), ("Snare",[1,2],0.34,0.58),
        ("Kick",[0],0.56,0.60), ("Tom 3",[7,8],0.79,0.59),
        ("Ride",[15,16,17],0.86,0.38), ("AUX 1",[18,19],0.20,0.85),
        ("AUX 2",[20,21],0.48,0.85), ("AUX 3",[22,23],0.76,0.85)
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TD-27 Studio v3.1").font(.largeTitle.bold())
                Spacer()
                Button("New kit", action: model.newKit)
                Button("Open kit…", action: model.openKit)
                Button("Choose base…", action: model.openTD0)
                Button("Open project", action: model.openProject)
                Button("Save project", action: model.saveProject)
            }
            HStack {
                Picker("Ansicht",selection:$browser) {
                    Text("Kit-Editor").tag(false)
                    Text("USB / SD Kit-Browser").tag(true)
                }.pickerStyle(.segmented).frame(width:400)
                Text("Änderungen lokal · vollständiger Transfer über SD").font(.caption).foregroundStyle(.secondary)
            }
            if browser { TD27BrowserView(model:model) }
            else {
            HSplitView {
                library.frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
                VStack(alignment: .leading) {
                    TextField("Project title", text: $model.project.title).font(.title2)
                    Toggle("Alle Main-/Sub-Zuordnungen anzeigen",isOn:$overview)
                    if overview {
                        ScrollView {
                            VStack(alignment:.leading,spacing:8) {
                                ForEach(0..<24,id:\.self) { i in
                                    Button { model.selectedZone = i; showCrossStick = false } label: {
                                        VStack(alignment:.leading) {
                                            Text(TD27ZoneCatalog.names[i]).bold()
                                            Text("Main: " + model.assignment(zone:i,sub:false))
                                            Text("Sub: " + model.assignment(zone:i,sub:true))
                                        }.frame(maxWidth:.infinity,alignment:.leading)
                                    }.buttonStyle(.plain)
                                }
                            }.font(.caption)
                        }.frame(height:240)
                    } else { stage.frame(minHeight:220,idealHeight:260) }
                    HStack {
                        Text("PD-140DS:")
                        Button("Head") { model.selectedZone = 1; showCrossStick = false }
                        Button("Rimshot") { model.selectedZone = 2; showCrossStick = false }
                        Button("Cross-stick") { showCrossStick = true }
                    }
                    if showCrossStick { crossStickPanel }

                    if !showCrossStick {
                    Picker("Zone", selection: $model.selectedZone) {
                        ForEach(Array(model.project.zones.enumerated()), id: \.offset) { index, zone in
                            Text(zone.name).tag(index)
                        }
                    }
                    Picker("Ebene",selection:$model.selectedLayer) {
                        Text("Main").tag(0); Text("Sub").tag(1)
                    }.pickerStyle(.segmented)
                    HStack {
                        Button("Assign selected sample", action: model.assign).disabled(model.selectedSample == nil)
                        Button("Original wiederherstellen",action:model.useOriginalInstrument)
                        Button("Play pad") { model.preview(assigned: true) }
                        Button("Stop", action: model.stop)
                    }
                    Text(assignmentName).foregroundStyle(.secondary)
                    layerPanel
                    Button("Reset sample sound: pitch 0 / decay 100", action: model.resetSelectedSample)
                    GroupBox("User-Sample-Parameter · lokal bearbeiten, dann TD0 exportieren") {
                        VStack {
                            parameter("Level", value: soundValue(\.volumeDB,sub:\.volumeDB), range: -60...6, suffix: "dB")
                            parameter("Pan", value: Binding(get:{model.project.zones[model.selectedZone].pan},set:{model.project.zones[model.selectedZone].pan = $0; model.project.zones[model.selectedZone].panEdited = true}), range: -1...1, suffix: "")
                            parameter("Pad pitch", value: soundValue(\.semitones,sub:\.semitones), range: -24...24, suffix: "st")
                            parameter("Inst pitch", value: zoneValue(\.instrumentPitch, default: 0), range: -100...100, suffix: "")
                            parameter("Inst decay", value: zoneValue(\.instrumentDecay, default: 100), range: 1...100, suffix: "%")
                            parameter("Pad decay", value: zoneValue(\.padDecay, default: 100), range: 1...100, suffix: "%")
                            Text("Preview plays WAV + pad pitch/pan/level. Instrument pitch, decay and template effects are module parameters; the preview does not simulate them.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(6)
                    }.disabled(model.selectedLayer == 0 ? model.project.zones[model.selectedZone].sampleID == nil : model.project.zones[model.selectedZone].sub?.sampleID == nil)
                    }
                }.padding(.horizontal, 16).frame(minWidth: 530)
                sourceInspector.frame(minWidth: 200, idealWidth: 230, maxWidth: 320)
            }
            }
            Text(model.message).font(.callout).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .onDisappear { model.stop() }
    }
    private var assignmentName: String {
        model.assignment(zone:model.selectedZone,sub:model.selectedLayer == 1)
    }
    private var library: some View {
        VStack(alignment: .leading) {
            Text("WAV library").font(.headline)
            Text("Drop WAV files here").foregroundStyle(.secondary)
            Button("Import WAVs…", action: model.pickWAVs)
            List(selection: $model.selectedSample) {
                ForEach(model.project.samples) { sample in
                    VStack(alignment: .leading) {
                        Text(sample.name).lineLimit(2)
                        if let wave = try? TD27Wave(sample.wav) {
                            Text(String(format: "%.2f s · %d ch · %d bit", wave.duration, wave.channels, wave.bits))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.tag(sample.id)
                }
            }
            HStack {
                Button("Preview") { model.preview(assigned: false) }
                Button("Remove", action: model.removeSample)
            }.disabled(model.selectedSample == nil)
            Text("44.1 kHz · PCM 16/24 bit\nTD0 exports 16-bit PCM; 24-bit input is reduced to 16 bit.\nMaximum 180 seconds per sample.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(10)
        .background(targeted ? Color.accentColor.opacity(0.15) : .clear)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in model.importWAVs([url]) }
                }
            }
            return !providers.isEmpty
        }
    }
    private var stage: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.18))
                ForEach(pads.indices, id: \.self) { i in
                    let pad = pads[i]
                    Button {
                        model.selectedZone = pad.1[0]; showCrossStick = false
                    } label: {
                        VStack(spacing: 4) {
                            Text(pad.0).font(.headline)
                            Text(model.parsedSource == nil ? "○ kein Kit" : "● Main / Sub")
                                .font(.caption)
                        }
                        .frame(width: 88, height: 62)
                        .background(pad.1.contains(model.selectedZone) ? Color.accentColor : Color.gray.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(.secondary.opacity(0.4)))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Select \(pad.0)")
                        .position(x: geometry.size.width*pad.2, y: geometry.size.height*pad.3)
                }
            }
        }
    }
    private var sourceInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kit base").font(.headline)
            if let file = model.parsedSource {
                Text(file.kitName).font(.title3)
                Text("Core MD5 verified\n\(file.bytes.count) bytes\n\(file.blocks.count) embedded sample blocks")
                    .font(.caption)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(file.blocks) { block in
                            Text(block.name).font(.caption.bold())
                            Text("\(block.payloadBytes) payload bytes").font(.caption)
                        }
                    }
                }
                Text("Format \(file.version)")
                Button("Remember as base for new kits", action: model.saveAsDefaultBase)
                    .disabled(!file.canExportSamples)
                Toggle("Unassigned pads: -60 dB", isOn: Binding(get: { model.project.muteUnassigned ?? false }, set: { model.project.muteUnassigned = $0 }))
                Button("Extract samples to WAV library", action: model.extractSourceSamples)
                Button("Save original copy…", action: model.exportOriginal)
                Text("This copies the source byte for byte. Project changes are not included.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Choose a working 1.01/1.02 kit once and remember it as your base. New kit then uses it automatically. 2.21 cores can be inspected and copied.")
                    .font(.caption)
            }
            Divider()
            Picker("Zielplatz am Modul",selection:Binding(get:{ model.project.targetKitNumber ?? 78 },set:{ model.project.targetKitNumber = $0 })) {
                ForEach(1...100,id:\.self) { Text("Kit \($0)").tag($0) }
            }
            Stepper("SD-Datei: \(model.project.sdFileNumber ?? 1)",value:Binding(get:{model.project.sdFileNumber ?? 1},set:{model.project.sdFileNumber = $0}),in:1...999)
            Button("SD-Paket + Importanleitung…") {
                if model.project.targetKitNumber == nil { model.project.targetKitNumber = 78 }
                model.exportSDPackage()
            }.disabled(model.parsedSource?.canExportSamples != true)
            Text("Der Zielplatz wird erst bei 1 KIT LOAD am Modul gewählt. Die Dateinummer erzwingt ihn nicht. Ein belegter Zielplatz wird dort ersetzt — vorher sichern.").font(.caption).foregroundStyle(.orange)
            Button("Nur TD0 exportieren…", action: model.exportTD0)
                .disabled(model.parsedSource?.canExportSamples != true)
            Text("Main/Sub einzeln ersetzen. Effekte und unbearbeitete Daten bleiben erhalten. Neue Layer-Exporte sind automatisiert geprüft; ihr Hardwaretest steht noch aus.")
                .font(.caption).foregroundStyle(.orange)
            Spacer()
        }.padding(10)
    }
    private func soundValue(_ key: WritableKeyPath<TD27Project.Zone,Double>, sub subKey: WritableKeyPath<TD27Project.SubLayer,Double>) -> Binding<Double> {
        Binding(get: { model.selectedLayer == 1 ? (model.project.zones[model.selectedZone].sub ?? .init())[keyPath:subKey] : model.project.zones[model.selectedZone][keyPath:key] },set: { value in
            if model.selectedLayer == 1 {
                var sub = model.project.zones[model.selectedZone].sub ?? .init()
                sub[keyPath:subKey] = value; sub.edited = true; model.project.zones[model.selectedZone].sub = sub
            } else { model.project.zones[model.selectedZone][keyPath:key] = value; model.project.zones[model.selectedZone].mainEdited = true }
        })
    }
    private func zoneValue(_ key: WritableKeyPath<TD27Project.Zone, Double?>, default fallback: Double) -> Binding<Double> {
        let subKey: WritableKeyPath<TD27Project.SubLayer,Double> = key == \.instrumentPitch ? \.instrumentPitch : key == \.instrumentDecay ? \.instrumentDecay : \.padDecay
        return Binding(get: {
            model.selectedLayer == 1 ? (model.project.zones[model.selectedZone].sub ?? .init())[keyPath:subKey] : (model.project.zones[model.selectedZone][keyPath:key] ?? fallback)
        },set: { value in
            if model.selectedLayer == 1 {
                var sub = model.project.zones[model.selectedZone].sub ?? .init()
                sub[keyPath:subKey] = value; sub.edited = true; model.project.zones[model.selectedZone].sub = sub
            } else { model.project.zones[model.selectedZone][keyPath:key] = value; model.project.zones[model.selectedZone].mainEdited = true }
        })
    }
    private var layerPanel: some View {
        GroupBox("Main / Sub · Anschlagdynamik") {
            HStack {
                Toggle("Sub an",isOn:Binding(get:{model.currentLayerSettings.enabled},set:{value in var layer = model.currentLayerSettings; layer.enabled = value; model.project.zones[model.selectedZone].layer = layer}))
                Picker("Modus",selection:Binding(get:{model.currentLayerSettings.mode},set:{value in var layer = model.currentLayerSettings; layer.mode = value; model.project.zones[model.selectedZone].layer = layer})) {
                    ForEach(Array(["MIX","FADE1","FADE2","FADE3","SWITCH"].enumerated()),id:\.offset) { i,name in Text(name).tag(i) }
                }
                Stepper("Fade: \(model.currentLayerSettings.fadePoint)",value:Binding(get:{model.currentLayerSettings.fadePoint},set:{value in var layer = model.currentLayerSettings; layer.fadePoint = value; model.project.zones[model.selectedZone].layer = layer}),in:1...159)
                    .disabled(model.currentLayerSettings.mode == 0)
            }.font(.caption)
        }.disabled(model.parsedSource?.canExportSamples != true)
    }
    private var crossStickPanel: some View {
        GroupBox("PD-140DS — Cross-stick") {
            VStack(alignment: .leading) {
                Picker("Roland cross-stick sound", selection: Binding(get: { model.crossStickSettings.instrument }, set: {
                    var settings = model.crossStickSettings; settings.instrument = $0; model.project.crossStick = settings
                })) {
                    ForEach(0..<16, id: \.self) { Text("Cross-stick \($0+1)").tag($0) }
                }
                parameter("Level", value: Binding(get: { model.crossStickSettings.volumeDB }, set: {
                    var settings = model.crossStickSettings; settings.volumeDB = $0; model.project.crossStick = settings
                }), range: -60...6, suffix: "dB")
                Text("Roland offers 16 cross-stick sounds when a compatible internal snare/cross-stick instrument is on Snare Rim. This is not a third freely assignable WAV zone. A user sample on Snare Rim does not meet that condition.")
                    .font(.caption)
            }.padding(6)
        }
    }
    private func parameter(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(title).frame(width: 55, alignment: .leading)
            Slider(value: value, in: range)
            TextField(title,value:value,format:.number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder).monospacedDigit().frame(width:65)
            Text(suffix).font(.caption).frame(width:25)
            if !value.wrappedValue.isFinite || !range.contains(value.wrappedValue) { Text("Bereich!").foregroundStyle(.red) }
        }
    }
}
