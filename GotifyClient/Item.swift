//
//  Item.swift
//  GotifyClient
//
//  Created by kenko on 2025/11/13.
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
