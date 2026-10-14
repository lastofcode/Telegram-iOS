import Foundation
import UIKit

@objc(EmbeddedContentHost)
public final class EmbeddedContentHost: NSObject {
    private static var appDelegate: AppDelegate?
    private static weak var hostWindow: UIWindow?
    private static var exitGestureDelegate: ExitGestureDelegate?

    @objc public static var isVisible: Bool {
        guard let window = self.appDelegate?.window else {
            return false
        }
        return !window.isHidden
    }

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
