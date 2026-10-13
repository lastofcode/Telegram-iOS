import Foundation
import UIKit

/// Runs Telegram inside another app's process and scene.
///
/// The host app loads TelegramUIFramework at runtime and drives Telegram through this class
/// (looked up with `NSClassFromString("TelegramEmbeddedHost")`), so the host never links
/// against Telegram's Swift modules. Telegram's window is placed on top of the host's window
/// while shown and hidden again afterwards; while hidden, Telegram is treated as backgrounded.
@objc(TelegramEmbeddedHost)
public final class TelegramEmbeddedHost: NSObject {
    private static var appDelegate: AppDelegate?
    private static weak var hostWindow: UIWindow?
    private static var exitGestureDelegate: ExitGestureDelegate?

    @objc public static var isVisible: Bool {
        guard let window = self.appDelegate?.window else {
            return false
        }
        return !window.isHidden
    }

    /// Starts Telegram on first use and puts its window in front of `scene`'s key window.
    @objc public static func show(in scene: UIWindowScene) {
        self.hostWindow = scene.windows.first(where: { $0.isKeyWindow })

        if let appDelegate = self.appDelegate {
            if appDelegate.window?.windowScene !== scene {
                appDelegate.attachWindow(to: scene)
            }
            appDelegate.window?.isHidden = false
            appDelegate.window?.makeKeyAndVisible()
            appDelegate.handleWillEnterForeground()
            appDelegate.handleDidBecomeActive()
            return
        }

        AppDelegate.isEmbedded = true
        let appDelegate = AppDelegate()
        self.appDelegate = appDelegate
        let _ = appDelegate.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        appDelegate.attachWindow(to: scene)
        if let window = appDelegate.window {
            self.installExitGesture(on: window)
        }
        appDelegate.handleWillEnterForeground()
        appDelegate.handleDidBecomeActive()
    }

    /// Hides Telegram's window, returns focus to the host window and takes Telegram offline.
    @objc public static func hide() {
        guard let appDelegate = self.appDelegate, let window = appDelegate.window, !window.isHidden else {
            return
        }
        appDelegate.handleWillResignActive()
        appDelegate.handleDidEnterBackground()
        window.endEditing(true)
        window.isHidden = true
        self.hostWindow?.makeKeyAndVisible()
    }

    @objc public static func sceneWillResignActive() {
        guard self.isVisible else {
            return
        }
        self.appDelegate?.handleWillResignActive()
    }

    @objc public static func sceneDidBecomeActive() {
        guard self.isVisible else {
            return
        }
        self.appDelegate?.handleDidBecomeActive()
    }

    /// The host is going to the background: hide Telegram so the app switcher snapshot
    /// and the next launch show the host app.
    @objc public static func sceneDidEnterBackground() {
        self.hide()
    }

    private static func installExitGesture(on window: UIWindow) {
        let delegate = ExitGestureDelegate()
        self.exitGestureDelegate = delegate

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.exitGestureRecognized(_:)))
        recognizer.numberOfTouchesRequired = 2
        recognizer.numberOfTapsRequired = 2
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = delegate
        window.addGestureRecognizer(recognizer)
    }

    @objc private static func exitGestureRecognized(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.hide()
        }
    }
}

private final class ExitGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
