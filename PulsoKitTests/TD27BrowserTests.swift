import Foundation
import CryptoKit
import Testing
@testable import PulsoKit

@MainActor
struct TD27BrowserTests {
    @Test func kitAddressCarriesInSevenBitSpace() throws {
        #expect(TD27KitBrowser.address(kit:1) == [4,0,0,0])
        #expect(TD27KitBrowser.address(kit:50) == [4,98,0,0])
        #expect(TD27KitBrowser.address(kit:64) == [4,126,0,0])
        #expect(TD27KitBrowser.address(kit:65) == [5,0,0,0])
        #expect(TD27KitBrowser.address(kit:76,offset:16384+128) == [5,23,1,0])
        #expect(TD27KitBrowser.address(kit:78) == [5,26,0,0])
        #expect(TD27KitBrowser.address(kit:100) == [5,70,0,0])
        #expect(TD27KitBrowser.address(kit:0) == nil)
        #expect(TD27KitBrowser.address(kit:101) == nil)
        #expect(TD27KitBrowser.address(kit:1,offset:32768) == nil)
        let addresses = (1...100).compactMap { TD27KitBrowser.address(kit:$0) }
        #expect(Set(addresses).count == 100)
        #expect(addresses.flatMap { $0 }.allSatisfy { $0 < 128 })
    }
    @Test func nibbleIDsAndBanksAreDistinct() throws {
        let sample = try TD27KitBrowser.instrument([0,0,2,13,0,0,0,0,1])
        #expect(sample.number == 45)
        #expect(sample.label.hasPrefix("U046"))
        let factory = try TD27KitBrowser.instrument([0,0,2,13,0,0,0,0,0])
        #expect(factory.number == 45)
        #expect(!factory.label.hasPrefix("U"))
        #expect(throws:(any Error).self) { try TD27KitBrowser.instrument([0,0,16,0,0,0,0,0,1]) }
        #expect(throws:(any Error).self) { try TD27KitBrowser.instrument([0,1,15,4,0,0,0,0,1]) }
        #expect(throws:(any Error).self) { try TD27KitBrowser.instrument([]) }
        #expect(throws:(any Error).self) { try TD27KitBrowser.name([1,2]) }
    }
    func source() -> Data {
        TD27V3Tests().core()
    }
    func sample(_ name: String, pcm: Data = Data([1,0,2,0])) throws -> TD27Project.Sample {
        let block = try TD27Codec.encode(pcm:pcm,channels:1,slot:2,filename:name)
        return .init(name:name,wav:TD27Codec.wav(try TD27Codec.decode(block)))
    }
    @Test func subAssignmentDoesNotReplaceMainOrOtherZones() throws {
        var p = TD27Project(); p.sourceTD0 = source(); p.title = "Test"
        let main = try sample("soft"), sub = try sample("hard",pcm:Data([3,0,4,0]))
        p.samples = [main,sub]; p.zones[1].sampleID = main.id
        let before = try TD27Codec.export(p)
        let model = TD27StudioModel(loadSavedBase:false); try model.loadKit(before)
        model.project.samples.append(sub)
        model.selectedZone = 1; model.selectedLayer = 1; model.selectedSample = sub.id; model.assign()
        model.project.zones[1].layer = .init(enabled:true,mode:4,fadePoint:87)
        let after = try TD27Codec.export(model.project)
        let m = TD27Codec.mainBase+28, common = TD27Codec.commonBase+40
        #expect(after[m..<m+28] == before[m..<m+28])
        #expect(after[common+5] == 1)
        #expect(after[common+6] == 4)
        #expect(TD27Codec.u16(after,common+8) == 87)
        let s = TD27Codec.subBase+28
        #expect(after[s+4] == 1)
        #expect(TD27Codec.u16(after,s) != TD27Codec.u16(after,m))
        for i in 0..<24 where i != 1 {
            for (base,stride) in [(TD27Codec.mainBase,28),(TD27Codec.subBase,28),(TD27Codec.commonBase,40),(TD27Codec.vEditMainBase,24),(TD27Codec.vEditSubBase,24)] {
                let o = base+i*stride
                #expect(after[o..<o+stride] == before[o..<o+stride])
            }
        }
        let reopened = TD27StudioModel(loadSavedBase:false); try reopened.loadKit(after)
        #expect(reopened.project.samples.count == 2)
        #expect(reopened.project.zones[1].sub?.sampleID != nil)
        #expect(try TD27Codec.export(reopened.project) == after)
    }
    @Test func untouchedLoadedFileIsByteIdentical() throws {
        var p = TD27Project(); p.sourceTD0 = source(); p.title = "Test"
        let a = try sample("A"); p.samples = [a]; p.zones[0].sampleID = a.id
        var bytes = try TD27Codec.export(p)
        // Fields not exposed in the UI must survive load/export unchanged, including edited-zone extras.
        bytes[TD27Codec.mainBase+14] = 77
        bytes[TD27Codec.mainBase+5] = 1
        bytes[TD27Codec.mainBase+10] = 2
        bytes[4240..<4256] = Data(Insecure.MD5.hash(data:bytes.prefix(4240)))
        let model = TD27StudioModel(loadSavedBase:false); try model.loadKit(bytes)
        #expect(try TD27Codec.export(model.project) == bytes)
        model.project.zones[0].mainEdited = true
        model.project.zones[0].instrumentPitch = -25
        let edited = try TD27Codec.export(model.project)
        #expect(edited[TD27Codec.mainBase+14] == 77)
        #expect(edited[TD27Codec.mainBase+5] == 1)
        #expect(edited[TD27Codec.mainBase+10] == 2)
        #expect(edited[TD27Codec.vEditMainBase] == 231)
    }
    @Test func missingAudioBlocksRefuseCompleteExport() throws {
        var bytes = source(); bytes[TD27Codec.subBase+4] = 1
        bytes[4240..<4256] = Data(Insecure.MD5.hash(data:bytes.prefix(4240)))
        var p = TD27Project(); p.sourceTD0 = bytes
        #expect(throws:(any Error).self) { try TD27Codec.export(p) }
    }
    @Test func fullProjectPersistsSourceTargetAndBothLayers() throws {
        var p = TD27Project(); p.sourceKitNumber = 50; p.targetKitNumber = 78; p.sdFileNumber = 999
        p.samples = [try sample("x")]; p.zones[2].sub = .init(sampleID:p.samples[0].id,edited:true)
        p.zones[2].layer = .init(enabled:true,mode:3,fadePoint:159)
        let roundTrip = try JSONDecoder().decode(TD27Project.self,from:JSONEncoder().encode(p)).validated()
        #expect(roundTrip.sourceKitNumber == 50); #expect(roundTrip.targetKitNumber == 78)
        #expect(roundTrip.zones[2].sub?.sampleID == p.samples[0].id)
        p.targetKitNumber = 101
        #expect(throws:(any Error).self) { try p.validated() }
        p.targetKitNumber = 78; p.zones[2].layer?.fadePoint = 160
        #expect(throws:(any Error).self) { try p.validated() }
    }
    @Test func editingExistingMainKeepsSubEnabledWithoutExplicitLayerEdit() throws {
        var p = TD27Project(); p.sourceTD0 = source(); p.title = "Test"
        let a = try sample("a"); p.samples = [a]
        p.zones[1].sampleID = a.id
        p.zones[1].sub = .init(sampleID:a.id,edited:true)
        p.zones[1].layer = .init(enabled:true,mode:4,fadePoint:87)
        let original = try TD27Codec.export(p)
        let model = TD27StudioModel(loadSavedBase:false); try model.loadKit(original)
        model.project.zones[1].instrumentPitch = -25
        model.project.zones[1].mainEdited = true
        let edited = try TD27Codec.export(model.project)
        let common = TD27Codec.commonBase+40
        #expect(edited[common..<common+40] == original[common..<common+40])
        let sub = TD27Codec.subBase+28
        #expect(edited[sub..<sub+28] == original[sub..<sub+28])
    }
    @Test func newKitAssignmentDoesNotReactivateInheritedSub() throws {
        var bytes = source(); bytes[TD27Codec.commonBase+5] = 1
        bytes[4240..<4256] = Data(Insecure.MD5.hash(data:bytes.prefix(4240)))
        let model = TD27StudioModel(loadSavedBase:false)
        model.project.sourceTD0 = bytes; model.project.muteUnassigned = true
        let a = try sample("a"); model.project.samples = [a]; model.selectedSample = a.id
        model.assign()
        #expect(model.project.zones[0].layer?.enabled == false)
        #expect(try TD27Codec.export(model.project)[TD27Codec.commonBase+5] == 0)
    }
    @Test func newProjectVersionProtectsAgainstOldEditorDataLoss() throws {
        #expect(TD27Project().schema == 2)
        var old = TD27Project(); old.schema = 1
        #expect(try old.validated().schema == 1)
        old.schema = 99
        #expect(throws:(any Error).self) { try old.validated() }
    }

}
