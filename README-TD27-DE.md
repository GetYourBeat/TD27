# TD-27 Studio v3 — separate Testversion

Diese Entwicklungsversion lässt die funktionierende Version auf `main` unverändert.
App-Name: `PulsoKit-TD27-v3.app`. Eigene Bundle-ID und eigener lokaler Basisspeicher.
Der Import eines v2-Exports wurde vom Benutzer am TD-27 bestätigt. Die Änderungen
in v3 benötigen einen erneuten Hardwaretest.

## Änderungen

- Neue WAV-Zuweisungen setzen **Instrument Pitch = 0 / Instrument Decay = 100**,
  zusätzlich zu Pad Pitch und Pad Decay. Bisher wurden die V-Edit-Werte der
  Vorlage übernommen. Beide Ebenen sind jetzt sichtbar und editierbar.
- **Open kit…** lädt tatsächlich verwendete Hauptinstrument-User-Samples samt
  Zuordnung und Parametern in die Bibliothek. Unveränderte Audiodaten verwenden
  ihren bestehenden Slot wieder, anstatt bei jedem Export dupliziert zu werden.
- **Reset sample sound** setzt beide Pitch-/Decay-Ebenen zurück.
- **PD-140DS: Head / Rimshot / Cross-stick**. Cross-stick bietet die am TD-27
  dokumentierte Auswahl 1–16 und einen eigenen Pegel. Es ist kein dritter frei
  belegbarer WAV-Slot. Ein kompatibles internes Snare-/Cross-stick-Instrument
  muss auf Snare Rim liegen; ein dort zugewiesenes User-Sample erfüllt das nicht.
- **2.21-Kitkerne**: Öffnen, Name und MD5 prüfen, unverändert kopieren.
  Der Sample-Container dieser Version ist noch nicht verifiziert; WAV-Export
  verwendet weiterhin eine 1.01/1.02-Basis. Keine geratenen 2.21-Sampleheader.

## Neue Kits ohne wiederholte Dateiauswahl

1. Einmal **Choose base…** und eine funktionierende TD0 in Version 1.01/1.02 wählen.
2. **Remember as base for new kits** speichert eine Kopie nur auf deinem Mac.
3. **New kit** startet danach ohne Dateiauswahl mit dieser Basis.
4. WAV importieren, Pad/Zone wählen, **Assign selected sample**.
5. **Export TD0 with samples…** schreibt ausschließlich eine neue Datei.

Die strukturelle Basis bleibt notwendig. Diese Version erzeugt noch keinen
vollständig neutralen Kit-Kern von Grund auf. EQ, Kompression, Room, Overhead und
MFX bleiben aus der Basis erhalten; das steht ausdrücklich im Editor.
**Unassigned pads: -60 dB** senkt unbelegte Hauptinstrumente ab und deaktiviert
ihre Sub-Layer. -60 dB ist keine garantierte digitale Stummschaltung.
Die gespeicherte Basis liegt unter Application Support/TD27StudioV3/base.TD0.
Originaldateien werden nicht überschrieben und nicht ins Repository hochgeladen.

## Vorschau

Die Vorschau berücksichtigt WAV, Pad Pitch, Pan und Pegel. Instrument Pitch,
Decay, interne Roland-Instrumente und Basis-Effekte werden nicht simuliert.
Cross-stick-Sounds sind nicht als Audio im Programm enthalten.

## Build und Tests

`bash build-apple-silicon.command` führt Swift-Tests aus und erzeugt
`dist/PulsoKit-TD27-v3.app` sowie `dist/PulsoKit-TD27-v3-AppleSilicon.zip`.
GitHub Actions baut die separate Branch `td27-studio-v3`.
Die App ist ad-hoc signiert, nicht notarisiert. macOS 14+, Apple Silicon.

Python: `python3 -m unittest discover -s tools -p 'test_*.py' -v`.
Private Referenztests werden ohne bereitgestellte Dateien übersprungen.
Neue Regressionstests prüfen den Pitch-/Decay-Reset, Byte-Erhalt anderer Zonen,
Cross-stick-Felder, 2.21-Prüfsummen, bestehende Projekte und Sample-Slot-Wiederverwendung.

## Quellen und technische Grenzen

Roland Corporation, PD-140DS Owner’s Manual, ©2016, S.5:
https://static.roland.com/assets/media/pdf/PD-140DS_eng02_W.pdf

Roland Corporation, TD-27 Data List, ©2020, S.4–7 (beide Pitch-/Decay-Ebenen,
Cross-stick 1–16 und erforderliches Rim-Instrument):
https://static.roland.com/assets/media/pdf/TD-27_Data_List_eng02_W.pdf

Die Datei-Offsets sind rekonstruiert, keine veröffentlichte Roland-TD0-Spezifikation.
V-Edit-Hauptparameter in 1.01/1.02: 0xADC + 24 × Zone, Pitch als vorzeichenbehaftetes
Byte, Decay im Folgebyte. Die unabhängigen öffentlichen User-Sample-Kits zeigen
hier Pitch 0 / Decay 100. Cross-stick-Auswahl/Level liegen im gemeinsamen Kitblock.
Ein automatisierter Rundlauf ersetzt den Hardwaretest der neuen Parameter nicht.
Nicht verifizierte SysEx-Schreibzugriffe bleiben gesperrt.

Basis: PulsoKit von Arek / arkus1972 (MIT): https://github.com/arkus1972/PulsoKit
