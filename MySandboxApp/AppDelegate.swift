//
//  AppDelegate.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/29.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
}
