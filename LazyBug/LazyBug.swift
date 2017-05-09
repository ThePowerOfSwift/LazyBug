//
//  LazyBug.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 03.05.17.
//
//

import Foundation


public struct LazyBugOptions {
    let baseURL: URL
    let options: [String: Any]?
}

public final class LazyBug: FeedBackWindowDelegate{

//    let options: LazyBugOptions

    var debugWindow: UIWindow?
    var feedbackWindow: UIWindow?

    var timer: Timer?
    static var shared: LazyBug!

    public static func setup() {
        LazyBug.shared = LazyBug()
    }
    private init() {
        startSession()
    }

    private func startSession() {
        // Start debugwindow
        showTransparentWindow()
        // Start Hooking on ScreenShots
        NotificationCenter.default.addObserver(self, selector: #selector(LazyBug.screenShotTriggered(notif:)), name: .UIApplicationUserDidTakeScreenshot, object: nil)
        //resetTimer()

        showFeedbackWindow()

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func showTransparentWindow() {
        let window = TransparentWindow()
        window.isHidden = false
        self.debugWindow = window
    }

    private func showFeedbackWindow() {
        guard let snapshot = LazyBug.takeRawSnapshot() else { return }
        let window = FeedbackWindow(snapshot: snapshot)
        window.isHidden = false
        self.feedbackWindow = window
        window.delegate = self
    }

    @objc func screenShotTriggered(notif: Notification) {
        showFeedbackWindow()
    }

    @objc func timerTriggered(timer: Timer) {
        print("Timer snapshot")
        takeScreenshot()
    }
    
    func takeScreenshot(withTouch touch: CGPoint? = nil) {
        let snapshot = LazyBug.takeRawSnapshot(withTouch: touch)
        Store.shared.addSnapshot(image: snapshot)
        resetTimer()
    }

    private func resetTimer() {
        if let t = timer {
            t.invalidate()
        }

        let t = Timer(timeInterval: 0.3, target: self, selector: #selector(LazyBug.timerTriggered), userInfo: nil, repeats: false)
        RunLoop.main.add(t, forMode: .defaultRunLoopMode)
        self.timer = t
    }

    private static func takeRawSnapshot(withTouch touch: CGPoint? = nil) -> UIImage? {

        let view = UIScreen.main.snapshotView(afterScreenUpdates: true)
        UIGraphicsBeginImageContext(UIScreen.main.bounds.size)

        // View
        view.drawHierarchy(in: UIScreen.main.bounds, afterScreenUpdates: true)
        //Touch
        if let touch  = touch {
            print("Snap with touch")
            UIColor.gray.setStroke()
            UIColor.lightGray.setFill()
            let path = UIBezierPath(ovalIn: CGRect(origin: touch, size: CGSize(width: 50, height: 50)))
            path.fill()
            path.stroke()
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return img
    }

    func windowDidCancel(_ window: FeedbackWindow) {
        window.isHidden = true
        self.feedbackWindow = nil
    }

  }
