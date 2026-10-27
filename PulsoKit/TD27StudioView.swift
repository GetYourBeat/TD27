import SwiftUI
import UniformTypeIdentifiers

struct TD27StudioView: View {
    @ObservedObject var model: TD27StudioModel
    @State private var targeted = false
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
                Text("TD-27 Studio").font(.largeTitle.bold())
                Spacer()
                Button("TD0 template…", action: model.openTD0)
                Button("Open project", action: model.openProject)
                Button("Save project", action: model.saveProject)
            }
            Text("Experimental TD0 exporter • Import on a real TD-27 has not yet been tested")
                .foregroundStyle(.orange)
            HSplitView {
                library.frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
                VStack(alignment: .leading) {
                    TextField("Project title", text: $model.project.title).font(.title2)
                    stage.frame(minHeight: 300, idealHeight: 360)
                    Picker("Zone", selection: $model.selectedZone) {
                        ForEach(Array(model.project.zones.enumerated()), id: \.offset) { index, zone in
                            Text(zone.name).tag(index)
                        }
                    }
                    HStack {
                        Button("Assign selected sample", action: model.assign).disabled(model.selectedSample == nil)
                        Button("Use original instrument") { model.project.zones[model.selectedZone].sampleID = nil }
                        Button("Play pad") { model.preview(assigned: true) }
                        Button("Stop", action: model.stop)
                    }
                    Text(assignmentName).foregroundStyle(.secondary)
                    GroupBox("Assigned sample: level, pan and tuning — included in TD0 export") {
                        VStack {
                            parameter("Level", value: $model.project.zones[model.selectedZone].volumeDB, range: -60...6, suffix: "dB")
                            parameter("Pan", value: $model.project.zones[model.selectedZone].pan, range: -1...1, suffix: "")
                            parameter("Tuning", value: $model.project.zones[model.selectedZone].semitones, range: -24...24, suffix: "st")
                        }.padding(6)
                    }
                }.padding(.horizontal, 16).frame(minWidth: 530)
                sourceInspector.frame(minWidth: 200, idealWidth: 230, maxWidth: 320)
            }
            Text(model.message).font(.callout).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .onDisappear { model.stop() }
    }
    private var assignmentName: String {
        let id = model.project.zones[model.selectedZone].sampleID
        return model.project.samples.first(where: { $0.id == id })?.name ?? "Original template instrument (no replacement assigned)"
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
                        model.selectedZone = pad.1[0]
                    } label: {
                        VStack(spacing: 4) {
                            Text(pad.0).font(.headline)
                            Text(pad.1.contains(where: { model.project.zones[$0].sampleID != nil }) ? "● assigned" : "○ empty")
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
            Text("Original TD0").font(.headline)
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
                Button("Extract samples to WAV library", action: model.extractSourceSamples)
                Button("Save original copy…", action: model.exportOriginal)
                Text("This copies the source byte for byte. Project changes are not included.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Optional: open an existing TD-27 1.01/1.02 kit to inspect and preserve its original bytes.")
                    .font(.caption)
            }
            Divider()
            Button("Export TD0 with samples…", action: model.exportTD0)
                .disabled(model.project.sourceTD0 == nil)
            Text("Requires a TD0 template. Assigned zones receive your samples; other zones and existing sample blocks are preserved. Unknown settings remain from the template. Test only after backing up your module. No MIDI writes.")
                .font(.caption).foregroundStyle(.orange)
            Spacer()
        }.padding(10)
    }
    private func parameter(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(title).frame(width: 55, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.1f %@", value.wrappedValue, suffix)).monospacedDigit().frame(width: 80)
        }
    }
}
