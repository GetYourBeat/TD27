import AppKit
import Foundation

extension TD27StudioModel {
    func scanKitFolder() {
        let panel = NSOpenPanel()
        panel.title = "SD-Karte oder Ordner mit TD0-Kits auswählen"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        kitLibrary = []; selectedLibraryKit = nil
        Task { @MainActor in
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            guard let enumerator = FileManager.default.enumerator(at:folder,
                includingPropertiesForKeys:[.isRegularFileKey,.fileSizeKey], options:[.skipsHiddenFiles,.skipsPackageDescendants]) else {
                message = "Ordner kann nicht gelesen werden."; return
            }
            var entries: [LibraryKit] = [], errors: [String] = []
            var examined = 0
            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension.lowercased() == "td0" else { continue }
                examined += 1
                if examined > 1000 { errors.append("Scan auf 1000 TD0-Dateien begrenzt."); break }
                do {
                    let values = try url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey])
                    guard values.isRegularFile == true, let size = values.fileSize, size <= 256*1024*1024 else {
                        throw TD27File.Failure.invalid("Datei zu groß oder kein reguläres File.")
                    }
                    let file = try TD27File(Data(contentsOf:url,options:.mappedIfSafe))
                    entries.append(.init(url:url,name:file.kitName,version:file.version,sampleCount:file.blocks.count))
                } catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                message = "Kitordner: \(entries.count) gültige Dateien gefunden…"
                await Task.yield()
            }
            kitLibrary = entries.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
            selectedLibraryKit = kitLibrary.first?.url
            message = "\(entries.count) TD0-Kits gefunden. SD-Dateinummer und Modul-Kitnummer können unterschiedlich sein. " + errors.prefix(5).joined(separator:"\n")
        }
    }
    func openLibraryKit() {
        guard let url = selectedLibraryKit else { return }
        // Reuse Open Kit's replacement confirmation through the shared loader wrapper.
        loadLibraryURL(url)
    }
    func exportSDPackage() {
        run {
            guard let target = project.targetKitNumber, (1...100).contains(target) else {
                throw TD27File.Failure.invalid("Zuerst einen Zielplatz (1–100) auswählen.")
            }
            guard project.sourceKitNumber != target else {
                throw TD27File.Failure.invalid("Für eine Kopie einen anderen Zielplatz als das Quellkit wählen.")
            }
            let number = project.sdFileNumber ?? 1
            let data = try TD27Codec.export(project)
            let panel = NSOpenPanel(); panel.title = "Ordner für ein neues SD-Exportpaket"
            panel.canChooseDirectories = true; panel.canChooseFiles = false
            guard panel.runModal() == .OK, let parent = panel.url else { return }
            let folder = parent.appendingPathComponent("TD27-Ziel-\(target)-\(UUID().uuidString.prefix(8))",isDirectory:true)
            let kits = folder.appendingPathComponent("ROLAND/TD-27/Kit",isDirectory:true)
            try FileManager.default.createDirectory(at:kits,withIntermediateDirectories:true)
            let fileURL = kits.appendingPathComponent(String(format:"KIT-%03d.TD0",number))
            try data.write(to:fileURL,options:.withoutOverwriting)
            guard try Data(contentsOf:fileURL) == data else { throw TD27File.Failure.invalid("Exportprüfung fehlgeschlagen.") }
            _ = try TD27Codec.blocks(TD27File(Data(contentsOf:fileURL)))
            let instructions = """
            TD-27 Studio v3.1 — vollständiger Kit-Import
            Kit: \(project.title)
            Quellplatz (vom Benutzer angegeben): \(project.sourceKitNumber.map(String.init) ?? "nicht angegeben")
            Gewünschter Zielplatz im Modul: \(target)
            SD-Datei: KIT-\(String(format:"%03d",number)).TD0

            ACHTUNG: Die TD0-Datei erzwingt keinen Zielplatz. Den Zielplatz am Modul prüfen!
            1. Den aktuellen Inhalt von Zielplatz \(target) mit 1 KIT SAVE inklusive User Samples sichern.
            2. Die TD0-Datei in ROLAND/TD-27/Kit der am Modul formatierten SD-Karte kopieren.
               Bereits vorhandene Dateien nicht überschreiben; nötigenfalls eine freie SD-Dateinummer im Editor wählen und erneut exportieren.
            3. Am TD-27 SYSTEM > SD CARD > 1 KIT LOAD öffnen. TDZ ausschalten.
            4. SD Card = \(number), User = \(target), With User Sample einschalten (wenn Samples enthalten sind).
            5. Quellname und Zielplatz prüfen, dann LOAD bestätigen.
            Das vollständige Kit und seine eingebetteten Samples werden geladen, keine Einzelzuordnung nötig.
            Beim Import werden User Samples automatisch freien Plätzen zugeordnet; ausreichend freien Samplespeicher bereithalten.

            Ein USB-Belegungssnapshot ist kein vollständiger TD0-Backup und enthält keine Audiodaten.
            Neue Main/Sub-Layeränderungen benötigen noch die Prüfung am echten TD-27.
            Quelle: Roland TD-27 Reference Manual eng02, S. 49–50.
            https://static.roland.com/assets/media/pdf/TD-27_Reference_eng02_W.pdf
            """
            try Data(instructions.utf8).write(to:folder.appendingPathComponent("IMPORT-ANLEITUNG.txt"),options:.withoutOverwriting)
            message = "SD-Paket erstellt. Ziel \(target) ist eine Importvorgabe; am Modul unter User auswählen. Kein Modulplatz wurde beschrieben."
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
    }
}
