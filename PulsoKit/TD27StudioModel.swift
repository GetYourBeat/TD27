import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class TD27StudioModel: ObservableObject {
    @Published var project = TD27Project()
    @Published var selectedZone = 0
    @Published var selectedSample: UUID?
    @Published var message = "TD0 export available as an experimental build; not yet tested on hardware."
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var previewURL: URL?
    var parsedSource: TD27File? { project.sourceTD0.flatMap { try? TD27File($0) } }

    init() {
        engine.attach(player); engine.attach(pitch)
        engine.connect(player, to: pitch, format: nil)
        engine.connect(pitch, to: engine.mainMixerNode, format: nil)
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
        project.zones[selectedZone].sampleID = id
        message = "Assigned to the main instrument. TD0 export replaces this zone and disables its previous sub-layer."
    }
    func removeSample() {
        guard let id = selectedSample else { return }
        stop()
        project.samples.removeAll { $0.id == id }
        for i in project.zones.indices where project.zones[i].sampleID == id { project.zones[i].sampleID = nil }
        selectedSample = nil
    }
    func preview(assigned: Bool) {
        run {
            let zone = project.zones[selectedZone]
            let id = assigned ? zone.sampleID : selectedSample
            guard let sample = project.samples.first(where: { $0.id == id }) else { return }
            stop()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
            previewURL = url; try sample.wav.write(to: url)
            let file = try AVAudioFile(forReading: url)
            engine.stop()
            engine.disconnectNodeOutput(player); engine.disconnectNodeOutput(pitch)
            engine.connect(player, to: pitch, format: file.processingFormat)
            engine.connect(pitch, to: engine.mainMixerNode, format: file.processingFormat)
            player.volume = assigned ? Float(pow(10, zone.volumeDB/20)) : 1
            player.pan = assigned ? Float(zone.pan) : 0
            pitch.pitch = assigned ? Float(zone.semitones*100) : 0
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
            let panel = NSSavePanel(); panel.title = "Experimental TD-27 export — hardware test pending"
            panel.nameFieldStringValue = "KIT-001.TD0"
            panel.allowedContentTypes = [UTType(filenameExtension: "TD0") ?? .data]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.pathExtension.lowercased() == "td0" else { throw TD27File.Failure.invalid("Use .TD0 for kit export.") }
            try output.write(to: url, options: .withoutOverwriting)
            let saved = try Data(contentsOf: url)
            guard saved == output else { throw TD27File.Failure.invalid("Saved bytes differ from export.") }
            _ = try TD27Codec.blocks(TD27File(saved))
            message = "TD0 saved with assigned WAVs and verified by re-reading. Hardware compatibility still needs testing. Original file was not overwritten."
        }
    }
    func extractSourceSamples() {
        run {
            guard let file = parsedSource else { return }
            let blocks = try TD27Codec.blocks(file)
            var next = project
            for slot in blocks.keys.sorted() {
                let audio = try TD27Codec.decode(blocks[slot]!)
                let label = file.sampleNames[slot]
                next.samples.append(TD27Project.Sample(name: label, wav: TD27Codec.wav(audio)))
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
