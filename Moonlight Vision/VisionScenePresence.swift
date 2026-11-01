//
//  VisionScenePresence.swift
//  Moonlight Vision
//
//  Avoid opening a second mainView when a plain window is already on-screen
//  (common during zombie stream-window cleanup races on visionOS).
//

import SwiftUI
import UIKit

enum VisionScenePresence {
    /// True when any plain (non-volumetric) application window scene is already presented.
    static var hasPresentedPlainWindow: Bool {
        UIApplication.shared.connectedScenes.contains { scene in
            guard let windowScene = scene as? UIWindowScene else { return false }
            guard windowScene.session.role == .windowApplication else { return false }
            switch windowScene.activationState {
            case .foregroundActive, .foregroundInactive, .background:
                return windowScene.windows.contains { !$0.isHidden }
            default:
                return false
            }
        }
    }

    static func openMainViewIfNeeded(_ openWindow: OpenWindowAction) {
        if hasPresentedPlainWindow {
            NSLog("[Scene] mainView already present; skip duplicate openWindow")
            return
        }
        openWindow(id: "mainView")
    }
}
