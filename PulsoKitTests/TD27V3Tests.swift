import Foundation
import CryptoKit
import Testing
@testable import PulsoKit

@MainActor
struct TD27V3Tests {
    func core(version: String = "1.02") -> Data {
        let modern = version == "2.21"
        var d = Data(repeating:0,count:modern ? 4288 : 4256)
        d.replaceSubrange(0..<8,with:Data("TD-27\0KT".utf8))
        d.replaceSubrange(20..<24,with:Data(version.utf8))
        let start = modern ? 80 : 48
        d.replaceSubrange(start..<start+12,with:Data("Test        ".utf8))
        d.replaceSubrange(d.count-16..<d.count,with:Data(Insecure.MD5.hash(data:d.dropLast(16))))
        return d
    }
    @Test func modernCoreUsesItsOwnNameAndChecksumOffsets() throws {
        let data = core(version:"2.21"), file = try TD27File(data)
        #expect(file.coreLength == 4288)
        #expect(file.kitName == "Test")
        #expect(file.originalCopy() == data)
        #expect(!file.canExportSamples)
        var corrupted = data; corrupted[80] ^= 1
        #expect(throws: (any Error).self) { try TD27File(corrupted) }
        #expect(throws: (any Error).self) { try TD27File(Data(data.dropLast())) }
        var p = TD27Project(); p.sourceTD0 = data
        #expect(throws: (any Error).self) { try TD27Codec.export(p) }
    }
    @Test func legacyProjectDefaultsDoNotRequireNewFields() throws {
        let data = try JSONEncoder().encode(TD27Project())
        let p = try JSONDecoder().decode(TD27Project.self,from:data).validated()
        #expect(p.zones[0].instrumentPitch == nil)
        #expect(p.zones[0].instrumentDecay == nil)
        #expect(p.crossStick == nil)
    }
    @Test func crossStickChangesOnlyItsOwnFields() throws {
        var p = TD27Project(); p.sourceTD0 = core(); p.title = "Test"
        let unchanged = try TD27Codec.export(p)
        p.crossStick = .init(instrument:15,volumeDB:-3.5)
        let changed = try TD27Codec.export(p)
        #expect(changed[81] == 15)
        #expect(Int16(bitPattern:UInt16(TD27Codec.u16(changed,82))) == -35)
        for i in 0..<4240 where !(81...83).contains(i) { #expect(changed[i] == unchanged[i]) }
    }
    @Test func resetClearsBothPitchAndDecayLayers() throws {
        let model = TD27StudioModel(loadSavedBase:false)
        model.project.zones[0].instrumentPitch = 34
        model.project.zones[0].instrumentDecay = 2
        model.project.zones[0].padDecay = 20
        model.project.zones[0].semitones = 4
        model.resetSelectedSample()
        #expect(model.project.zones[0].instrumentPitch == 0)
        #expect(model.project.zones[0].instrumentDecay == 100)
        #expect(model.project.zones[0].padDecay == 100)
        #expect(model.project.zones[0].semitones == 0)
    }
    @Test func reopenedSamplesReuseOriginalAudioSlots() throws {
        var p = TD27Project();p.sourceTD0 = core();p.title = "Test"
        let audio = try TD27Codec.decode(TD27Codec.encode(pcm:Data([1,0,2,0]),channels:1,slot:2,filename:"x.wav"))
        let sample = TD27Project.Sample(name:"x",wav:TD27Codec.wav(audio))
        p.samples = [sample];p.zones[0].sampleID = sample.id
        let exported = try TD27Codec.export(p)
        let model = TD27StudioModel(loadSavedBase:false);try model.loadKit(exported)
        #expect(model.project.samples.count == 1)
        #expect(model.project.samples[0].sourceSlot == 2)
        let again = try TD27Codec.export(model.project)
        #expect(try TD27Codec.blocks(TD27File(again)).count == 1)
        #expect(again == exported)
    }
}
