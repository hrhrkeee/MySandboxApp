//
//  ContentView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/21.
//

import SwiftUI

struct ContentView: View {
    
    // 1. 辞書で画面を管理
    private let screens: [String: AnyView] = [
        "01_HomeView": AnyView(UISampleMainView()),
        "02_BluetoothSample": AnyView(BluetoothMainView()),
        "03_BLE広告": AnyView(BLEAdvertisingSampleView()),
        "04_BLEによる通信サンプル": AnyView(BLECommunicationDemo()),
        "05_ジャイロ機能のサンプル": AnyView(ResizableFloatingGyroPIPView()),
        "06_カメラ画像処理のサンプル": AnyView(CameraSampleMainView()),
        "07_カメラ画像処理のサンプル2": AnyView(CameraInputTestView()),
        "08_iSpeedのUIクローン": AnyView(iSpeedCloneView())
    ]
    
    // ソート済みのキー一覧
    private var screenNames: [String] {
        Array(screens.keys).sorted()
    }
    
    var body: some View {
        
        TabView {
            
            NavigationView {
                List(screenNames, id: \.self) { name in
                    NavigationLink(destination: screens[name]!) {
                        Text(name)
                    }
                }
                .navigationTitle("画面一覧")
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("ホーム")
            }

            
            NavigationView {
                UISampleMainView()
                .navigationTitle("画面一覧")
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("設定")
            }
            
        }
            
    }
}

#Preview {
    ContentView()
}
