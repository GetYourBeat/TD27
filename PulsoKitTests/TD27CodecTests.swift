import Foundation
import CryptoKit
import Testing
@testable import PulsoKit

@MainActor
struct TD27CodecTests {
    private func core() -> Data {
        var data = Data(repeating:0,count:4256)
        data.replaceSubrange(0..<8,with:Data("TD-27\0KT".utf8))
        data.replaceSubrange(20..<24,with:Data("1.02".utf8))
        data.replaceSubrange(48..<60,with:Data("Test        ".utf8))
        data.replaceSubrange(4240..<4256,with:Data(Insecure.MD5.hash(data:data.prefix(4240))))
        return data
    }
    @Test func monoStereoBoundaryRoundTrips() throws {
        for channels in [1,2] {
            for frames in [1,31,32,33,191,192,193,255,256,257,65535,65536] {
                var pcm = Data(repeating:0,count:frames*channels*2)
                for i in 0..<frames*channels { TD27Codec.put((i*731)%65536-32768,in:&pcm,at:i*2,bytes:2) }
                let encoded = try TD27Codec.encode(pcm:pcm,channels:channels,slot:499,filename:"Test.wav")
                let decoded = try TD27Codec.decode(encoded)
                #expect(decoded.pcm == pcm)
                #expect(decoded.channels == channels)
                #expect(decoded.slot == 499)
                #expect(try TD27Wave(TD27Codec.wav(decoded)).pcm == pcm)
            }
        }
    }
    @Test func corruptedPaddingRejected() throws {
        var block = try TD27Codec.encode(pcm:Data(repeating:0,count:400),channels:1,slot:2,filename:"a.wav")
        block[48] = 1
        #expect(throws: (any Error).self) { try TD27Codec.decode(block) }
    }
    @Test func templateRequired() throws {
        #expect(throws: (any Error).self) { try TD27Codec.export(TD27Project()) }
    }
    @Test func exportContainsAssignedAudioAndPreservesOtherZones() throws {
        let pcm = Data([0,0,1,0,255,127,0,128])
        let block = try TD27Codec.encode(pcm:pcm,channels:1,slot:2,filename:"golden.wav")
        let audio = try TD27Codec.decode(block)
        var project = TD27Project();project.title = "MY KIT";project.sourceTD0 = core()
        let sample = TD27Project.Sample(name:"golden",wav:TD27Codec.wav(audio))
        project.samples = [sample];project.zones[0].sampleID = sample.id
        project.zones[0].volumeDB = -3.5;project.zones[0].pan = -0.5;project.zones[0].semitones = 2
        let result = try TD27Codec.export(project), file = try TD27File(result)
        let decoded = try TD27Codec.blocks(file)
        #expect(file.kitName == "MY KIT")
        #expect(decoded.count == 1)
        #expect(try TD27Codec.decode(try #require(decoded[2])).pcm == pcm)
        #expect(TD27Codec.u16(result,0x594) == 2)
        #expect(result[0x598] == 1)
        #expect(result[0x1D4] == 241)
        #expect(result[0x594+28..<4240] == core()[0x594+28..<4240])
        let digest = SHA256.hash(data:result).map { String(format:"%02x",$0) }.joined()
        #expect(digest == "31e0a14b3c6d4a63cc51a876ebce6daad74c504112853ae9aefa8daab64d3bd1")
    }
    @Test func originalSampleFixtureRoundTripWhenProvided() throws {
        guard let folder = ProcessInfo.processInfo.environment["TD27_FIXTURES"] else { return }
        let source = try Data(contentsOf:URL(fileURLWithPath:folder).appendingPathComponent("KIT-130(1).TD0"))
        let file = try TD27File(source)
        for block in try TD27Codec.blocks(file).values {
            let a = try TD27Codec.decode(block)
            #expect(try TD27Codec.encode(pcm:a.pcm,channels:a.channels,slot:a.slot,filename:"",tails:a.alignmentTails,originalHeader:a.header) == block)
        }
        var project = TD27Project();project.sourceTD0 = source;project.title = file.kitName
        #expect(try TD27Codec.export(project) == source)
    }
}
