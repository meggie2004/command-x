//
//  cmd_X2App.swift
//  cmd-X2
//
//  Created by maria gabriella sica on 29/04/2026.
//

import SwiftUI


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Se non ci sono finestre visibili, mostra la prima disponibile
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

@main
struct cmd_xApp: App {
    
    @State private var statusItem: NSStatusItem?
    
    // stateobject garantisce la persistenza
    @StateObject private var manager = FileCutPasteManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        MenuBarExtra {
            Text("stato: \(manager.statusMessage)")
            
            Button(manager.monitored ? "disattiva" : "attiva") {
                if manager.monitored {
                    manager.stopMonitoring()
                } else {
                    manager.startMonitoring()
                }
            }
            
            Button("settings") {
                NSApp.activate(ignoringOtherApps: true) // forza l'apertura della finestra principale
                
                //per vedere se c'è già una finestra aperta
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    let url = URL(string: "cmd-x2://settings")!
                    NSWorkspace.shared.open(url)
                }
            }
            
            Divider()
            
            Button("ESC") {
                NSApplication.shared.terminate(nil)
            }
        }label: {
            Image(systemName: manager.monitored ? "scissors.circle.fill" : "scissors.circle")
            
        }
    }
}

// prova git

