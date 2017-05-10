//
//  LazyServerClient.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 10.05.17.
//
//

import Foundation
import ProcedureKit
import ProcedureKitNetwork
import Compression

enum NetworkError: Error {
    case compression
}
final class ConvertFeedbackProcedure: Procedure, OutputProcedure {

    let formatter = ISO8601DateFormatter()
    let feedback: Feedback
    var output: Pending<ProcedureResult<Data>> = .pending

    init(feedback: Feedback) {
        self.feedback = feedback
        super.init()
        name = "net.yageek.lazybug.convertFeedback.\(feedback.identifier ?? "Unknown")"
    }

    override func execute() {

        guard !isCancelled else { self.finish(); return }

        do {
            var request = Lazybug_FeedbackAddRequest()
            request.identifier = feedback.identifier!
            request.creationDate =  formatter.string(from: feedback.createdDate! as Date)
            request.content = feedback.content!
            request.meta = try JSONSerialization.data(withJSONObject: Bundle.main.infoDictionary!, options: [])
            request.snapshot = feedback.snapshot! as Data
            let data = try request.serializedData()

            self.finish(withResult: .success(data))

        } catch let error {
            Log.error("Error during marshalling: \(error)")
            self.finish(withError: error)
        }
    }
}

final class CompressDataProcedure: Procedure, InputProcedure, OutputProcedure {

    private var compressBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)

    var input: Pending<Data> = .pending
    var output: Pending<ProcedureResult<Data>> = .pending

    override func execute() {
        guard !isCancelled else { self.finish(); return }

        guard let data = input.value else {
            self.finish(withError: ProcedureKitError.dependenciesFailed())
            return
        }

        var result: Int = 0
        data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            result = compression_encode_buffer(compressBuffer, 4096, bytes, data.count, nil, COMPRESSION_LZFSE)
        }

        if result == 0 {
            self.finish(withError: NetworkError.compression)
        } else {
            let data = Data(bytes: compressBuffer, count: result)
            self.finish(withResult: .success(data))
        }
    }
}

final class LazyServerClient: FeedbackServerClient {
    let queue: ProcedureQueue = {
        let queue = ProcedureQueue()
        queue.qualityOfService = .background
        queue.name = "net.yageek.lazybug.lazyserverclient"
        return queue
    }()

    let url: URL

    init(url: URL) {
        self.url = url
    }

    func sendFeedback(feedback: Feedback, completion: @escaping (Error?) -> Void) {
        var finalError: Error?
        defer {
            completion(finalError)
        }

        var httpRequest = URLRequest(url: url.appendingPathComponent("/feedbacks"))
        httpRequest.httpMethod = "PUT"


        // Get Unsynced
        let convert = ConvertFeedbackProcedure(feedback: feedback)
        let transform = TransformProcedure { return HTTPPayloadRequest(payload: $0, request: httpRequest) }.injectResult(from: convert)
        let network = NetworkUploadProcedure(session: URLSession.shared).injectResult(from: transform)
        network.addDidFinishBlockObserver { (_, errors) in
            completion(errors.first)
        }
        
        queue.add(operations: convert, transform, network)
    }
}
