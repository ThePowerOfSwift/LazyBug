//
//  Store.swift
//  LazyBug
//
//  Created by Yannick Heinrich on 03.05.17.
//
//

import Foundation
import CoreData

final class Store {

    var currentSession: Session!

    lazy var psc: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.model)
        let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        queue.sync {
            guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
                fatalError("Unable to resolve document directory")
            }
            let storeURL = docURL.appendingPathComponent("LazyBug.sqlite")
            do {
                try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }
        return coordinator
    }()

    lazy var model: NSManagedObjectModel = {
        let modelURL = Bundle(for: Store.self).url(forResource: "LazyBug", withExtension: "momd")
        return NSManagedObjectModel(contentsOf: modelURL!)!
    }()

    lazy var moc: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        moc.persistentStoreCoordinator = self.psc
        return moc
    }()

    private init() {

        moc.performAndWait { [unowned self] in
            let session = NSEntityDescription.insertNewObject(forEntityName: "Session", into: self.moc) as! Session
            session.identifier = UUID().uuidString
            session.startDate = NSDate()
            self.currentSession = session
            do {
                try self.moc.save()
                print("New session started")
            } catch let error {
                print(error)
            }
        }
    }
    // MARK: - Snapshot
    func addSnapshot(image: UIImage?) {

        guard let image = image else {
            print("No images has been recorded")
            return
        }

        self.moc.perform {

            let snapshot = NSEntityDescription.insertNewObject(forEntityName: "Snapshot", into: self.moc) as! Snapshot
            snapshot.content = UIImageJPEGRepresentation(image, 0.5) as NSData?
            snapshot.session = self.currentSession
            snapshot.triggeredDate = NSDate()

            do {
                try self.moc.save()
                print("Snapshot created")
            } catch let error {
                print("Error: \(error)")
            }
        }
    }

    // MARK: - Feedback
    func addFeedback(content: String, image: UIImage, completion: @escaping () -> Void) {

        self.moc.perform {
            do {
                let feedback = NSEntityDescription.insertNewObject(forEntityName: "Feedback", into: self.moc) as! Feedback
                feedback.content = content
                feedback.snapshot = UIImageJPEGRepresentation(image, 0.5) as NSData?
                feedback.createdDate = Date() as NSDate
                feedback.identifier = UUID().uuidString

                try self.moc.save()
                DispatchQueue.global(qos: .background).async {
                    completion()
                }

            } catch let error {
                Log.debug("Impossible to save: \(error)")
                
            }
            
        }
    }


    func getUnsyncedFeedback() throws -> [Feedback] {

        let request = NSFetchRequest<Feedback>(entityName: "Feedback")
        request.returnsObjectsAsFaults = false
        request.includesSubentities = true

        var result: [Feedback] = []
        var finalError: Error?
        self.moc.performAndWait {

            do {
                result = try self.moc.fetch(request)
            } catch let error {
                Log.error("Error: \(error)")
                finalError = error
            }
        }

        if let error = finalError {
            throw error
        }
        return result
    }
    static var shared = Store()
}
