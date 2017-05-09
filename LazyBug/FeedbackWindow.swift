//
//  FeedbackWindow.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 04.05.17.
//
//

import UIKit

// MARK: - Dragging View

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

// MARK: - Feadback
fileprivate protocol FeedbackControllerDelegate {
    func controllerDidClose(_ feedbackController: FeedbackController)
}

class FeedbackController: UIViewController {
    fileprivate var snapshot: UIImage? {
        didSet {
            startAnimation(image: snapshot)
        }
    }

    fileprivate var annotedSnapshot: UIImage?

    private var imageView: UIImageView!
    private var dragView: RectView!

    fileprivate let dimmingTransitionDelegate = FeedbackTransitionDelegate()

    fileprivate var delegate: FeedbackControllerDelegate?
    private var snapGesture: UIPanGestureRecognizer!

    private func startAnimation(image: UIImage?) {
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
        case .changed:
            self.dragView.endPoint = src.location(in: self.imageView)
        case .ended:
            takeSnapshot()
            displayController()
        default:
            break
        }
    }
    private func takeSnapshot() {
        UIGraphicsBeginImageContext(self.view.bounds.size)
        // View
        self.view.drawHierarchy(in: UIScreen.main.bounds, afterScreenUpdates: true)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.annotedSnapshot = img
    }

    private func enablePinch(view: UIView) {
        // Pinch
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(FeedbackController.panTriggered(_:)))
        view.addGestureRecognizer(gesture)
        snapGesture = gesture
    }

    private func displayController() {
        performSegue(withIdentifier: "DimmingSegue", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DimmingSegue" {
            let dst = segue.destination as! FeedbackFormController
            dst.snapshot = annotedSnapshot
            dst.transitioningDelegate = dimmingTransitionDelegate
            dst.modalPresentationStyle = .custom
        }
    }
}

// MARK: - FeedbackWindow
protocol FeedBackWindowDelegate {
    func windowDidCancel(_ window: FeedbackWindow)
}

class FeedbackWindow: UIWindow, FeedbackControllerDelegate {

    fileprivate let controller: FeedbackController
    var delegate: FeedBackWindowDelegate?

    init(snapshot: UIImage) {
        controller = UIStoryboard(name: "Feedback", bundle: Bundle(for: Feedback.self)).instantiateInitialViewController() as! FeedbackController
        super.init(frame: UIScreen.main.bounds)
        windowLevel = UIWindowLevelAlert + 2
        rootViewController = controller
        isUserInteractionEnabled = true
        screen = UIScreen.main

        controller.delegate = self
        controller.snapshot = snapshot
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func controllerDidClose(_ feedbackController: FeedbackController) {
        delegate?.windowDidCancel(self)
    }
}

fileprivate class FeedbackTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return FeedbackPresentationController(presentedViewController: presented, presenting: presenting)
    }
}
// MARK: - Presentation
fileprivate class FeedbackPresentationController: UIPresentationController {
    let dimmingView = UIView()

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
         dimmingView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
    }

    override func presentationTransitionWillBegin() {
        dimmingView.frame = containerView?.bounds ?? CGRect.zero
        dimmingView.alpha = 0.0
        containerView?.insertSubview(dimmingView, at: 0)

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: {
            context in
            self.dimmingView.alpha = 1.0
        }, completion: nil)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        let screenBounds = UIScreen.main.bounds
        let inset = screenBounds.insetBy(dx: 20, dy: 20)
        return CGRect(origin: inset.origin, size: CGSize(width: inset.width, height: 250))

    }
}


// MARK: - Feedback form

class FeedbackFormController: UIViewController {

    var snapshot: UIImage?
    @IBOutlet weak var snapshotImageView: UIImageView!
    @IBOutlet weak var feedbackTextView: UITextView!
    override func loadView() {
        super.loadView()

        self.view.layer.cornerRadius = 10.0
        self.snapshotImageView.image = snapshot
    }
    @IBAction func addingTriggered(_ sender: Any) {
    }
    @IBAction func cancelTriggered(_ sender: Any) {
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        feedbackTextView.becomeFirstResponder()
    }
}
