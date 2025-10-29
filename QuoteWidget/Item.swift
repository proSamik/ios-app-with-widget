//
//  Item.swift
//  QuoteWidget
//
//  Created by Samik Choudhury on 30/10/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
