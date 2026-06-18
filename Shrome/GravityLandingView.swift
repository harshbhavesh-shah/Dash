//
//  GravityLandingView.swift
//  Shrome
//

import SwiftUI

struct GravityLandingView: View {
    @Binding var urlString: String
    var namespace: Namespace.ID // Interface binding parameter
    var onSubmit: (String) -> Void
    
    @FocusState private var isSearchFieldFocused: Bool
    
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
    
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning, Harshie" }
        if hour < 17 { return "Good afternoon, Harshie" }
        return "Good evening, Harshie"
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(dynamicGreeting)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Where are we sailing today?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 8)
                
                // THE MORPHING HUB SELECTION CONTAINER
                HStack(spacing: 0) {
                    Image(systemName: "magnifyingglass")
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
                // --- FIXED: THE CORE GEOMETRIC FLUID LINKAGE ---
                // Connects this pill container seamlessly to the bottom layout layer
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
    }
}
