import Foundation

/// Strict RIFF PCM reader; skips metadata and emits a minimal PCM WAV.
struct TD27Wave {
    let channels: Int
    let sampleRate: Int
    let bits: Int
    let pcm: Data
    var frames: Int { pcm.count / (channels * bits / 8) }
    var duration: Double { Double(frames) / Double(sampleRate) }
    var moduleReady: Bool { sampleRate == 44100 && [16,24].contains(bits) && duration <= 180 }
    init(_ data: Data) throws {
        func fail(_ s: String) -> TD27File.Failure { .invalid(s) }
        guard data.count >= 44, data.count <= 128*1024*1024,
              data.prefix(4) == Data("RIFF".utf8), data[8..<12] == Data("WAVE".utf8) else {
            throw fail("Expected a RIFF/WAVE file, maximum 128 MiB.")
        }
        let end = Int(TD27File.u32(data, 4)) + 8
        guard end == data.count else { throw fail("WAV size does not match RIFF header.") }
        var format: (Int,Int,Int)?
        var audio: Data?
        var pos = 12
        func u16(_ p: Int) -> Int { Int(data[p]) | Int(data[p+1]) << 8 }
        while pos < end {
            guard pos <= end-8 else { throw fail("Truncated WAV chunk.") }
            let n = Int(TD27File.u32(data, pos+4)), start = pos+8
            guard n <= end-start else { throw fail("Truncated WAV payload.") }
            let tag = data[pos..<pos+4]
            if tag == Data("fmt ".utf8) {
                guard format == nil, n >= 16, u16(start) == 1 else {
                    throw fail("Use integer PCM WAV (16/24 bit); float/compressed/extensible WAV is not supported yet.")
                }
                let ch = u16(start+2), rate = Int(TD27File.u32(data,start+4)), depth = u16(start+14)
                guard [1,2].contains(ch), [16,24].contains(depth), (8000...192000).contains(rate),
                      u16(start+12) == ch*depth/8,
                      Int(TD27File.u32(data,start+8)) == rate*ch*depth/8 else { throw fail("Invalid PCM format.") }
                format = (ch,rate,depth)
            } else if tag == Data("data".utf8) {
                guard audio == nil else { throw fail("Multiple WAV data chunks are not supported.") }
                audio = Data(data[start..<start+n])
            }
            pos = start+n+(n % 2)
            guard pos <= end else { throw fail("Missing WAV chunk padding.") }
        }
        guard let (ch,rate,depth) = format, let audio, !audio.isEmpty,
              audio.count % (ch*depth/8) == 0 else { throw fail("Missing format/audio or incomplete PCM frame.") }
        channels = ch; sampleRate = rate; bits = depth; pcm = audio
        guard duration <= 180 else { throw fail("TD-27 samples must be at most 180 seconds.") }
    }
    func cleanWAV() -> Data {
        var result = Data("RIFF".utf8)
        func append(_ value: Int, bytes: Int) { for i in 0..<bytes { result.append(UInt8((value >> (i*8)) & 255)) } }
        append(36+pcm.count+(pcm.count % 2),bytes:4)
        result.append(Data("WAVEfmt ".utf8)); append(16,bytes:4); append(1,bytes:2)
        append(channels,bytes:2); append(sampleRate,bytes:4)
        append(sampleRate*channels*bits/8,bytes:4); append(channels*bits/8,bytes:2); append(bits,bytes:2)
        result.append(Data("data".utf8)); append(pcm.count,bytes:4); result.append(pcm)
        if pcm.count % 2 != 0 { result.append(0) }
        return result
    }
}
