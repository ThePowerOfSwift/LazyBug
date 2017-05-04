//
//  FeedbackWindow.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 04.05.17.
//
//

import UIKit

fileprivate class RectView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var startPoint:CGPoint?{
        didSet{
            self.setNeedsDisplay()
        }
    }
    var endPoint:CGPoint?{
        didSet{
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let start = startPoint, let end = endPoint else {
            return
        }
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: fabs(start.x - end.x), height: fabs(start.y - end.y))
        UIColor.red.setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = 5
        path.stroke()
    }
}

fileprivate protocol FeedbackControllerDelegate {
    func controllerDidClose(_ feedbackController: FeedbackController)
}

fileprivate class FeedbackController: UIViewController {
    private let snapshot: UIImage
    private var imageView: UIImageView!
    private var dragView: RectView!

    fileprivate var delegate: FeedbackControllerDelegate?
    private var snapGesture: UIPanGestureRecognizer!

    init(snapshot: UIImage) {
        self.snapshot = snapshot
        super.init(nibName: "FeedbackController", bundle: Bundle(for: FeedbackController.self))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        let imageV = UIImageView(image: snapshot)
        imageV.isUserInteractionEnabled = true
        imageV.frame = self.view.bounds

        self.view.addSubview(imageV)

        let ratio: CGFloat = 0.80
        UIView.animate(withDuration: 1.0, animations: { 
            imageV.layer.transform =  CATransform3DMakeScale(ratio, ratio, 1);
        }) { (finished) in
            if finished {
                self.enablePinch(view: self.imageView)
            }
        }
        self.imageView = imageV

        let rect = RectView(frame: imageV.bounds)
        dragView = rect
        imageV.addSubview(rect)
    }
    @IBAction func closeTriggered(_ sender: UIButton) {
        self.delegate?.controllerDidClose(self)
    }

    @objc func panTriggered(_ src: UIPinchGestureRecognizer) {
        switch src.state {
        case .began:
            self.dragView.startPoint = src.location(in: self.imageView)
        case .changed :
            self.dragView.endPoint = src.location(in: self.imageView)
        default:
            break
        }
    }

    private func enablePinch(view: UIView) {
        // Pinch
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(FeedbackController.panTriggered(_:)))
        view.addGestureRecognizer(gesture)
        snapGesture = gesture

    }
}

protocol FeedBackWindowDelegate {
    func windowDidCancel(_ window: FeedbackWindow)
}

class FeedbackWindow: UIWindow, FeedbackControllerDelegate {

    fileprivate let controller: FeedbackController
    var delegate: FeedBackWindowDelegate?

    init(snapshot: UIImage) {
        controller = FeedbackController(snapshot: snapshot)
        super.init(frame: UIScreen.main.bounds)
        windowLevel = UIWindowLevelAlert + 2
        rootViewController = controller
        isUserInteractionEnabled = true
        screen = UIScreen.main

        controller.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func controllerDidClose(_ feedbackController: FeedbackController) {
        delegate?.windowDidCancel(self)
    }
}
