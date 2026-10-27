import Foundation
import Testing
@testable import PulsoKit

@MainActor
struct TD27USBTestTests {
    func snapshot() -> TD27USBTest.Snapshot {
        .init(kitName: "Test", head: [0,1,14,6,4], rim: [0,1,9,6,4],
              headInstrument: [0,0,0,1,0,0,0,0,1], rimInstrument: [0,0,0,2,0,0,0,0,1])
    }
    @Test func hardwareObservedValuesDecode() {
        let s = snapshot()
        #expect(s.isSupported)
        #expect(s.value(.head, .pitch) == 30)
        #expect(s.value(.rim, .pitch) == 25)
        #expect(s.value(.head, .decay) == 100)
        #expect(s.changing(.head, .decay, to: 81)?.head == [0,1,14,5,1])
    }
    @Test func writeAllowlistRejectsOtherKitsAndOutOfRangeValues() {
        #expect(TD27USBTest.frame(kit: 75, zone: .head, parameter: .pitch, value: 25) == nil)
        for value in [-129, -101, 101, 128, 256, Int.min, Int.max] {
            #expect(TD27USBTest.frame(kit: 76, zone: .head, parameter: .pitch, value: value) == nil)
        }
        #expect(TD27USBTest.frame(kit: 76, zone: .rim, parameter: .decay, value: 0) == nil)
    }
    @Test func packetHasExactAddressPayloadAndChecksum() throws {
        let frame = try #require(TD27USBTest.frame(kit: 76, zone: .head, parameter: .pitch, value: 25))
        #expect(Array(frame[8..<14]) == [5,0x17,1,1,1,9])
        #expect(frame[7] == 0x12)
        #expect(frame.last == 0xF7)
        #expect(frame[8..<frame.count-1].reduce(0) { $0 + Int($1) } % 128 == 0)
        let rim = try #require(TD27USBTest.frame(kit: 76, zone: .rim, parameter: .decay, value: 81))
        #expect(Array(rim[8..<14]) == [5,0x17,2,3,5,1])
    }
    @Test func expectedReadbackPreservesOtherZoneAndAssignment() throws {
        let s = snapshot(), expected = try #require(s.changing(.head, .pitch, to: 25))
        #expect(expected.rim == s.rim)
        #expect(expected.headInstrument == s.headInstrument)
        #expect(expected.rimInstrument == s.rimInstrument)
        #expect(expected.head == [0,1,9,6,4])
        #expect(expected != s)
        #expect(try JSONDecoder().decode(TD27USBTest.Snapshot.self, from: JSONEncoder().encode(s)) == s)
    }
    @Test func malformedOrUnsupportedSnapshotCannotAuthorizeWrite() {
        let s = snapshot()
        let bad = TD27USBTest.Snapshot(kitName: s.kitName, head: [0,16,0,6,4], rim: s.rim,
                                      headInstrument: s.headInstrument, rimInstrument: s.rimInstrument)
        #expect(!bad.isSupported)
        #expect(bad.changing(.head, .pitch, to: 25) == nil)
        let acoustic = TD27USBTest.Snapshot(kitName: s.kitName, head: s.head, rim: s.rim,
                                           headInstrument: [0,0,0,1,0,0,0,0,0], rimInstrument: s.rimInstrument)
        #expect(!acoustic.isSupported)
    }
    @Test func capturedNegativePitchAndBoundaryEncoding() throws {
        #expect(TD27USBTest.Parameter.pitch.decode([0x0E, 0x07]) == -25)
        #expect(TD27USBTest.Parameter.pitch.encode(-25) == [0x0E, 0x07])
        #expect(TD27USBTest.Parameter.pitch.encode(-100) == [9, 12])
        #expect(TD27USBTest.Parameter.pitch.encode(-1) == [15, 15])
        #expect(TD27USBTest.Parameter.pitch.encode(100) == [6, 4])
        #expect(TD27USBTest.Parameter.decay.decode([15, 15]) == nil)
        #expect(TD27USBTest.Parameter.pitch.decode([8, 0]) == nil)
        let frame = try #require(TD27USBTest.frame(kit: 76, zone: .head, parameter: .pitch, value: -25))
        #expect(Array(frame[8...14]) == [5, 0x17, 1, 1, 14, 7, 0x4D])
        let before = snapshot(), after = try #require(before.changing(.head, .pitch, to: -25))
        #expect(after.isSupported)
        #expect(after.head == [0,14,7,6,4])
        #expect(after.rim == before.rim)
        #expect(after.changing(.head, .pitch, to: 30) == before)
        let stored = try JSONEncoder().encode(after)
        #expect(try JSONDecoder().decode(TD27USBTest.Snapshot.self, from: stored).value(.head, .pitch) == -25)
    }

    @Test func allDocumentedValuesRoundTripWithoutChangingOtherBytes() throws {
        for parameter in TD27USBTest.Parameter.allCases {
            for zone in TD27USBTest.Zone.allCases {
                for value in parameter.range {
                    let s = try #require(snapshot().changing(zone, parameter, to: value))
                    #expect(s.value(zone, parameter) == value)
                    #expect(s.block(zone == .head ? .rim : .head) == snapshot().block(zone == .head ? .rim : .head))
                    let f = try #require(TD27USBTest.frame(kit: 76, zone: zone, parameter: parameter, value: value))
                    #expect(f[8..<f.count-1].reduce(0) { $0 + Int($1) } % 128 == 0)
                    #expect(f[12] < 16 && f[13] < 16)
                }
            }
        }
    }

    @Test func manualInputDoesNotSilentlySendAnOldOrClampedValue() {
        let p = TD27USBTest.Parameter.pitch
        #expect(p.parseInput("-25") == -25)
        #expect(p.parseInput("−25") == -25)
        #expect(p.parseInput(" 30 ") == 30)
        for invalid in ["", "-", "25.5", "25,5", "101", "-101", "abc", "9999999999999999999999999"] {
            #expect(p.parseInput(invalid) == nil)
        }
        #expect(TD27USBTest.Parameter.decay.parseInput("0") == nil)
        #expect(TD27USBTest.Parameter.decay.parseInput("-25") == nil)
        #expect(TD27USBTest.Parameter.decay.parseInput("1") == 1)
    }
}
