//
//  HapticFeedback.swift
//  Dash
//
//  Created by Harsh Shah on 13/07/2026.
//

import AppKit

enum DashHaptics {
    static func confirmationTap() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.generic, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            performer.perform(.generic, performanceTime: .now)
        }
    }
}
