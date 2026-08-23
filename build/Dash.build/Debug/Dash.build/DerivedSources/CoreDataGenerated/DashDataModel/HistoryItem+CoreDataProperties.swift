//
//  HistoryItem+CoreDataProperties.swift
//  
//
//  Created by Harsh Shah on 23/08/26.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias HistoryItemCoreDataPropertiesSet = NSSet

extension HistoryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HistoryItem> {
        return NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var title: String?
    @NSManaged public var url: String?

}

extension HistoryItem : Identifiable {

}
