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

    override var next: UIResponder? {
        return UIApplication.shared.delegate?.window ?? nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let point = event?.allTouches?.first?.location(in: self) else {
            return
        }

        Store.shared.addSnapshot(image: TakeScreenshot(withTouch: point))
        lastPoint = point

        self.next?.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        guard let point = event?.allTouches?.first?.location(in: self) else {
            print("Touched")
            return
        }
        if let last = lastPoint {
            let delta = hypotf(Float(last.x - point.x), Float(last.y - point.y))
            print("Delta: \(delta)")
            if delta > 25 {
                print("Enough moved")
                Store.shared.addSnapshot(image: TakeScreenshot(withTouch: point))
                lastPoint = point
            }
        }
        self.next?.touchesMoved(touches, with: event)
    }

}
