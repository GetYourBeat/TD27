import Foundation

/// Read-only interpretation of the public TD-27 schema, cross-checked at kits 1 and 76.
/// A USB snapshot contains parameter references, NOT the WAV audio or a TD0 container.
enum TD27KitBrowser {
    struct KitName: Identifiable, Equatable {
        let number: Int
        let name: String
        var id: Int { number }
    }
    struct Instrument: Codable, Equatable {
        let number: Int // Factory ID is direct; user slot is zero-based.
        let bank: Int
        let raw: [UInt8]
        var label: String {
            if bank == 1 { return String(format: "U%03d", number+1) + " · User-Sample (Audio über SD)" }
            if bank == 0 { return String(format: "%03d", number) + " · " + (TD27InstrumentNames.names[number] ?? "Werksinstrument") }
            return "Unbekannte Bank \(bank), ID \(number)"
        }
    }
    struct Zone: Codable, Identifiable, Equatable {
        let index: Int
        let main: Instrument
        let sub: Instrument
        let common: [UInt8]
        let mainVEdit: [UInt8]
        let subVEdit: [UInt8]
        var id: Int { index }
        var subEnabled: Bool { common.count > 7 && common[7] == 1 }
    }
    struct Snapshot: Codable, Equatable {
        let kitNumber: Int
        let name: String
        let zones: [Zone]
        let date: Date
    }
    static func address(kit: Int, offset: Int = 0) -> [UInt8]? {
        guard (1...100).contains(kit), (0..<32768).contains(offset) else { return nil }
        let value = (4 << 21) + (kit-1)*32768 + offset
        return [21,14,7,0].map { UInt8((value >> $0) & 127) }
    }
    static func instrument(_ raw: [UInt8]) throws -> Instrument {
        guard raw.count >= 9, raw.prefix(8).allSatisfy({ $0 < 16 }), raw[8] < 2 else {
            throw TD27File.Failure.invalid("Ungültige Instrument-Antwort. Keine Zuordnung übernommen.")
        }
        let id = raw.prefix(4).reduce(0) { ($0 << 4) | Int($1) }
        guard raw[8] == 0 || id < 500 else { throw TD27File.Failure.invalid("Ungültige User-Sample-ID.") }
        return .init(number:id, bank:Int(raw[8]), raw:raw)
    }
    static func name(_ raw: [UInt8]) throws -> String {
        guard raw.count == 12, raw.allSatisfy({ $0 == 0 || (32...126).contains($0) }) else {
            throw TD27File.Failure.invalid("Ungültiger Kitname in MIDI-Antwort.")
        }
        return String(bytes:raw.prefix(while: { $0 != 0 }), encoding:.ascii)!.trimmingCharacters(in:.whitespaces)
    }
}
