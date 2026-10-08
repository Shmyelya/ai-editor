//
//  testApp.swift
//  test
//
//  Created by Yelzhan Yelikbaev on 07.10.2026.
//

import SwiftData
import SwiftUI

@main
struct testApp: App {
    var body: some Scene {
        WindowGroup {
            ChatListView()
        }
        .modelContainer(for: Chat.self)
    }
}
