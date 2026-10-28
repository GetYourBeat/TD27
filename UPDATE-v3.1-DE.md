# TD-27 Studio v3.1

## Installation

Die neue App heißt **PulsoKit-TD27-v3.1.app**. Die vorhandene v3-App behalten.
ZIP entpacken und die neue App unter ihrem neuen Namen in Programme kopieren.
Die App ist lokal/ad-hoc signiert, nicht mit einer Apple Developer ID notarisiert.

## Kit ansehen und vollständig bearbeiten

1. TD-27 als MIDI-Eingang und -Ausgang auswählen.
2. TD-27 Studio → USB / SD Kit-Browser → 100 Kitnamen lesen.
3. Gewünschtes Kit wählen (z.B. 50) → Belegung lesen.
   Main/Sub aller 24 Zonen werden zweimal gelesen und verglichen.
4. Für Audio und vollständige Kitdaten: am Modul 1 KIT SAVE mit With User Sample.
   SD-Karte am Mac anschließen → Kitordner durchsuchen → passende TD0 öffnen.
5. Im Kit-Editor Main oder Sub auswählen, bestehendes Sample aus der Bibliothek
   zuordnen oder WAV importieren. Unbearbeitete Bereiche bleiben erhalten.
6. Quellplatz manuell dokumentieren, Zielplatz (z.B. 78) und SD-Dateinummer wählen.
7. SD-Paket exportieren. Die enthaltene Anleitung beschreibt 1 KIT LOAD.
   Zielplatz am Modul vor dem Laden sichern und unter User ausdrücklich wählen.

Wichtig: Kit 50 per USB anzusehen lädt KEINE vollständige TD0 inklusive Audio.
Die SD-Sicherung ist hierfür weiterhin nötig. Das Programm bietet keinen
unverifizierten USB-Kitkopierbefehl und keinen WAV-Upload per USB an.
Eine SD-Dateinummer ist keine Modul-Zielnummer; der Editor kann einen belegten
Zielplatz nicht als frei garantieren. Es erfolgt kein automatischer Hardwarewrite.

## Änderungen

- USB-Kitbrowser mit 100 Namen und allen Main/Sub-Zuordnungen.
- Werksinstrumentnamen mit expliziter numerischer Anzeige unbekannter IDs.
- SD-Ordnerbrowser mit Kitname, Dateiformat und Anzahl eingebetteter Samples.
- Bibliothek enthält auch Samples, die nur als Sub verwendet werden.
- Getrennte Main-/Sub-WAV-Zuordnung, Pegel, Pitch und Decay; Layer-Modus/Fadepunkt.
- Ein Main-Austausch entfernt nicht mehr automatisch das bestehende Sub.
- Wertefelder zusätzlich zu Slidern; Änderungen bleiben bis zum Export lokal.
- Unbearbeitetes Öffnen/Exportieren normalisiert keine Sample-Parameter mehr.
- SD-Paket mit separater Zielvorgabe und Importanleitung; kein Überschreiben.
- Bestätigter Snare-USB-Test für Kit 76 auch direkt aus dem Browser erreichbar.

## Grenzen

- 1.01/1.02 TD0: bearbeiten/exportieren. 2.21: prüfen/anzeigen/Originalkopie.
- USB-only zeigt Sample-Nummern; Sample-Namen und Audio kommen aus TD0.
- Keine vollständige USB-Sicherung oder direktes Speichern eines ganzen Kits auf
  einen anderen Modulplatz. Das geschieht über 1 KIT LOAD mit Samples.
- Neue Layer-Exporte und der erweiterte Browser sind erst nach einem realen
  Hardwaretest bestätigt. Bisherige positive/negative Snare-Pitch- und Decay-
  Schreibtests sowie Wiederherstellungen waren am Modul erfolgreich.
- Vorschau spielt eine WAV mit Pad-Pitch/Pan/Pegel, keine Roland-Modellierung und
  keine Simulation der kompletten Velocity-Layer, Effekte oder Instrument-Decay.
- Layer-Modi gelten für die ältere TD0-Struktur. Moderne XFADE-/Fade-End-Parameter
  sind nicht implementiert; FADE2/FADE3 werden ausdrücklich als legacy angezeigt.
- Recherche mit Quellen: Research/TD27-SAMPLES-AND-WORKFLOW-v3.1.md.
