//
//  GravityLandingView.swift
//  Shrome
//
//  Created by Harsh Shah on 07/03/2026.
//


import SwiftUI

struct GravityLandingView: View {
    @Binding var urlString: String
    var onSearch: (String) -> Void
    @FocusState private var isFocused: Bool
    
    // Tap into our color preferences
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    
    // The Master Switch for the stars
    @AppStorage("useMagicMode") private var useMagicMode: Bool = false
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
    
    // The Sky & Sage Blend
    var magicGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.75, blue: 1.0), // Sky
                Color(red: 0.3, green: 0.85, blue: 0.5)  // Sage
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            // LAYER 1: THE BACKGROUND
            if useMagicMode {
                // Render the stars directly here!
                ShootingStarsView()
                    .transition(.opacity)
            } else {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
            }
            
            // LAYER 2: THE MONOLITHIC PILL
            VStack {
                HStack(spacing: 15) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(useMagicMode ? .white.opacity(0.6) : .primary.opacity(0.3))
                    
                    TextField("Search or enter address", text: $urlString)
                        .textFieldStyle(.plain)
                        .foregroundColor(useMagicMode ? .white : .primary)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .focused($isFocused)
                        .onSubmit { onSearch(urlString) }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .frame(width: 540)
                .background(
                    ZStack {
                        Capsule()
                            .fill(Color(NSColor.controlBackgroundColor).opacity(useMagicMode ? 0.3 : 1.0))
                        
                        Capsule()
                            .stroke(useMagicMode ? Color.white.opacity(0.2) : Color.primary.opacity(0.08), lineWidth: 1)
                    }
                )
                // The dynamic glow (Aurora in Magic Mode, Solid Color in Normal Mode)
                .background(
                    Capsule()
                        .fill(useMagicMode ? AnyShapeStyle(magicGradient) : AnyShapeStyle(accentColor))
                        .blur(radius: isFocused ? 45 : 30)
                        .opacity(useMagicMode ? 0.4 : 0.6)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .scaleEffect(isFocused ? 1.02 : 1.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -20)
        }
        .onAppear {
            isFocused = true
        }
        .animation(.easeInOut(duration: 0.8), value: useMagicMode) // Smooth fade between space and solid
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isFocused)
    }
}
