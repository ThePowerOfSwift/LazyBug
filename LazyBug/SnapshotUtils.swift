//
//  SnapshotUtils.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 03.05.17.
//
//

import Foundation

func TakeScreenshot(withTouch touch: CGPoint? = nil) -> UIImage? {

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
