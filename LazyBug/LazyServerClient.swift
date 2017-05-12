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
import SwiftProtobuf

enum NetworkError: Error {
    case compression
    case apiError
}

final class ConvertFeedbackProcedure: Procedure, OutputProcedure {

    let formatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter
    }()
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
            var request = Lazybug_Feedback()
            request.identifier = feedback.identifier!
            request.creationDate =  formatter.string(from: feedback.createdDate! as Date)
            request.content = feedback.content!
            if let meta = feedback.meta {
                request.meta = meta as Data
            }
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

final class ValidAPICode: Procedure, InputProcedure {

    var input: Pending<HTTPPayloadResponse<Data>> = .pending

    override func execute() {
        guard !isCancelled else { self.finish(); return }

        guard let result = input.value else {
            self.finish(withError: ProcedureKitError.requirementNotSatisfied())
            return
        }


        switch result.response.statusCode {
        case 200..<300:
            self.finish()
        default:
            self.finish(withError: NetworkError.apiError)
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
      
        var httpRequest = URLRequest(url: url.appendingPathComponent("/feedbacks"))
        httpRequest.httpMethod = "PUT"

        let convert = ConvertFeedbackProcedure(feedback: feedback)
        let transform = TransformProcedure { return HTTPPayloadRequest(payload: $0, request: httpRequest) }.injectResult(from: convert)
        let network = NetworkUploadProcedure(session: URLSession.shared).injectResult(from: transform)
        let valid = ValidAPICode().injectResult(from: network)

        valid.addDidFinishBlockObserver { (_, errors) in
            completion(errors.first)
        }
    
        queue.add(operations: convert, transform, network, valid)
    }
}
