import SwiftUI
import AppKit
import Combine
import ServiceManagement //per l'avvio al login

final class FileCutPasteManager: ObservableObject {
    
    //permessi da richiedere:
    // accessibility
    // full disk access
    // privacy&security --> automation
    
    @Published var isAccessibilityEnabled: Bool = false
    @Published var statusMessage: String = ""
    @Published var monitored: Bool = false
    
    static let shared = FileCutPasteManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var cutItems: [URL] = []
    
    private init() {
        statusMessage = "Pronto"
        refreshAccessibilityStatus()
        //        _ = finderTargetFolder()  // forza la richiesta di automation al finder
        //
        //        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        //        let isTrusted = AXIsProcessTrustedWithOptions(options)
        //        print("STATO ACCESSIBILITÀ AL BOOT: \(isTrusted)")
        //        self.isAccessibilityEnabled = isTrusted
        
        if AXIsProcessTrusted() {
            startMonitoring() // se abbiamo tutti i permessi, comincia a funzionare
        } else {
            _ = finderTargetFolder()  // forza la richiesta di automation al finder
            
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary // mi fa vedere il messaggio "would like to control this computer"
            let isTrusted = AXIsProcessTrustedWithOptions(options)
            print("STATO ACCESSIBILITÀ AL BOOT: \(isTrusted)")
            self.isAccessibilityEnabled = isTrusted
        }
        
        do {
            if SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register() // per l'avvio all'accensione del computer
                print("App registrata per l'avvio al login")
            }
        } catch {
            print("Errore durante la registrazione dell'avvio automatico: \(error)")
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard !monitored else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }
            
            // per controllare se premo il tasta command
            let flags = event.flags
            let isCmdPressed = flags.contains(.maskCommand)
            if !isCmdPressed {
                return Unmanaged.passUnretained(event)
            }
            
            // per non rischiare di fare cmd-X nel finder invece che in un'altra app
            if let activeApp = NSWorkspace.shared.frontmostApplication,
               activeApp.bundleIdentifier != "com.apple.finder" {
                return Unmanaged.passUnretained(event)
            }
            
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode) // X = 7; V = 9
            let manager = FileCutPasteManager.shared
            
            switch keyCode {
            case 7: // X
                manager.handleCut()
            case 9: // V
                manager.handlePaste()
            default:
                break
            }
            return Unmanaged.passUnretained(event)
        }
        
        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                               place: .headInsertEventTap,
                                               options: .defaultTap,
                                               eventsOfInterest: CGEventMask(eventMask),
                                               callback: eventTapCallback,
                                               userInfo: nil) else {
            DispatchQueue.main.async {
                self.statusMessage = "Errore: impossibile creare event tap"
            }
            return
        }
        
        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            monitored = true
            DispatchQueue.main.async {
                self.statusMessage = "Monitoraggio attivo"
            }
        } else {
            DispatchQueue.main.async {
                self.statusMessage = "Errore: impossibile creare run loop source"
            }
        }
    }
    
    func stopMonitoring() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        DispatchQueue.main.async {
            self.monitored = false
            self.statusMessage = "Monitoraggio fermato"
        }
    }
    
    func refreshAccessibilityStatus() {
        DispatchQueue.global(qos: .userInitiated).async {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)
            DispatchQueue.main.async {
                self.isAccessibilityEnabled = trusted
                if !trusted {
                    self.statusMessage = "Accessibilità non abilitata"
                }
            }
        }
    }
    
    private func handleCut() {
        DispatchQueue.global(qos: .userInitiated).async {
            let paths = self.finderSelectionPaths()
            guard !paths.isEmpty else {
                DispatchQueue.main.async {
                    self.statusMessage = "Nessun file selezionato in Finder per tagliare"
                }
                return
            }
            
            if !self.cutItems.isEmpty{
                self.setFilesHidden(self.cutItems, hidden: false)
            }
            
            let urls = paths.compactMap { URL(fileURLWithPath: $0) }
            self.cutItems = urls
            
            //nascondi i file tagliati
            self.setFilesHidden(urls, hidden: true)
            
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString("com.example.filecutpaste.cut", forType: .string)
            
            DispatchQueue.main.async {
                self.statusMessage = "Tagliati \(urls.count) elementi"
            }
        }
    }
    
    private func handlePaste() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard !self.cutItems.isEmpty else {
                DispatchQueue.main.async {
                    self.statusMessage = "Nessun elemento da incollare"
                }
                return
            }
            
            let targetFolder = self.finderTargetFolder() ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            
            var successCount = 0
            var failureCount = 0
            
            for sourceURL in self.cutItems {
                let destURL = self.uniqueDestinationURL(for: sourceURL, in: targetFolder)
                
                do {
                    //sposta il file
                    try FileManager.default.moveItem(at: sourceURL, to: destURL)
                    
                    // rendilo di nuovo visibile
                    self.setFilesHidden([destURL], hidden: false)
                    successCount += 1
                } catch {
                    failureCount += 1
                    self.setFilesHidden([sourceURL], hidden: false)
                }
            }
            
            if successCount > 0 {
                self.cutItems.removeAll()
            }
            
            DispatchQueue.main.async {
                if successCount > 0 && failureCount == 0 {
                    self.statusMessage = "Incollati \(successCount) elementi"
                } else if successCount > 0 && failureCount > 0 {
                    self.statusMessage = "Incollati \(successCount) elementi, \(failureCount) errori"
                } else {
                    self.statusMessage = "Errore durante incolla"
                }
            }
        }
    }
    
    
    // MARK: - AppleScript Helpers
    
    private func finderSelectionPaths() -> [String] {
        let script = """
        tell application "Finder"
            set theSelection to selection
            set posixPaths to {}
            repeat with anItem in theSelection
                set thePosixPath to POSIX path of (anItem as alias)
                copy thePosixPath to end of posixPaths
            end repeat
            return posixPaths
        end tell
        """
        
        guard let result = runAppleScript(script) else { return [] }
        var paths: [String] = []
        
        if result.numberOfItems > 0 {
            for i in 1...result.numberOfItems {
                if let item = result.atIndex(i)?.stringValue {
                    paths.append(item)
                }
            }
        } else if let singlePath = result.stringValue, !singlePath.isEmpty {
            paths.append(singlePath)
        }
        
        return paths
    }
    
    private func finderTargetFolder() -> URL? {
        let script = """
        tell application "Finder"
            if (count of windows) is 0 then
                return POSIX path of (path to home folder)
            else
                try
                    set targetPath to POSIX path of (target of front window as alias)
                    return targetPath
                on error
                    return POSIX path of (path to home folder)
                end try
            end if
        end tell
        """
        
        guard let result = runAppleScript(script),
              let path = result.stringValue else {
            return nil
        }
        
        return URL(fileURLWithPath: path)
    }
    
    private func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        let script = NSAppleScript(source: source)
        var errorDict: NSDictionary?
        let result = script?.executeAndReturnError(&errorDict)
        
        if let err = errorDict {
            print("AppleScript Error: \(err)")
        }
        
        return result
    }
    
    // per evitare due file con lo stesso nome nella stessa cartella
    private func uniqueDestinationURL(for sourceURL: URL, in destinationFolder: URL) -> URL {
        var destURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: destURL.path) {
            return destURL
        }
        
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        
        var copyIndex = 1
        while true {
            var newName = "\(fileName) copy"
            if copyIndex > 1 {
                newName += " \(copyIndex)"
            }
            if !fileExtension.isEmpty {
                newName += ".\(fileExtension)"
            }
            destURL = destinationFolder.appendingPathComponent(newName)
            if !fileManager.fileExists(atPath: destURL.path) {
                break
            }
            copyIndex += 1
        }
        return destURL
    }
    
    private func setFilesHidden(_ urls: [URL], hidden: Bool) {
        let paths = urls.map { $0.path }
        let script = """
         repeat with aPath in \(paths)
             tell application "Finder" to set extension hidden of (POSIX file aPath as alias) to \(hidden)
             -- Nota: 'extension hidden' nasconde l'estensione, ma per nascondere 
             -- l'intero file via AppleScript si usa il comando 'visible'
             do shell script "chflags " & (if \(hidden) then "hidden " else "nohidden ") & quoted form of aPath
         end repeat
         """
        _ = runAppleScript(script)
    }
    
}
