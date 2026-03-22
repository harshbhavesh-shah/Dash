//
//  LandingPageView.swift
//  Shrome
//
//  Created by Harsh Shah on 07/03/2026.
//

import SwiftUI

struct LandingPageView: View {
    @Binding var urlString: String
    var onSearch: (String) -> Void
    
    @AppStorage("useMagicMode") private var useMagicMode: Bool = false
    
    let favorites = [
        (name: "Apple", url: "apple.com", icon: "apple.logo"),
        (name: "GitHub", url: "github.com", icon: "terminal.fill"),
        (name: "YouTube", url: "youtube.com", icon: "play.rectangle.fill"),
        (name: "Dribbble", url: "dribbble.com", icon: "paintpalette.fill")
    ]
    
    var body: some View {
        ZStack {
            if useMagicMode {
                ShootingStarsView()
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [Color.primary.opacity(0.03), Color(NSColor.windowBackgroundColor)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 0) {
                    Text(Date(), style: .time)
                        .font(.system(size: 80, weight: .thin, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8)) // Adaptive
                    
                    Text("Good Morning, Captain.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary.opacity(0.5)) // Adaptive
                }
                .padding(40)
                .background(LiquidGlass().opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 40))
                
                HStack(spacing: 20) {
                    ForEach(favorites, id: \.name) { site in
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(0.05)) // Adaptive
                                    .frame(width: 60, height: 60)
                                    .polishedGlassAesthetic()
                                
                                Image(systemName: site.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary.opacity(0.7)) // Adaptive
                            }
                            
                            Text(site.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.6)) // Adaptive
                        }
                        .onTapGesture {
                            onSearch(site.url)
                        }
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                    }
                }
                
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Ensure the gradient doesn't blind us in dark mode
            .background(
                LinearGradient(
                    colors: [Color.primary.opacity(0.03), Color(NSColor.windowBackgroundColor)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .animation(.easeInOut(duration: 0.8), value: useMagicMode)
    }
}
