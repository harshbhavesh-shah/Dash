//
//  DownloadItem+CoreDataProperties.swift
//  
//
//  Created by Harsh Shah on 23/08/26.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias DownloadItemCoreDataPropertiesSet = NSSet

extension DownloadItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadItem> {
        return NSFetchRequest<DownloadItem>(entityName: "DownloadItem")
    }

    @NSManaged public var filename: String?
    @NSManaged public var id: UUID?
    @NSManaged public var localPath: String?
    @NSManaged public var receivedBytes: Int64
    @NSManaged public var sourceURL: String?
    @NSManaged public var status: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var totalBytes: Int64

}

extension DownloadItem : Identifiable {

}
