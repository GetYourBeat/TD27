import Foundation

/// Hardware-observed snare addresses; documented user-sample ranges.
/// This remains a restricted kit-76 test, not a general TD-27 map.
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
        // Roland TD-27 Data List eng02, page 7: USER SAMPLE Pitch/Decay.
        var range: ClosedRange<Int> { self == .pitch ? -100...100 : 1...100 }
        var defaultValue: Int { self == .pitch ? 0 : 100 }

        func parseInput(_ text: String) -> Int? {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "−", with: "-")
            guard let value = Int(normalized), range.contains(value) else { return nil }
            return value
        }

        func encode(_ value: Int) -> [UInt8]? {
            guard range.contains(value) else { return nil }
            // Hardware read: -25 -> E7, transmitted as the nibbles 0E 07.
            let raw = self == .pitch ? UInt8(bitPattern: Int8(value)) : UInt8(value)
            return [raw >> 4, raw & 0x0F]
        }

        func decode(_ bytes: [UInt8]) -> Int? {
            guard bytes.count == 2, bytes.allSatisfy({ $0 < 16 }) else { return nil }
            let raw = bytes[0] << 4 | bytes[1]
            let value = self == .pitch ? Int(Int8(bitPattern: raw)) : Int(raw)
            return range.contains(value) ? value : nil
        }
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
            guard bytes.count == 5 else { return nil }
            return parameter.decode(Array(bytes[i...i+1]))
        }
        var isSupported: Bool {
            guard head.count == 5, rim.count == 5,
                  headInstrument.count == 9, rimInstrument.count == 9,
                  headInstrument[8] == 1, rimInstrument[8] == 1 else { return false }
            return Zone.allCases.allSatisfy { zone in
                Parameter.allCases.allSatisfy { parameter in
                    value(zone, parameter) != nil
                }
            }
        }
        func changing(_ zone: Zone, _ parameter: Parameter, to value: Int) -> Snapshot? {
            guard isSupported, let data = parameter.encode(value) else { return nil }
            var h = head, r = rim
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
        // Only kit 76, device 0x10 and the two measured snare zones.
        guard kit == 76, let data = parameter.encode(value) else { return nil }
        let payload: [UInt8] = [0x05, 0x17, zone.index, UInt8(parameter.offset)] + data
        let sum = payload.reduce(0) { $0 + Int($1) }
        return [0xF0, 0x41, 0x10, 0, 0, 0, 0x63, 0x12] + payload
            + [UInt8((128 - sum % 128) % 128), 0xF7]
    }
}
