# PulsoKit TD-27 – Exportversion 2

Stand 26.10.2026. **Der Export eigener WAVs in TD0 ist jetzt implementiert und in
der Oberfläche freigeschaltet.** Er verwendet eine originale TD0 als Vorlage.

**Noch experimentell:** Die Binärtests bestehen. Ein Import am echten TD-27 und
manuelle Bedienung der Swift-App sind noch nicht getestet. Der ARM64-Build und
die automatisierten Swift-Tests wurden am 27.10.2026 erfolgreich auf GitHub ausgeführt.
Es wird deshalb keine bestätigte Modulkompatibilität behauptet.

## Workflow in der Mac-App

1. Über **TD0 template…** eine originale TD-27-`.TD0` laden, z. B. deine FATTITUDE-Datei.
   Das lädt die Grundeinstellungen; bereits importierte WAVs bleiben erhalten.
2. Eigene WAVs in die Bibliothek ziehen oder **Import WAVs…** wählen.
3. Pad und Zone wählen, Sample markieren, **Assign selected sample** drücken.
4. Pegel, Panorama und Tuning einstellen; über **Play pad** vorhören.
5. **Export TD0 with samples…** erstellt eine neue `.TD0` mit eingebetteten Samples,
   Pad-Zuordnungen und Prüfsummen. Ein vorhandener Dateipfad wird niemals überschrieben.
6. Die Datei als `KIT-XXX.TD0` in den vom Modul angelegten Kit-Ordner auf der SD-Karte
   kopieren. Vor dem ersten Versuch ein vollständiges Modul-Backup erstellen.
7. Auf einem entbehrlichen Kit-Speicherplatz mit **1 KIT LOAD / With User Sample** laden.

Die zugewiesenen Zonen erhalten die Samples als Hauptinstrument. Der bisherige Sub-Layer
wird für diese Zonen ausgeschaltet. Nicht zugewiesene Zonen bleiben wie in der Vorlage.
**Use original instrument** nimmt eine neue Zuweisung zurück. Weitere Effekte und
unbekannte Einstellungen stammen aus der Vorlage; die Vorschau simuliert diese nicht.
Kitname: maximal 12 ASCII-Zeichen im TD0; längere Namen werden beim Export gekürzt,
nicht-ASCII-Zeichen durch `_` ersetzt. Projektnamen bleiben im Projekt vollständig.

**Save project** speichert eine portable `.td27project` mit WAVs und Vorlage zum
Weiterarbeiten. **Save original copy** bleibt eine separate unveränderte Kopie der Vorlage.
**Extract samples to WAV library** macht eingebettete Vorlagensamples lokal hörbar und
neu zuweisbar. Originalblöcke bleiben beim Export erhalten, auch wenn sie ersetzt werden;
das kann mehr Speicher benötigen als ein am Modul aufgeräumtes Kit.

## Was neu entschlüsselt wurde

- Kanalweise gespeichertes 16-Bit-PCM, Mono-/Stereo-Kennung, Block- und Seitengrößen.
- Vorspann, Nachspann und Auffüllung aller 29 Samples aus drei unabhängigen Kits.
- Sample-Slot, Main-/Sub-Instrumentbank und Zuordnungsfelder für 24 Zonen.
- Pegel, Panorama und Pad-Pitch sowie samplehaltige Dateiheader.

**24 Python-Tests bestanden.** Alle 29 Originalblöcke und die drei kompletten
samplehaltigen TD0-Dateien wurden bytegenau rekonstruiert. Neu erzeugte Audiodaten,
Zuordnungen, Parameter, Prüfsummen, Schutz vor Datenverlust und Grenzen werden getestet.
Die privaten Referenzdateien und daraus erzeugten Analyseberichte sind nicht Teil dieses öffentlichen Repositorys.

## Fertige App ohne lokales Xcode

Unter [Actions](https://github.com/GetYourBeat/TD27/actions) den neuesten erfolgreichen
Lauf öffnen und das Artefakt **PulsoKit-TD27-AppleSilicon** herunterladen.
Das heruntergeladene Archiv enthält das App-ZIP; beide entpacken.
Der Status des jeweiligen GitHub-Laufs ist maßgeblich. Die App ist ad-hoc signiert,
aber nicht bei Apple notarisiert.

## Auf Apple Silicon bauen

macOS 14+ und vollständiges Xcode (empfohlen Xcode 26); keine externen Swift-Pakete.
Xcode einmal starten und benötigte Komponenten installieren. Im Ordner `PulsoKit`:

```bash
bash build-apple-silicon.command
```

Das Skript führt Swift-Kerntests, Projekt-/Audio-/Exporttests und den arm64-Build aus.
Bei Erfolg entstehen `dist/PulsoKit-TD27.app` und `dist/PulsoKit-TD27-AppleSilicon.zip`.
Bei Fehlern bricht es ab. Alternativ `PulsoKit.xcodeproj`, Schema PulsoKit, My Mac öffnen.
Die App wird lokal ad-hoc signiert; sie ist nicht notarisiert.

**Build bestätigt:** [GitHub Actions, 27.10.2026](https://github.com/GetYourBeat/TD27/actions/runs/40518473506), Xcode 26.6, ARM64 Release.
11 Swift-Testfunktionen erfolgreich; darunter ein leerer Upstream-Beispieltest und ein
optionaler Referenztest ohne bereitgestellte Originaldatei. Python: 24 Tests entdeckt,
21 ausgeführt und 3 Referenztests mangels privater Dateien übersprungen.
Die WAV-Konvertierung von 48 auf 44,1 kHz wurde im nativen Test geprüft.
Manuelle GUI-/Hörtests und der Import am echten TD-27 bleiben offen.

## Export ohne Xcode, über Python

Der unabhängige Python-Exporter ist tatsächlich ausgeführt und getestet worden.
Er benötigt Python 3 und keine Zusatzpakete. WAVs müssen bereits PCM 16/24 Bit,
44,1 kHz, mono oder stereo sein. Eine `mapping.json` enthält beispielsweise:

```json
[
  {"zone": 0, "wav": "/Users/ava/Samples/Kick.wav", "level_db": -6, "pan": 0, "semitones": 0},
  {"zone": 1, "wav": "/Users/ava/Samples/Snare.wav", "level_db": -3, "pan": 0, "semitones": 0}
]
```

```bash
python3 tools/td27_codec.py /pfad/Vorlage.TD0 mapping.json /pfad/KIT-101.TD0 --title "AVA KIT"
```

Die Ausgabedatei muss neu sein. Zonenindizes:

| Index | Zone |
|---|---|
| 0 | Kick Head |
| 1 / 2 | Snare Head / Rim |
| 3 / 4 | Tom 1 Head / Rim |
| 5 / 6 | Tom 2 Head / Rim |
| 7 / 8 | Tom 3 Head / Rim |
| 9 / 10 | Hi-Hat Head / Rim |
| 11 / 12 | Crash 1 Head / Rim |
| 13 / 14 | Crash 2 Head / Rim |
| 15 / 16 / 17 | Ride Head / Rim / Bell |
| 18 / 19 | AUX 1 Head / Rim |
| 20 / 21 | AUX 2 Head / Rim |
| 22 / 23 | AUX 3 Head / Rim |

Pegel: -60 bis +6 dB, Pan: -1 bis +1, Tuning: -24 bis +24 Halbtöne.
Der Encoder schreibt 16-Bit-PCM. 24-Bit-Quellen verlieren beim Export die niedrigsten
acht Bits; das wird nicht als verlustfreie 24-Bit-Konvertierung dargestellt.

## Testkit im Download

Im separaten Ordner `Hardware-Test` liegt `KIT-199.TD0` mit einem neu erzeugten,
kurzen und leisen synthetischen Kick-Sample. Es basiert auf deiner FATTITUDE-Vorlage.
Nur Kick Head ist ersetzt; andere Pads bleiben unverändert. `TestKick.wav` und
Anleitung liegen daneben. Dieses Testkit ist nicht im öffentlichen Quellcode enthalten.
**Es ist noch nicht hardwaregetestet.** Die Hardware-Anleitung benennt die Erfolgskriterien.

## Grenzen

- Originale TD0-Version 1.01/1.02 als Vorlage erforderlich; kein erfundener leerer Kit-Kern.
- TDZ ist ein anderes Format und wird nicht konvertiert.
- Unbekannte Samplekodierungen werden abgelehnt; neue Samples werden als 16 Bit gespeichert.
- Neue Zuordnungen betreffen den Main-Layer; kein freier Sub-Layer-/Effekteditor.
- Bibliotheks-/Exportgrenze: 500 Samples, 180 s je Sample, 24 Mono-Minuten insgesamt.
  Der tatsächlich freie Speicher im Modul kann geringer sein.
- Die nicht verifizierte MIDI-Schreibsperre bleibt unverändert. Der Export arbeitet nur mit Dateien.
- Noch kein Hardware-Nachweis. Ein Parser-Rundlauf allein beweist keinen erfolgreichen Import.

## Tests reproduzieren

```bash
python3 -m unittest discover -s tools -p 'test_*.py' -v
TD27_FIXTURES=/pfad/originale TD27_EXTRA_FIXTURES=/pfad/weitere-kits python3 -m unittest discover -s tools -p 'test_*.py' -v
python3 tools/verify_export_references.py /pfad/MOONWALK2.TD0 /pfad/IN-THE-AIR.TD0 /pfad/NO-ORDER.TD0
```

Ohne Originaldateien werden die entsprechenden Referenztests übersprungen. Die zuvor berichteten Referenzergebnisse stammen aus einem lokalen Lauf mit Originalkits.

## Repository

Vollständige PulsoKit-Codebasis von Arek / arkus1972, MIT-Lizenz erhalten.
Upstream-Basis: `6163631fda93cba724254a99e70a1e10d103302d`.
Das Archiv enthält außerdem ein Git-Bundle mit der vollständigen Historie:

```bash
git clone PulsoKit-TD27.bundle PulsoKit-TD27
git -C PulsoKit-TD27 switch td27-offline-studio
```

Öffentliches Repository: https://github.com/GetYourBeat/TD27
Der Workflow baut bei jedem Push auf `main` und lässt sich über Actions manuell starten.
