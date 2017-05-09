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
        let modelURL =  Bundle(for: Store.self).url(forResource: "LazyBug", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
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
    static var shared = Store()
}
