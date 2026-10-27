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
    @Test func writeAllowlistRejectsUnverifiedTargetsAndValues() {
        #expect(TD27USBTest.frame(kit: 75, zone: .head, parameter: .pitch, value: 25) == nil)
        for value in [-100, -1, 1, 24, 26, 31, 100, 256] {
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
}
