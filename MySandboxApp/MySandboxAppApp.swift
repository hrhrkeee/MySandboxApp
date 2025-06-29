//
//  MySandboxAppApp.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/21.
//

import SwiftUI

@main
struct MySandboxAppApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
