//
//  FeedbackServer.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 10.05.17.
//
//

import Foundation

protocol FeedbackServerClient {
    func sendFeedback(feedback: Feedback, completion: @escaping (Error?) -> Void)
}
