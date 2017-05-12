//
//  FeebackSyncingProcedure.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 10.05.17.
//
//

import ProcedureKit
import CoreData

fileprivate class FeedbackSyncSingleProcedure: Procedure {
    let client: FeedbackServerClient
    let feedback: Feedback
    let moc: NSManagedObjectContext

    init(client: FeedbackServerClient, feedback: Feedback, psc: NSPersistentStoreCoordinator) {
        self.client = client
        self.feedback = feedback

        let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        moc.persistentStoreCoordinator = psc
        self.moc = moc

        super.init()
        name = "net.yageek.lazybug.feedbacksyncing.single.\(feedback.identifier ?? "<Unknown>")"
    }

    override func execute() {
        guard !isCancelled else { return }

        client.sendFeedback(feedback: self.feedback) { (error) in
            if error == nil {
                let id = self.feedback.objectID
                self.moc.perform {

                    let feedback = self.moc.object(with: id) as! Feedback
                    self.moc.delete(feedback)
                    do {
                        try self.moc.save()
                        self.finish()
                    } catch let error {
                        self.finish(withError: error)
                    }
                }
            } else {
                self.finish()
            }
        }
    }
}



final class FeebackSyncingProcedure: Procedure {

    let client: FeedbackServerClient
    init(client: FeedbackServerClient) {
        self.client = client
        super.init()
        name = "net.yageek.lazybug.feedbacksyncing"

        add(condition: MutuallyExclusive<FeebackSyncingProcedure>())
    }

    override func execute() {
        guard !isCancelled else { return }
              // All elements
        do {
            let elements = try Store.shared.getUnsyncedFeedback()
            guard elements.count > 0 else {
                Log.debug("No elements to sync :)")
                self.finish()
                return
            }

            Log.debug("Start Syncing elements...")

            let operations = elements.map {FeedbackSyncSingleProcedure(client: client, feedback: $0, psc: Store.shared.psc) }
            let group = GroupProcedure(operations: operations)

            group.addDidFinishBlockObserver(block: { (_, errors) in
                self.finish(withError: errors.first)
            })

            do {
                try produce(operation: group)
            } catch let error {
                self.finish(withError: error)
            }


        } catch let error {
            self.finish(withError: error)
        }
    }
}
