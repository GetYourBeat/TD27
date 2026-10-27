import SwiftUI

struct TD27USBTestView: View {
    @EnvironmentObject private var midi: MIDIManager
    @State private var zone: TD27USBTest.Zone = .head
    @State private var parameter: TD27USBTest.Parameter = .pitch
    @State private var value = 25
    var body: some View {
        GroupBox("USB-Schreibtest · Kit 76 · User-Sample-Snare") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kit-Kopie 76 am Modul auswählen. Zuerst lesen und Namen prüfen. Dieser Test ändert Instrument Pitch/Decay direkt im Modul; der Offline-Editor bleibt separat.")
                    .font(.caption)
                HStack {
                    Button("1. Snare lesen") { midi.readTD27USBTest() }
                    Picker("Zone", selection: $zone) {
                        ForEach(TD27USBTest.Zone.allCases) { Text($0.rawValue).tag($0) }
                    }.frame(width: 180)
                    Picker("Parameter", selection: $parameter) {
                        ForEach(TD27USBTest.Parameter.allCases) { Text($0.rawValue).tag($0) }
                    }.frame(width: 150)
                    Picker("Wert", selection: $value) {
                        ForEach(parameter.values, id: \.self) { Text(String($0)).tag($0) }
                    }.frame(width: 110)
                    Button("2. Sichern & senden") {
                        midi.writeTD27USBTest(zone: zone, parameter: parameter, value: value)
                    }.disabled(!midi.usbTestReady)
                }
                HStack {
                    Button("Letzten Test zurücksetzen") { midi.restoreTD27USBTest() }
                        .disabled(!midi.usbTestCanRestore)
                    Button("Sicherung im Finder") { midi.revealTD27USBBackup() }
                        .disabled(midi.usbTestBackupURL == nil)
                }
                Text(midi.usbTestStatus).textSelection(.enabled)
                Text("Nur beobachtete Werte: Pitch 0/25/30, Decay 81/100. Lokale Parametersicherung vor jedem Schreibvorgang. Noch kein bestätigter Hardware-Schreibtest; keine vollständige Kit- oder Sample-Sicherung.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(midi.isOperationInProgress)
        .onChange(of: parameter) { _, new in value = new.values[0] }
    }
}
