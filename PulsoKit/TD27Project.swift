import Foundation

struct TD27Project: Codable {
    var schema = 1
    var title = "New TD-27 kit"
    var sourceTD0: Data?
    var samples: [Sample] = []
    var zones: [Zone] = TD27ZoneCatalog.names.map { Zone(name: $0) }
    struct Sample: Codable, Identifiable {
        var id = UUID()
        var name: String
        var wav: Data
    }
    struct Zone: Codable, Identifiable {
        var name: String
        var sampleID: UUID?
        var volumeDB: Double = 0
        var pan: Double = 0
        var semitones: Double = 0
        var id: String { name }
    }
    func validated() throws -> Self {
        guard schema == 1, title.count <= 128, samples.count <= 500,
              zones.map(\.name) == TD27ZoneCatalog.names,
              Set(samples.map(\.id)).count == samples.count else {
            throw TD27File.Failure.invalid("Invalid project schema, samples or zones.")
        }
        if let sourceTD0 { _ = try TD27File(sourceTD0) }
        var monoSeconds = 0.0
        for s in samples {
            let w = try TD27Wave(s.wav)
            guard w.moduleReady, s.name.count <= 256 else { throw TD27File.Failure.invalid("Invalid project sample.") }
            monoSeconds += w.duration * Double(w.channels)
        }
        guard monoSeconds <= 1440 else { throw TD27File.Failure.invalid("Sample library exceeds 24 mono-equivalent minutes.") }
        let ids = Set(samples.map(\.id))
        for z in zones {
            guard z.sampleID.map({ ids.contains($0) }) ?? true,
                  z.volumeDB.isFinite, (-60...6).contains(z.volumeDB),
                  z.pan.isFinite, (-1...1).contains(z.pan),
                  z.semitones.isFinite, (-24...24).contains(z.semitones) else {
                throw TD27File.Failure.invalid("Invalid pad assignment or preview parameter.")
            }
        }
        return self
    }
}
