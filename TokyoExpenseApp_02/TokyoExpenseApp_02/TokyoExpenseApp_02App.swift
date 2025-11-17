//
//  TokyoExpenseApp_02App.swift
//  TokyoExpenseApp_02
//
//  Created by Claudia Ng on 11/12/25.
//

import SwiftUI
import SwiftData

@main
struct TokyoExpenseApp_02App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Expense.self)
    }
}
