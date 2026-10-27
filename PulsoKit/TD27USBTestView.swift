import SwiftUI

struct TD27USBTestView: View {
    @EnvironmentObject private var midi: MIDIManager
    @State private var zone: TD27USBTest.Zone = .head
    @State private var parameter: TD27USBTest.Parameter = .pitch
    @State private var valueText = "25"

    private var enteredValue: Int? { parameter.parseInput(valueText) }
    private func useReadValue() {
        valueText = String(midi.usbTestSnapshot?.value(zone, parameter) ?? parameter.defaultValue)
    }
    private var sliderValue: Binding<Double> {
        Binding(get: { Double(enteredValue ?? parameter.defaultValue) },
                set: { valueText = String(Int($0.rounded())) })
    }

    var body: some View {
        GroupBox("USB-Schreibtest · Kit 76 · freie Werteingabe") {
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
                }
                HStack {
                    Text("Wert")
                    TextField("Ganzzahl", text: $valueText)
                        .textFieldStyle(.roundedBorder).frame(width: 80)
                        .accessibilityLabel("Gewünschter \(parameter.rawValue)-Wert")
                    Slider(value: sliderValue,
                           in: Double(parameter.range.lowerBound)...Double(parameter.range.upperBound), step: 1)
                        .accessibilityLabel(parameter.rawValue)
                    Text("\(parameter.range.lowerBound)…\(parameter.range.upperBound)")
                        .font(.caption).monospacedDigit()
                    Button("2. Sichern & senden") {
                        guard let value = enteredValue else { return }
                        midi.writeTD27USBTest(zone: zone, parameter: parameter, value: value)
                    }.disabled(!midi.usbTestReady || enteredValue == nil)
                }
                if enteredValue == nil {
                    Text("Bitte eine ganze Zahl von \(parameter.range.lowerBound) bis \(parameter.range.upperBound) eingeben.")
                        .font(.caption).foregroundStyle(.red)
                }
                Text("Eingabe und Regler senden erst nach Klick auf „Sichern & senden“. Beim Lesen oder Wechseln von Zone/Parameter wird der zuletzt gelesene Wert übernommen.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Letzten Test zurücksetzen") { midi.restoreTD27USBTest() }
                        .disabled(!midi.usbTestCanRestore)
                    Button("Sicherung im Finder") { midi.revealTD27USBBackup() }
                        .disabled(midi.usbTestBackupURL == nil)
                }
                Text(midi.usbTestStatus).textSelection(.enabled)
                Text("Positive Pitch-/Decay-Schreibtests und Rücksetzen bestätigt. −25 ist bisher nur ausgelesen; negative Schreibwerte und weitere Zwischenwerte noch nicht hardwaregetestet. Lokale Parametersicherung vor jedem Schreibvorgang, keine vollständige Kit-/Sample-Sicherung.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(midi.isOperationInProgress)
        .onChange(of: parameter) { _, _ in useReadValue() }
        .onChange(of: zone) { _, _ in useReadValue() }
        .onChange(of: midi.usbTestReadRevision) { _, _ in useReadValue() }
    }
}
