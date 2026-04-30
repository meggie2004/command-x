//
//  cmd_X2App.swift
//  cmd-X2
//
//  Created by maria gabriella sica on 29/04/2026.
//

import SwiftUI

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
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
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

