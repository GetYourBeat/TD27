import Foundation
import CryptoKit

var checks = 0
func check(_ condition: Bool, _ message: String) {
    precondition(condition, message); checks += 1
}
func rejects(_ body: () throws -> Void) {
    do { try body(); fatalError("Expected rejection") } catch { checks += 1 }
}
func makeCore() -> Data {
    var d = Data(repeating: 0, count: 4256)
    d.replaceSubrange(0..<8, with: Data("TD-27\0KT".utf8))
    d.replaceSubrange(20..<24, with: Data("1.02".utf8))
    d.replaceSubrange(48..<60, with: Data("TEST        ".utf8))
    d.replaceSubrange(4240..<4256, with: Data(Insecure.MD5.hash(data: d.prefix(4240))))
    return d
}
func makeWave(bits: Int = 16, rate: Int = 44100, samples: Int = 4) -> Data {
    var d = Data("RIFF".utf8)
    func put(_ v: Int, _ n: Int) { for i in 0..<n { d.append(UInt8((v >> (8*i)) & 255)) } }
    let bytes = samples*bits/8
    put(36+bytes+bytes%2,4); d.append(Data("WAVEfmt ".utf8));put(16,4);put(1,2);put(1,2)
    put(rate,4);put(rate*bits/8,4);put(bits/8,2);put(bits,2);d.append(Data("data".utf8));put(bytes,4)
    d.append(Data(repeating: 0, count: bytes+bytes%2));return d
}
let original = makeCore()
let parsed = try TD27File(original)
check(parsed.kitName == "TEST", "name")
check(parsed.originalCopy() == original, "lossless copy")
var corrupt = original; corrupt[99] ^= 1
rejects { _ = try TD27File(corrupt) }
for size in [0,8,4240,4255] { rejects { _ = try TD27File(original.prefix(size)) } }
var sampleContainer = original
sampleContainer.append(Data(repeating: 0, count: 20352-4256))
sampleContainer.replaceSubrange(4256..<4274, with: Data("TD-27\0USUsrSmplPrm".utf8))
sampleContainer.replaceSubrange(4276..<4280, with: Data("1.02".utf8))
sampleContainer.replaceSubrange(20304..<20320, with: Data(Insecure.MD5.hash(data: sampleContainer[4256..<20304])))
sampleContainer.replaceSubrange(20320..<20324, with: Data("SMPh".utf8))
sampleContainer[20324] = 32; sampleContainer[20328] = 2; sampleContainer[20332] = 1
var block = Data(repeating: 0, count: 52)
block.replaceSubrange(0..<4, with: Data("SMPd".utf8)); block[8] = 4
sampleContainer.append(block)
check(try TD27File(sampleContainer).blocks.count == 1, "sample block framing")
rejects { _ = try TD27File(sampleContainer.dropLast()) }
var badMetadata = sampleContainer; badMetadata[4304] ^= 1
rejects { _ = try TD27File(badMetadata) }
var badLength = sampleContainer
badLength.replaceSubrange(20360..<20364, with: Data(repeating: 255, count: 4))
rejects { _ = try TD27File(badLength) }
for bits in [16,24] {
    let data = makeWave(bits: bits, samples: 3)
    let wave = try TD27Wave(data)
    check(wave.frames == 3 && wave.moduleReady, "PCM frames")
    check(try TD27Wave(wave.cleanWAV()).pcm == wave.pcm, "PCM round trip")
}
check(try !TD27Wave(makeWave(rate: 48000)).moduleReady, "conversion needed")
rejects { _ = try TD27Wave(makeWave().dropLast()) }
var bad = makeWave();bad[20] = 3
rejects { _ = try TD27Wave(bad) }
if CommandLine.arguments.count > 1 {
    let folder = URL(fileURLWithPath: CommandLine.arguments[1])
    for name in ["KIT-008(1).TD0", "KIT-130(1).TD0"] {
        let data = try Data(contentsOf: folder.appendingPathComponent(name))
        let file = try TD27File(data)
        check(file.originalCopy() == data, "Original fixture byte preservation")
        check(file.blocks.count == (name.contains("130") ? 8 : 0), "sample count")
    }
}
print("Passed \(checks) Swift core checks")
