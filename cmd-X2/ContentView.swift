//
//  ContentView.swift
//  cmd-X2
//
//  Created by maria gabriella sica on 29/04/2026.
//

import SwiftUI
import AppKit


struct ContentView: View {
    
    @ObservedObject var manager = FileCutPasteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: manager.monitored ? "bolt.fill" : "bolt.slash")
                    .foregroundStyle(manager.monitored ? .green : .secondary)
                VStack(alignment: .leading) {
                    Text("Cut & Paste File Helper")
                        .font(.headline)
                    Text(manager.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            GroupBox("Permessi") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: manager.isAccessibilityEnabled ? "checkmark.seal.fill" : "exclamationmark.triangle")
                            .foregroundStyle(manager.isAccessibilityEnabled ? .green : .red)
                        Text(manager.isAccessibilityEnabled ? "Accessibilità attiva" : "Consenti Accessibilità per intercettare Cmd-X / Cmd-V")
                    }
                    HStack(spacing: 12) {
                        Button("Apri Impostazioni Accessibilità") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        Button("Aggiorna stato") {
                            manager.refreshAccessibilityStatus()
                        }
                    }
                    Text("Suggerito: abilita anche Accesso completo al disco e automazione per Finder per evitare errori di permesso.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 12) {
                Button(manager.monitored ? "Ferma" : "Avvia in background") {
                    if manager.monitored {
                        manager.stopMonitoring()
                    } else {
                        manager.startMonitoring()
                    }
                }
                Button("Pulisci tagliati") {
                    // Clear the in-memory cut list
                    // (A simple way is to restart monitoring or add a dedicated API; we call stop/start here)
                    manager.stopMonitoring()
                    manager.startMonitoring()
                }
                Spacer()
            }
            
            Text("Usa Cmd-X in Finder per tagliare i file selezionati e Cmd-V per incollarli nella cartella in primo piano.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 420)
        .onAppear {
            manager.refreshAccessibilityStatus()
        }
    }
}

#Preview {
    ContentView()
}
