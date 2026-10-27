import Foundation
import CryptoKit

/// Evidence-based TD-27 1.01/1.02 container reader. Never reuses TD-17 offsets.
struct TD27File {
    static let coreSize = 4256
    static let metadataEnd = 20320
    let version: String
    let coreLength: Int
    let bodyOffset: Int
    var canExportSamples: Bool { version != "2.21" }
    let bytes: Data
    let kitName: String
    let sampleNames: [String]
    let blocks: [SampleBlock]
    struct SampleBlock: Identifiable {
        let id: Int
        let offset: Int
        let payloadBytes: Int
        let opaqueWord: UInt32
        let frameCountCandidate: UInt32
        let name: String
        let referenceCandidate: UInt16
    }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil }
    }
    static func ascii(_ data: Data, _ offset: Int, _ length: Int) -> String {
        String(decoding: data[offset..<offset+length].prefix { $0 != 0 }, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
    }
    static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[offset+$1]) << (8*$1) }
    }
    init(_ input: Data) throws {
        let data = Data(input)
        guard data.count >= Self.coreSize, data.count <= 256 * 1024 * 1024 else {
            throw Failure.invalid("TD0: truncated core or file exceeds 256 MiB.")
        }
        guard data.prefix(8) == Data("TD-27\0KT".utf8) else {
            throw Failure.invalid("Expected TD-27 TD0; TDZ presets are a different format.")
        }
        version = Self.ascii(data, 20, 4)
        coreLength = version == "2.21" ? 4288 : 4256
        bodyOffset = version == "2.21" ? 80 : 48
        guard ["1.01", "1.02", "2.21"].contains(version), data.count >= coreLength else {
            throw Failure.invalid("Supported TD-27 versions: 1.01/1.02 and core-only 2.21.")
        }
        func checkMD5(_ start: Int, _ end: Int) throws {
            guard Data(Insecure.MD5.hash(data: data[start..<end])) == data[end..<end+16] else {
                throw Failure.invalid("MD5 mismatch at byte \(end).")
            }
        }
        try checkMD5(0, coreLength-16)
        kitName = Self.ascii(data, bodyOffset, 12)
        if version == "2.21" {
            guard data.count == coreLength else { throw Failure.invalid("2.21 embedded sample layout is not yet verified.") }
            bytes = data; sampleNames = []; blocks = []; return
        }
        var names: [String] = []
        var records: [SampleBlock] = []
        if data.count > Self.coreSize {
            guard data.count >= Self.metadataEnd + 32,
                  data[4256..<4274] == Data("TD-27\0USUsrSmplPrm".utf8),
                  Self.ascii(data, 4276, 4) == Self.ascii(data, 20, 4) else {
                throw Failure.invalid("Unrecognized or truncated user-sample metadata.")
            }
            try checkMD5(4256, 20304)
            names = (0..<500).map { Self.ascii(data, 4304 + $0*32, 16) }
            guard data[20320..<20324] == Data("SMPh".utf8),
                  Self.u32(data, 20324) == 32, Self.u32(data, 20328) == 2 else {
                throw Failure.invalid("Unsupported SMPh layout.")
            }
            let count = Int(Self.u32(data, 20332))
            guard count <= 500 else { throw Failure.invalid("Invalid sample block count.") }
            var cursor = 20352
            for index in 0..<count {
                guard cursor <= data.count - 48,
                      data[cursor..<cursor+4] == Data("SMPd".utf8) else {
                    throw Failure.invalid("Missing SMPd header at byte \(cursor).")
                }
                let size = Int(Self.u32(data, cursor+8))
                guard size <= data.count - cursor - 48 else {
                    throw Failure.invalid("Truncated sample payload at byte \(cursor).")
                }
                records.append(SampleBlock(id: index, offset: cursor, payloadBytes: size,
                    opaqueWord: Self.u32(data, cursor+4),
                    frameCountCandidate: Self.u32(data, cursor+12),
                    name: Self.ascii(data, cursor+16, 16),
                    referenceCandidate: UInt16(data[cursor+32]) | UInt16(data[cursor+33]) << 8))
                cursor += 48 + size
            }
            guard cursor == data.count else { throw Failure.invalid("Unrecognized trailing bytes.") }
        }
        bytes = data
        sampleNames = names
        blocks = records
    }
    /// Only an exact original copy is exportable. Draft assignments cannot reach this API.
    func originalCopy() -> Data { bytes }
}
