//
//  LazyBug.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 03.05.17.
//
//

import Foundation
import XCGLogger
import ProcedureKit

let Log = XCGLogger.default

public final class LazyBug: FeedBackWindowDelegate {

    let queue: ProcedureQueue = {
        let queue = ProcedureQueue()
        queue.qualityOfService = .background
        return queue
    }()

    let feedbackClient: FeedbackServerClient

    var debugWindow: UIWindow?
    var feedbackWindow: UIWindow?

    var timer: Timer?
    static var shared: LazyBug!

    public static func setup(withURL url: String) {
        guard let convertedURL = URL(string: url) else {
            fatalError("Provided url is incorrect.")
        }
        LogManager.severity = .verbose
        LazyBug.shared = LazyBug(withURL: convertedURL)
    }
    private init(withURL url: URL) {
        self.feedbackClient = LazyServerClient(url: url)
        startSession()
    }

    private func startSession() {
        // Start Hooking on ScreenShots
        NotificationCenter.default.addObserver(self, selector: #selector(LazyBug.screenShotTriggered(notif:)), name: .UIApplicationUserDidTakeScreenshot, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LazyBug.feebackFormDidClose(notif:)), name: FeedbackFormController.DidCloseNotification, object: nil)
        showFeedbackWindow()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func showTransparentWindow() {
        let window = TransparentWindow()
        window.isHidden = false
        self.debugWindow = window
        resetTimer()
    }

    private func showFeedbackWindow() {
        guard let snapshot = LazyBug.takeRawSnapshot() else { return }
        let window = FeedbackWindow(snapshot: snapshot)
        window.isHidden = false
        self.feedbackWindow = window
        window.delegate = self
        performSync()
    }
    
    private func hideFeedbackWindow() {
        self.feedbackWindow?.isHidden = true
        self.feedbackWindow = nil
    }

    @objc func screenShotTriggered(notif: Notification) {
        showFeedbackWindow()
    }

    @objc func timerTriggered(timer: Timer) {
        print("Timer snapshot")
        takeScreenshot()
    }

    @objc func feebackFormDidClose(notif: Notification) {
        hideFeedbackWindow()
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
            Log.debug("Snap with touch: \(touch)")
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

    // MARK: - Sync

    func performSync() {
        queue.add(operation: FeebackSyncingProcedure(client: self.feedbackClient))
    }
  }
