import Foundation
import Testing
@testable import PulsoKit

@MainActor
struct TD27ProjectTests {
    private func wave(rate: Int = 44100) -> Data {
        var d = Data("RIFF".utf8)
        func put(_ v: Int, _ n: Int) { for i in 0..<n { d.append(UInt8((v >> (i*8)) & 255)) } }
        let size = rate*2
        put(36+size,4);d.append(Data("WAVEfmt ".utf8));put(16,4);put(1,2);put(1,2)
        put(rate,4);put(rate*2,4);put(2,2);put(16,2);d.append(Data("data".utf8));put(size,4)
        d.append(Data(repeating:0,count:size));return d
    }
    @Test func projectRoundTripPreservesSamplesAndAssignments() throws {
        var project = TD27Project()
        let sample = TD27Project.Sample(name:"Kick",wav:wave())
        project.samples.append(sample);project.zones[0].sampleID = sample.id
        project.zones[0].volumeDB = -6;project.zones[0].pan = 0.25;project.zones[0].semitones = 3
        let decoded = try JSONDecoder().decode(TD27Project.self,from:JSONEncoder().encode(project)).validated()
        #expect(decoded.samples[0].wav == sample.wav)
        #expect(decoded.zones[0].sampleID == sample.id)
        #expect(decoded.zones[0].volumeDB == -6)
        #expect(decoded.zones[0].pan == 0.25)
        #expect(decoded.zones[0].semitones == 3)
    }
    @Test func danglingAssignmentRejected() {
        var project = TD27Project();project.zones[0].sampleID = UUID()
        #expect(throws: (any Error).self) { try project.validated() }
    }
    @Test func invalidParameterRejected() {
        var project = TD27Project();project.zones[0].pan = 2
        #expect(throws: (any Error).self) { try project.validated() }
    }
    @Test func unsupportedSchemaRejected() {
        var project = TD27Project();project.schema = 99
        #expect(throws: (any Error).self) { try project.validated() }
    }
    @Test func importConverts48kAndPreservesDuration() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer { try? FileManager.default.removeItem(at:url) }
        try wave(rate:48000).write(to:url)
        let model = TD27StudioModel();model.importWAVs([url])
        #expect(model.project.samples.count == 1)
        let sample = try #require(model.project.samples.first)
        let result = try TD27Wave(sample.wav)
        #expect(result.sampleRate == 44100)
        #expect(abs(result.duration-1) < 0.01)
        model.selectedZone = 2;model.assign()
        #expect(model.project.zones[2].sampleID == sample.id)
        model.removeSample()
        #expect(model.project.samples.isEmpty)
        #expect(model.project.zones[2].sampleID == nil)
    }
}
