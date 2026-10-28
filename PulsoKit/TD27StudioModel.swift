import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class TD27StudioModel: ObservableObject {
    @Published var project = TD27Project()
    @Published var selectedZone = 0
    @Published var selectedLayer = 0 // Main / Sub
    struct LibraryKit: Identifiable {
        let url: URL
        let name: String
        let version: String
        let sampleCount: Int
        var id: URL { url }
    }
    @Published var kitLibrary: [LibraryKit] = []
    @Published var selectedLibraryKit: URL?

    @Published var selectedSample: UUID?
    @Published var message = "TD-27 Studio v3.1 · Kit-Browser, Main/Sub und SD-Export"
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var previewURL: URL?
    var parsedSource: TD27File? { project.sourceTD0.flatMap { try? TD27File($0) } }

    private var baseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TD27StudioV3", isDirectory: true).appendingPathComponent("base.TD0")
    }
    init(loadSavedBase: Bool = true) {
        engine.attach(player); engine.attach(pitch)
        engine.connect(player, to: pitch, format: nil)
        engine.connect(pitch, to: engine.mainMixerNode, format: nil)
        if loadSavedBase, let data = try? Data(contentsOf: baseURL), let file = try? TD27File(data), file.canExportSamples {
            project.sourceTD0 = data
            project.muteUnassigned = true
            message = "New kit using your saved base. Unassigned main instruments start at -60 dB; effects remain from the base."
        }
    }
    func run(_ action: () throws -> Void) {
        do { try action() } catch { message = error.localizedDescription }
    }
    func pickWAVs() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.wav]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { importWAVs(panel.urls) }
    }
    func importWAVs(_ urls: [URL]) {
        var errors: [String] = []; var added = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try readBounded(url, limit: 128*1024*1024)
                let wave = try TD27Wave(data)
                let clean = wave.sampleRate == 44100 ? wave.cleanWAV() : try convertedWAV(wave.cleanWAV())
                let sample = TD27Project.Sample(name: url.deletingPathExtension().lastPathComponent, wav: clean)
                var next = project; next.samples.append(sample)
                project = try next.validated(); selectedSample = sample.id; added += 1
            } catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        message = "Imported \(added) WAV file(s). " + errors.joined(separator: "\n")
    }
    private func convertedWAV(_ data: Data) throws -> Data {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let inputURL = folder.appendingPathComponent("input.wav"), outputURL = folder.appendingPathComponent("output.wav")
        try data.write(to: inputURL)
        let input = try AVAudioFile(forReading: inputURL)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: AVAudioFrameCount(input.length)),
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100,
                                         channels: input.processingFormat.channelCount, interleaved: false),
              let converter = AVAudioConverter(from: input.processingFormat, to: format) else {
            throw TD27File.Failure.invalid("Cannot create sample-rate converter.")
        }
        try input.read(into: buffer)
        let capacity = AVAudioFrameCount(ceil(Double(input.length)*44100/input.processingFormat.sampleRate)+4096)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw TD27File.Failure.invalid("Cannot allocate conversion buffer.")
        }
        var supplied = false; var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .endOfStream; return nil }
            supplied = true; state.pointee = .haveData; return buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else {
            throw error ?? NSError(domain: "TD27Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio conversion failed."])
        }
        do {
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100, AVNumberOfChannelsKey: Int(format.channelCount),
                AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
            let file = try AVAudioFile(forWriting: outputURL, settings: settings,
                                      commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: output)
        }
        return try TD27Wave(Data(contentsOf: outputURL)).cleanWAV()
    }
    func assign() {
        guard let id = selectedSample, project.samples.contains(where: { $0.id == id }) else { return }
        if selectedLayer == 1 {
            project.zones[selectedZone].sub = .init(sampleID:id,edited:true)
            var layer = currentLayerSettings
            layer.enabled = true
            project.zones[selectedZone].layer = layer
        } else {
            // Replacing Main preserves the existing Sub and its layer behavior.
            if project.zones[selectedZone].layer == nil { project.zones[selectedZone].layer = currentLayerSettings }
            project.zones[selectedZone].sampleID = id
            project.zones[selectedZone].mainEdited = true
            resetSelectedSample()
        }
        message = "Sample zugeordnet. Änderungen bleiben lokal bis zum TD0-Export. Main und Sub sind getrennt."
    }
    func useOriginalInstrument() {
        if selectedLayer == 0 {
            project.zones[selectedZone].sampleID = nil
            project.zones[selectedZone].mainEdited = false
        } else { project.zones[selectedZone].sub = nil }
        message = "Originale Zuordnung und Parameter dieser Ebene werden beim Export beibehalten."
    }
    var currentLayerSettings: TD27Project.LayerSettings {
        if let layer = project.zones[selectedZone].layer { return layer }
        guard let f = parsedSource else { return .init(enabled:false,mode:0,fadePoint:50) }
        let at = TD27Codec.commonBase + f.bodyOffset-48 + selectedZone*40
        return .init(enabled:f.bytes[at+5] == 1, mode:Int(f.bytes[at+6]), fadePoint:TD27Codec.u16(f.bytes,at+8))
    }
    func sourceAssignment(zone: Int, sub: Bool) -> String {
        guard let file = parsedSource else { return "Keine Kitdatei geladen" }
        let offset = (sub ? TD27Codec.subBase : TD27Codec.mainBase) + file.bodyOffset-48 + zone*28
        let number = TD27Codec.u16(file.bytes,offset), bank = file.bytes[offset+4]
        if bank == 1 {
            let label = file.sampleNames.indices.contains(number) ? file.sampleNames[number] : "Audio nicht eingebettet"
            return String(format:"U%03d",number+1) + " · " + label
        }
        if bank == 0 { return String(format:"%03d",number) + " · " + (TD27InstrumentNames.names[number] ?? "Werksinstrument") }
        return "Unbekannte Bank \(bank), ID \(number)"
    }
    func assignment(zone: Int, sub: Bool) -> String {
        let id = sub ? project.zones[zone].sub?.sampleID : project.zones[zone].sampleID
        return project.samples.first(where: { $0.id == id })?.name ?? sourceAssignment(zone:zone,sub:sub)
    }
    func removeSample() {
        guard let id = selectedSample else { return }
        stop()
        project.samples.removeAll { $0.id == id }
        for i in project.zones.indices {
            if project.zones[i].sampleID == id { project.zones[i].sampleID = nil; project.zones[i].mainEdited = false }
            if project.zones[i].sub?.sampleID == id { project.zones[i].sub = nil }
        }
        selectedSample = nil
    }
    func preview(assigned: Bool) {
        run {
            let zone = project.zones[selectedZone]
            let id = assigned ? (selectedLayer == 1 ? zone.sub?.sampleID : zone.sampleID) : selectedSample
            guard let sample = project.samples.first(where: { $0.id == id }) else { return }
            stop()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
            previewURL = url; try sample.wav.write(to: url)
            let file = try AVAudioFile(forReading: url)
            engine.stop()
            engine.disconnectNodeOutput(player); engine.disconnectNodeOutput(pitch)
            engine.connect(player, to: pitch, format: file.processingFormat)
            engine.connect(pitch, to: engine.mainMixerNode, format: file.processingFormat)
            player.volume = assigned ? Float(pow(10, (selectedLayer == 1 ? (zone.sub?.volumeDB ?? 0) : zone.volumeDB)/20)) : 1
            player.pan = assigned ? Float(zone.pan) : 0
            pitch.pitch = assigned ? Float((selectedLayer == 1 ? (zone.sub?.semitones ?? 0) : zone.semitones)*100) : 0
            player.scheduleFile(file, at: nil)
            try engine.start(); player.play()
        }
    }
    func stop() {
        player.stop(); engine.stop()
        if let url = previewURL { try? FileManager.default.removeItem(at: url) }
        previewURL = nil
    }
    func saveProject() {
        run {
            _ = try project.validated()
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Kit.td27project"
            panel.allowedContentTypes = [UTType(filenameExtension: "td27project") ?? .data]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.pathExtension.lowercased() == "td27project" else { throw TD27File.Failure.invalid("Use .td27project for project files.") }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(project)
            guard data.count <= 256*1024*1024 else { throw TD27File.Failure.invalid("Project exceeds 256 MiB.") }
            try data.write(to: url, options: .atomic)
            _ = try JSONDecoder().decode(TD27Project.self, from: Data(contentsOf: url)).validated()
            message = "Project saved with embedded WAVs. It is not a Roland TD0 file."
        }
    }
    func openProject() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "td27project") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url, confirmReplacement() else { return }
        run {
            let next = try JSONDecoder().decode(TD27Project.self, from: readBounded(url, limit: 256*1024*1024)).validated()
            stop(); project = next; selectedZone = 0; selectedSample = nil; message = "Project loaded."
        }
    }
    func saveAsDefaultBase() {
        run {
            guard let file = parsedSource, file.canExportSamples else {
                throw TD27File.Failure.invalid("Select a working 1.01/1.02 TD0 as the reusable base first.")
            }
            try FileManager.default.createDirectory(at: baseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.bytes.write(to: baseURL, options: .atomic)
            message = "Base saved locally. New kit now reuses it without a file picker. Original file unchanged."
        }
    }
    func newKit() {
        guard confirmReplacement() else { return }
        run {
            guard FileManager.default.fileExists(atPath:baseURL.path) else {
                throw TD27File.Failure.invalid("Choose a 1.01/1.02 base once, then click Remember as base for new kits.")
            }
            let data = try Data(contentsOf: baseURL)
            let file = try TD27File(data)
            guard file.canExportSamples else { throw TD27File.Failure.invalid("Save a supported base first.") }
            stop(); project = TD27Project(); project.sourceTD0 = data; project.muteUnassigned = true
            selectedSample = nil; selectedZone = 0
            message = "New kit. Assigned samples start at neutral pitch and full decay. Base effects are retained."
        }
    }
    var crossStickSettings: TD27Project.CrossStick {
        if let settings = project.crossStick { return settings }
        guard let file = parsedSource else { return .init() }
        let start = file.bodyOffset
        return .init(instrument: min(15,Int(file.bytes[start+33])),
                     volumeDB: max(-60,min(6,Double(Int16(bitPattern:UInt16(TD27Codec.u16(file.bytes,start+34))))/10)))
    }
    func resetSelectedSample() {
        if selectedLayer == 1 {
            var sub = project.zones[selectedZone].sub ?? .init()
            sub.semitones = 0; sub.instrumentPitch = 0; sub.instrumentDecay = 100; sub.padDecay = 100; sub.edited = true
            project.zones[selectedZone].sub = sub
            return
        }
        project.zones[selectedZone].mainEdited = true
        project.zones[selectedZone].semitones = 0
        project.zones[selectedZone].instrumentPitch = 0
        project.zones[selectedZone].instrumentDecay = 100
        project.zones[selectedZone].padDecay = 100
        message = "Pitch reset to zero on both levels; both decay controls set to 100. Effects remain from the base."
    }
    func openKit() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "TD0") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url, confirmReplacement() else { return }
        run { try loadKit(readBounded(url, limit: 256*1024*1024)) }
    }
    func loadKit(_ data: Data) throws {
        let file = try TD27File(data)
        var next = TD27Project(); next.sourceTD0 = data; next.title = file.kitName
        let blocks = try TD27Codec.blocks(file)
        var ids: [Int:UUID] = [:]
        for slot in blocks.keys.sorted() {
            let sample = TD27Project.Sample(name:file.sampleNames[slot],wav:TD27Codec.wav(try TD27Codec.decode(blocks[slot]!)),sourceSlot:slot)
            next.samples.append(sample); ids[slot] = sample.id
        }
        if file.canExportSamples {
            for z in next.zones.indices {
                let offset = TD27Codec.mainBase+z*28, slot = TD27Codec.u16(data,offset)
                next.zones[z].mainEdited = false
                if data[offset+4] == 1, let id = ids[slot] {
                    next.zones[z].sampleID = id
                    next.zones[z].volumeDB = max(-60,min(6,Double(Int16(bitPattern:UInt16(TD27Codec.u16(data,offset+2))))/10))
                    next.zones[z].semitones = max(-24,min(24,Double(Int16(bitPattern:UInt16(TD27Codec.u16(data,offset+12))))/100))
                    next.zones[z].pan = max(-1,min(1,Double(Int8(bitPattern:data[TD27Codec.commonBase+z*40]))/30))
                    next.zones[z].padDecay = Double(max(1,min(100,Int(data[offset+11]))))
                    let vedit = TD27Codec.vEditMainBase+z*TD27Codec.vEditStride
                    next.zones[z].instrumentPitch = Double(max(-100,min(100,Int(Int8(bitPattern:data[vedit])))))
                    next.zones[z].instrumentDecay = Double(max(1,min(100,Int(data[vedit+1]))))
                }
                let sub = TD27Codec.subBase+z*28, subSlot = TD27Codec.u16(data,sub)
                if data[sub+4] == 1, let id = ids[subSlot] {
                    let vedit = TD27Codec.vEditSubBase+z*24
                    next.zones[z].sub = .init(sampleID:id,
                        volumeDB:max(-60,min(6,Double(Int16(bitPattern:UInt16(TD27Codec.u16(data,sub+2))))/10)),
                        semitones:max(-24,min(24,Double(Int16(bitPattern:UInt16(TD27Codec.u16(data,sub+12))))/100)),
                        instrumentPitch:Double(max(-100,min(100,Int(Int8(bitPattern:data[vedit]))))),
                        instrumentDecay:Double(max(1,min(100,Int(data[vedit+1])))),
                        padDecay:Double(max(1,min(100,Int(data[sub+11])))),edited:false)
                }
            }
        }
        stop(); project = try next.validated(); selectedZone = 0; selectedLayer = 0; selectedSample = nil
        message = file.canExportSamples ? "Kit vollständig aus TD0 geladen. Main/Sub und alle eingebetteten Samples verfügbar. Unbearbeitete Bereiche bleiben unverändert." : "2.21 kit inspected and checksum verified. Exact-copy saving is supported; sample export requires a 1.01/1.02 base."
    }
    func openTD0() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "TD0") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        run {
            let file = try TD27File(readBounded(url, limit: 256*1024*1024))
            _ = try TD27Codec.blocks(file)
            stop()
            if project.title == "New TD-27 kit" { project.title = file.kitName }
            project.sourceTD0 = file.bytes
            message = "Template loaded: \(file.kitName), \(file.blocks.count) embedded samples. Your WAV assignments are kept."
        }
    }
    func exportTD0() {
        run {
            let output = try TD27Codec.export(project)
            let panel = NSSavePanel(); panel.title = "TD-27 Studio v3.1 — vollständiges Kit exportieren"
            panel.nameFieldStringValue = String(format:"KIT-%03d.TD0",project.sdFileNumber ?? 1)
            panel.allowedContentTypes = [UTType(filenameExtension: "TD0") ?? .data]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.pathExtension.lowercased() == "td0" else { throw TD27File.Failure.invalid("Use .TD0 for kit export.") }
            try output.write(to: url, options: .withoutOverwriting)
            let saved = try Data(contentsOf: url)
            guard saved == output else { throw TD27File.Failure.invalid("Saved bytes differ from export.") }
            _ = try TD27Codec.blocks(TD27File(saved))
            message = "TD0 mit eingebetteten Samples gespeichert und zurückgelesen. Am Modul 1 KIT LOAD, With User Sample aktivieren und den Zielplatz bewusst wählen. Die Dateinummer legt den Zielplatz NICHT fest."
        }
    }
    func extractSourceSamples() {
        run {
            guard let file = parsedSource else { return }
            let blocks = try TD27Codec.blocks(file)
            var next = project
            for slot in blocks.keys.sorted() where !next.samples.contains(where: { $0.sourceSlot == slot }) {
                let audio = try TD27Codec.decode(blocks[slot]!)
                let label = file.sampleNames[slot]
                next.samples.append(TD27Project.Sample(name: label, wav: TD27Codec.wav(audio), sourceSlot:slot))
            }
            project = try next.validated()
            message = "Extracted \(blocks.count) embedded samples as WAVs for preview and reassignment."
        }
    }
    func exportOriginal() {
        run {
            guard let source = project.sourceTD0 else { return }
            let file = try TD27File(source)
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Original-copy.TD0"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.pathExtension.lowercased() == "td0" else { throw TD27File.Failure.invalid("Use .TD0 for the original copy.") }
            // Exclusive creation prevents overwriting any original, including hard links.
            try file.originalCopy().write(to: url, options: .withoutOverwriting)
            guard try Data(contentsOf: url) == source else { throw TD27File.Failure.invalid("Copy verification failed.") }
            message = "Exact original copy saved. Draft edits and imported WAVs are NOT included."
        }
    }
    func loadLibraryURL(_ url: URL) {
        guard confirmReplacement() else { return }
        run { try loadKit(readBounded(url,limit:256*1024*1024)) }
    }
    private func confirmReplacement() -> Bool {
        if project.sourceTD0 == nil && project.samples.isEmpty && project.title == "New TD-27 kit" { return true }
        let alert = NSAlert(); alert.messageText = "Replace the current project?"
        alert.informativeText = "Save your project first if you want to keep changes."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Replace")
        return alert.runModal() == .alertSecondButtonReturn
    }
    private func readBounded(_ url: URL, limit: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= limit else {
            throw TD27File.Failure.invalid("Not a regular file or file exceeds size limit.")
        }
        return try Data(contentsOf: url)
    }
}
