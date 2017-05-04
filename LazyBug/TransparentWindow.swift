//
//  TransparentWindow.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 03.05.17.
//
//

import Foundation

private final class TransparentController: UIViewController {

    var transparentView: UIView!
    init() {

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.transparentView = UIView(frame: UIScreen.main.bounds)
        self.view = self.transparentView
        self.view.isUserInteractionEnabled = true
    }
}

final class TransparentWindow: UIWindow {

    fileprivate var lastPoint: CGPoint?

    fileprivate let controller: TransparentController
    init() {
        controller = TransparentController()
        super.init(frame: UIScreen.main.bounds)
        backgroundColor = UIColor.clear
        windowLevel = UIWindowLevelAlert + 1
        rootViewController = controller
        isUserInteractionEnabled = true
        screen = UIScreen.main
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let window = UIApplication.shared.delegate?.window ?? nil {
            return window.hitTest(point, with: event)
        }
        return super.hitTest(point, with: event)
    }

    override func sendEvent(_ event: UIEvent) {

        if let touches = event.allTouches {
            if let touch = touches.first {

                let point = touch.location(in: self)

                switch touch.phase {
                case .began:
                    LazyBug.shared.takeScreenshot(withTouch: point)
                    lastPoint = point
                case .moved:
                    if let last = lastPoint, hypotf(Float(last.x - point.x), Float(last.y - point.y)) > 25 {
                        LazyBug.shared.takeScreenshot(withTouch: point)
                        lastPoint = point
                    }
                default:
                    break
                }
            }
        }
        super.sendEvent(event)
    }
}
