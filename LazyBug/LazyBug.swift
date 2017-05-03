//
//  LazyBug.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 03.05.17.
//
//

import Foundation

public final class LazyBug {

    var debugWindow: UIWindow?

    static var shared: LazyBug = {
        return LazyBug()
    }()

    public static func setup() {
        let _ = LazyBug.shared
    }
    private init() {
        startSession()
    }

    private func startSession() {

        // Start debugwindow
        showTransparentWindow()
        // Start Session
//        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(LazyBug.timerTriggered(timer:)), userInfo: nil, repeats: true)
        // Start Hooking on ScreenShots
        NotificationCenter.default.addObserver(self, selector: #selector(LazyBug.screenShotTriggered(notif:)), name: .UIApplicationUserDidTakeScreenshot, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func showTransparentWindow() {
        let window = TransparentWindow()
        window.isHidden = false
        self.debugWindow = window
    }

    @objc func screenShotTriggered(notif: Notification) {
        print("Screen shots")
    }

    @objc func timerTriggered(timer: Timer) {
        Store.shared.addSnapshot(image: TakeScreenshot())
    }

  }
