//
//  GravityLandingView.swift
//  Shrome
//

import SwiftUI

struct GravityLandingView: View {
    @Binding var urlString: String
    var namespace: Namespace.ID
    var onSubmit: (String) -> Void
    
    @FocusState private var isSearchFieldFocused: Bool
    
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    
    @EnvironmentObject var tabManager: TabManager
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
    
    private var isPrivateSession: Bool {
        tabManager.activeTab.isPrivate
    }
    
    // --- SUBTLE: Swaps the greeting targets perfectly ---
    private var dynamicGreeting: String {
        let name = isPrivateSession ? "Stranger" : "Harshie"
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning, \(name)" }
        if hour < 17 { return "Good afternoon, \(name)" }
        return "Good evening, \(name)"
    }
    
    // --- SUBTLE: Your custom stealth quote line ---
    private var dynamicSubheader: String {
        if isPrivateSession {
            return "No one will know where we are sailing today."
        }
        return "Where are we sailing today?"
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // THE DASHBOARD GREETING HEADER (Completely clean hierarchy)
                VStack(spacing: 6) {
                    Text(dynamicGreeting)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary) // Regular adaptive color tracking
                    
                    Text(dynamicSubheader)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 8)
                
                // THE MORPHING HUB SELECTION CONTAINER
                HStack(spacing: 0) {
                    // --- SUBTLE: Simple icon swap, keeping your core theme accent color ---
                    Image(systemName: isPrivateSession ? "shield.fill" : "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.leading, 20)
                    
                    TextField("Search with Shrome...", text: $urlString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            onSubmit(urlString)
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 20)
                }
                .matchedGeometryEffect(id: "sharedAddressBarKey", in: namespace)
                .frame(width: 550, height: 48)
                .background {
                    Color.clear
                        .glassEffect(
                            .regular.tint(accentColor.opacity(0.06)),
                            in: Capsule()
                        )
                }
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.65), accentColor.opacity(0.35), accentColor.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 510, height: 24)
                        .blur(radius: 35)
                        .opacity(0.85)
                }
                .shadow(color: .black.opacity(0.02), radius: 15, x: 0, y: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if urlString == "about:blank" {
                urlString = ""
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
    }
}
