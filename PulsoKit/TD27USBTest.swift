import Foundation

/// Narrow allowlist from controlled hardware captures. Not a general TD-27 map.
enum TD27USBTest {
    enum Zone: String, CaseIterable, Identifiable, Codable {
        case head = "Snare Head", rim = "Snare Rim"
        var id: String { rawValue }
        var index: UInt8 { self == .head ? 1 : 2 }
    }
    enum Parameter: String, CaseIterable, Identifiable, Codable {
        case pitch = "Pitch", decay = "Decay"
        var id: String { rawValue }
        var offset: Int { self == .pitch ? 1 : 3 }
        var values: [Int] { self == .pitch ? [0, 25, 30] : [81, 100] }
    }
    struct Snapshot: Codable, Equatable {
        let kitName: String
        let head: [UInt8]
        let rim: [UInt8]
        let headInstrument: [UInt8]
        let rimInstrument: [UInt8]
        func block(_ zone: Zone) -> [UInt8] { zone == .head ? head : rim }
        func value(_ zone: Zone, _ parameter: Parameter) -> Int? {
            let bytes = block(zone), i = parameter.offset
            guard bytes.count == 5, bytes[i] < 16, bytes[i+1] < 16 else { return nil }
            return Int(bytes[i]) * 16 + Int(bytes[i+1])
        }
        var isSupported: Bool {
            guard head.count == 5, rim.count == 5,
                  headInstrument.count == 9, rimInstrument.count == 9,
                  headInstrument[8] == 1, rimInstrument[8] == 1 else { return false }
            return Zone.allCases.allSatisfy { zone in
                Parameter.allCases.allSatisfy { parameter in
                    guard let v = value(zone, parameter) else { return false }
                    return parameter.values.contains(v)
                }
            }
        }
        func changing(_ zone: Zone, _ parameter: Parameter, to value: Int) -> Snapshot? {
            guard isSupported, parameter.values.contains(value) else { return nil }
            var h = head, r = rim
            let data = [UInt8(value / 16), UInt8(value % 16)]
            if zone == .head { h.replaceSubrange(parameter.offset...parameter.offset+1, with: data) }
            else { r.replaceSubrange(parameter.offset...parameter.offset+1, with: data) }
            return Snapshot(kitName: kitName, head: h, rim: r,
                            headInstrument: headInstrument, rimInstrument: rimInstrument)
        }
    }
    struct Backup: Codable {
        let date: Date
        let kitNumber: Int
        let deviceID: UInt8
        let zone: Zone
        let parameter: Parameter
        let requestedValue: Int
        let before: Snapshot
    }
    static func frame(kit: Int, zone: Zone, parameter: Parameter, value: Int) -> [UInt8]? {
        // Only kit 76, device 0x10, two snare zones and observed positive values.
        guard kit == 76, parameter.values.contains(value) else { return nil }
        let payload: [UInt8] = [0x05, 0x17, zone.index, UInt8(parameter.offset),
                                UInt8(value / 16), UInt8(value % 16)]
        let sum = payload.reduce(0) { $0 + Int($1) }
        return [0xF0, 0x41, 0x10, 0, 0, 0, 0x63, 0x12] + payload
            + [UInt8((128 - sum % 128) % 128), 0xF7]
    }
}
