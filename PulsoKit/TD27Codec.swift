import Foundation
import CryptoKit

/// File writer based on 29 observed sample blocks and three independent sample kits.
/// Original sample export has passed a user hardware import. New layering edits need hardware acceptance.
enum TD27Codec {
    static let vEditMainBase = 0xADC
    static let vEditSubBase = 0xD1C
    static let vEditStride = 24
    static let mainBase = 0x594
    static let subBase = 0x834
    static let commonBase = 0x1D4
    struct Audio {
        let slot: Int
        let channels: Int
        let pcm: Data // Interleaved signed little-endian 16-bit / 44.1 kHz
        let alignmentTails: [Data]
        let header: Data
    }
    static func aligned(_ n: Int, _ unit: Int) -> Int { (n+unit-1)/unit*unit }
    static func u16(_ data: Data, _ offset: Int) -> Int { Int(data[offset]) | Int(data[offset+1]) << 8 }
    static func put(_ value: Int, in data: inout Data, at offset: Int, bytes: Int) {
        for i in 0..<bytes { data[offset+i] = UInt8(truncatingIfNeeded: value >> (i*8)) }
    }
    static func name(_ value: String, count: Int, padding: UInt8 = 32) -> Data {
        let ascii = value.unicodeScalars.map { $0.value >= 32 && $0.value <= 126 ? UInt8($0.value) : 95 }
        return Data(ascii.prefix(count)) + Data(repeating: padding, count: max(0,count-ascii.count))
    }
    static func decode(_ input: Data) throws -> Audio {
        let block = Data(input)
        guard block.count >= 48, block.prefix(4) == Data("SMPd".utf8) else { throw TD27File.Failure.invalid("Missing SMPd header.") }
        let flags = u16(block,32), channels = flags & 0x8000 == 0 ? 1 : 2
        let slot = flags & 0x7FFF, n = Int(TD27File.u32(block,12))
        let stride = aligned(n+128,512), rounded = aligned(n,64)
        guard n > 0, n % 2 == 0, n <= 44100*180*2, slot < 500,
              u16(block,4) == 48, u16(block,6) == aligned(stride,131072)/131072,
              Int(TD27File.u32(block,8)) == stride*channels, block.count == 48+stride*channels else {
            throw TD27File.Failure.invalid("Unsupported sample encoding or sample length.")
        }
        var pcm = Data(repeating:0,count:n*channels), tails: [Data] = []
        for c in 0..<channels {
            let base = 48+c*stride, end = base+64+rounded
            guard block[base..<base+64].allSatisfy({ $0 == 0 }),
                  block[end..<end+64].allSatisfy({ $0 == 0 }),
                  block[end+64..<base+stride].allSatisfy({ $0 == 255 }) else {
                throw TD27File.Failure.invalid("Unknown sample channel padding.")
            }
            for frame in 0..<n/2 {
                let from = base+64+frame*2, to = (frame*channels+c)*2
                pcm[to] = block[from]; pcm[to+1] = block[from+1]
            }
            tails.append(Data(block[base+64+n..<end]))
        }
        return Audio(slot:slot,channels:channels,pcm:pcm,alignmentTails:tails,header:Data(block.prefix(48)))
    }
    static func encode(pcm: Data, channels: Int, slot: Int, filename: String,
                       tails: [Data]? = nil, originalHeader: Data? = nil) throws -> Data {
        guard [1,2].contains(channels), (0..<500).contains(slot), !pcm.isEmpty, pcm.count % (2*channels) == 0 else {
            throw TD27File.Failure.invalid("Invalid PCM sample.")
        }
        let n = pcm.count/channels, stride = aligned(n+128,512), rounded = aligned(n,64)
        guard n <= 44100*180*2, originalHeader == nil || originalHeader?.count == 48,
              tails == nil || tails?.count == channels else { throw TD27File.Failure.invalid("Invalid sample length/header.") }
        var header = originalHeader ?? Data(repeating:0,count:48)
        header.replaceSubrange(0..<4,with:Data("SMPd".utf8))
        put(48,in:&header,at:4,bytes:2); put(aligned(stride,131072)/131072,in:&header,at:6,bytes:2)
        put(stride*channels,in:&header,at:8,bytes:4);put(n,in:&header,at:12,bytes:4)
        put(slot | (channels == 2 ? 0x8000 : 0),in:&header,at:32,bytes:2)
        if originalHeader == nil { header.replaceSubrange(16..<32,with:name(filename,count:16,padding:0)) }
        var payload = Data(repeating:255,count:stride*channels)
        for c in 0..<channels {
            let base = c*stride
            payload.replaceSubrange(base..<base+rounded+128,with:Data(repeating:0,count:rounded+128))
            for frame in 0..<n/2 {
                let from = (frame*channels+c)*2, to = base+64+frame*2
                payload[to] = pcm[from];payload[to+1] = pcm[from+1]
            }
            if let tails {
                guard tails[c].count == rounded-n else { throw TD27File.Failure.invalid("Alignment tail size mismatch.") }
                payload.replaceSubrange(base+64+n..<base+64+rounded,with:tails[c])
            }
        }
        return header+payload
    }
    static func pcm16(_ wav: TD27Wave) -> Data {
        if wav.bits == 16 { return wav.pcm }
        // Explicit 24 -> 16 bit truncation; no hidden format conversion.
        var pcm = Data(repeating:0,count:wav.pcm.count/3*2)
        for i in 0..<wav.pcm.count/3 { pcm[i*2] = wav.pcm[i*3+1];pcm[i*2+1] = wav.pcm[i*3+2] }
        return pcm
    }
    static func wav(_ audio: Audio) -> Data {
        var header = Data(repeating:0,count:44)
        header.replaceSubrange(0..<4,with:Data("RIFF".utf8));put(36+audio.pcm.count,in:&header,at:4,bytes:4)
        header.replaceSubrange(8..<16,with:Data("WAVEfmt ".utf8));put(16,in:&header,at:16,bytes:4)
        put(1,in:&header,at:20,bytes:2);put(audio.channels,in:&header,at:22,bytes:2)
        put(44100,in:&header,at:24,bytes:4);put(88200*audio.channels,in:&header,at:28,bytes:4)
        put(audio.channels*2,in:&header,at:32,bytes:2);put(16,in:&header,at:34,bytes:2)
        header.replaceSubrange(36..<40,with:Data("data".utf8));put(audio.pcm.count,in:&header,at:40,bytes:4)
        return header+audio.pcm
    }
    static func blocks(_ file: TD27File) throws -> [Int: Data] {
        var result: [Int:Data] = [:]
        for record in file.blocks {
            let block = Data(file.bytes[record.offset..<record.offset+48+record.payloadBytes])
            let decoded = try decode(block)
            guard result[decoded.slot] == nil else { throw TD27File.Failure.invalid("Duplicate sample slot.") }
            result[decoded.slot] = block
        }
        return result
    }
    static func export(_ project: TD27Project) throws -> Data {
        _ = try project.validated()
        guard let source = project.sourceTD0 else { throw TD27File.Failure.invalid("Open an original TD-27 TD0 as a template first.") }
        let file = try TD27File(source)
        guard file.canExportSamples else { throw TD27File.Failure.invalid("This 2.21 core can be inspected/copied, but its sample container is not verified. Choose a 1.01/1.02 base (for example your working exported kit) for WAV export.") }
        var core = Data(source.prefix(4256)), existing = try blocks(file)
        var metadata: Data? = source.count > 4256 ? Data(source[4256..<20304]) : nil
        var used = Set(existing.keys), slots: [UUID:Int] = [:]
        // Even disabled sub-layers must not create references to absent sample data.
        for base in [mainBase,subBase] {
            for i in 0..<24 {
                let offset = base+i*28
                guard source[offset+4] <= 1 else { throw TD27File.Failure.invalid("Unknown instrument bank in template.") }
                guard source[offset+4] == 1 else { continue }
                let slot = u16(source,offset)
                guard existing[slot] != nil else { throw TD27File.Failure.invalid("Template refers to a user sample without embedded audio.") }
                used.insert(slot)
            }
        }
        if let metadata {
            for i in 0..<500 {
                let label = TD27File.ascii(metadata,48+i*32,16)
                if !label.isEmpty && label != "----------------" { used.insert(i) }
            }
        }
        if project.title == file.kitName, project.crossStick == nil, project.muteUnassigned != true,
           project.zones.allSatisfy({ $0.mainEdited == false && $0.panEdited != true && $0.layer == nil && $0.sub?.edited != true }) {
            return source // Preserve header padding, opaque framing and original block order too.
        }
        let kitName = name(project.title,count:12)
        core.replaceSubrange(8..<20,with:kitName);core.replaceSubrange(48..<60,with:kitName)
        if let crossStick = project.crossStick {
            core[81] = UInt8(crossStick.instrument)
            put(Int((crossStick.volumeDB*10).rounded()),in:&core,at:82,bytes:2)
        }
        func assignSample(_ id: UUID, zoneIndex: Int, sub: Bool, volume: Double,
                          semitones: Double, instrumentPitch: Double, decay: Double, padDecay: Double) throws {
            guard let sample = project.samples.first(where: { $0.id == id }) else {
                throw TD27File.Failure.invalid("Sample is missing from the project.")
            }
            if slots[id] == nil, let oldSlot = sample.sourceSlot, let original = existing[oldSlot] {
                let decoded = try decode(original), wave = try TD27Wave(sample.wav)
                if decoded.channels == wave.channels && decoded.pcm == pcm16(wave) { slots[id] = oldSlot }
            }
            if slots[id] == nil {
                guard let slot = (2..<500).first(where: { !used.contains($0) }) else { throw TD27File.Failure.invalid("No unused sample slots.") }
                let wave = try TD27Wave(sample.wav)
                existing[slot] = try encode(pcm:pcm16(wave),channels:wave.channels,slot:slot,filename:sample.name+".wav")
                used.insert(slot);slots[id] = slot
                if metadata == nil {
                    var fresh = Data(repeating:0,count:48+500*32)
                    fresh.replaceSubrange(0..<18,with:Data("TD-27\0USUsrSmplPrm".utf8))
                    fresh.replaceSubrange(20..<36,with:core[20..<36]);fresh[41] = 1
                    for i in 0..<500 { fresh.replaceSubrange(48+i*32..<64+i*32,with:Data(repeating:45,count:16)) }
                    metadata = fresh
                }
                var record = name(sample.name,count:16)+Data(repeating:0,count:16)
                record[24] = 1 // Same one-shot drum mode seen in the reference drum samples.
                metadata!.replaceSubrange(48+slot*32..<80+slot*32,with:record)
            }
            let offset = (sub ? subBase : mainBase)+zoneIndex*28
            let replacing = core[offset+4] != 1 || u16(core,offset) != slots[id]!
            put(slots[id]!,in:&core,at:offset,bytes:2)
            put(Int((volume*10).rounded()),in:&core,at:offset+2,bytes:2)
            core[offset+4] = 1
            if replacing { core[offset+5] = 0; core[offset+10] = 0; core[offset+14] = 0 }
            core[offset+11] = UInt8(padDecay.rounded())
            put(Int((semitones*100).rounded()),in:&core,at:offset+12,bytes:2)
            let vedit = (sub ? vEditSubBase : vEditMainBase)+zoneIndex*vEditStride
            core[vedit] = UInt8(truncatingIfNeeded:Int(instrumentPitch.rounded()))
            core[vedit+1] = UInt8(decay.rounded())
        }
        for (zoneIndex,zone) in project.zones.enumerated() {
            let common = commonBase+zoneIndex*40
            if zone.sampleID == nil && project.muteUnassigned == true {
                put(-600,in:&core,at:mainBase+zoneIndex*28+2,bytes:2)
                core[common+5] = 0
            }
            if let id = zone.sampleID, zone.mainEdited != false {
                try assignSample(id, zoneIndex:zoneIndex, sub:false, volume:zone.volumeDB,
                    semitones:zone.semitones, instrumentPitch:zone.instrumentPitch ?? 0,
                    decay:zone.instrumentDecay ?? 100, padDecay:zone.padDecay ?? 100)
                core[common] = UInt8(truncatingIfNeeded:Int((zone.pan*30).rounded()))
                // Legacy projects disabled the sub layer. New projects explicitly preserve/control it.
                if zone.layer == nil && zone.mainEdited == nil { core[common+5] = 0 }
            }
            if let sub = zone.sub, sub.edited, let id = sub.sampleID {
                try assignSample(id, zoneIndex:zoneIndex, sub:true, volume:sub.volumeDB,
                    semitones:sub.semitones, instrumentPitch:sub.instrumentPitch,
                    decay:sub.instrumentDecay, padDecay:sub.padDecay)
            }
            if zone.panEdited == true { core[common] = UInt8(truncatingIfNeeded:Int((zone.pan*30).rounded())) }
            if let layer = zone.layer {
                core[common+5] = layer.enabled ? 1 : 0
                core[common+6] = UInt8(layer.mode)
                put(layer.fadePoint,in:&core,at:common+8,bytes:2)
            }
        }
        if !existing.isEmpty { core[40] = 1;core[41] = 1 }
        core.replaceSubrange(4240..<4256,with:Data(Insecure.MD5.hash(data:core.prefix(4240))))
        var result = core
        if !existing.isEmpty {
            guard let metadata else { throw TD27File.Failure.invalid("Missing metadata.") }
            var seconds = 0.0
            for block in existing.values { seconds += Double(try decode(block).pcm.count)/88200 }
            guard seconds <= 1440 else { throw TD27File.Failure.invalid("Samples exceed 24 mono-equivalent minutes including preserved samples.") }
            result.append(metadata);result.append(Data(Insecure.MD5.hash(data:metadata)))
            var header = Data(repeating:0,count:32);header.replaceSubrange(0..<4,with:Data("SMPh".utf8))
            put(32,in:&header,at:4,bytes:4);put(2,in:&header,at:8,bytes:4);put(existing.count,in:&header,at:12,bytes:4)
            result.append(header)
            for slot in existing.keys.sorted() { result.append(existing[slot]!) }
        }
        let parsed = try TD27File(result);_ = try blocks(parsed)
        return result
    }
}
