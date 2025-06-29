//
//  UIPracticeView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/29.
//

import SwiftUI

struct UIPracticeView: View {
    
    var body: some View {
        List {
            NavigationLink {
                ZStack {
                    IgnoresSafeAreaView()
                    DefaultAreaView()
                }
            } label: {
                Text("Tabbarあり")
            }
            
            NavigationLink {
                ZStack {
                    IgnoresSafeAreaView()
                    DefaultAreaView()
                }
                .toolbar(.hidden, for: .tabBar)
            } label: {
                Text("Tabbarなし")
            }
            
            NavigationLink {
                ZStack {
                    NoRotationView()
                }
            } label: {
                Text("回転なし（強制縦画面）")
            }
            
            NavigationLink {
                ZStack {
                    InfinitePageView(pageCount: 5)
                        .ignoresSafeArea() // 全画面表示
                }
                .toolbar(.hidden, for: .tabBar)
            } label: {
                Text("ループカルーセル")
            }
            
            NavigationLink {
                ZStack {
                    IgnoresSafeAreaView()
                    DefaultAreaView()
                    CameraSampleView3()
                    ResizableFloatingGyroPIPView(enableUIRotation: false)
                }
                .toolbar(.hidden, for: .tabBar)
            } label: {
                Text("カメラの映像を配置")
            }
        }
        
    }
}


struct DefaultAreaView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .stroke(Color.red, lineWidth: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            GeometryReader {proxy in
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .stroke(Color.blue, lineWidth: 1)
                        .frame(maxHeight: proxy.size.height / 2)
                    
                    Rectangle()
                        .fill(Color.orange.opacity(0.2))
                        .stroke(Color.orange, lineWidth: 1)
                        .frame(maxHeight: proxy.size.height / 2)
                        .frame(maxWidth: proxy.size.width / 2)
                }
            }
        }
    }
}

struct IgnoresSafeAreaView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.green.opacity(0.2))
                .stroke(Color.green, lineWidth: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
    }
}

struct NoRotationView: View {
    var body: some View {
        Group {
            IgnoresSafeAreaView()
            DefaultAreaView()
            ResizableFloatingGyroPIPView(enableUIRotation: false)
        }
        .onAppear() {
            // 縦画面固定
            AppDelegate.orientationLock = .portrait
            
            if let windowScene = UIApplication.shared.connectedScenes
                                   .compactMap({ $0 as? UIWindowScene })
                                   .first,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        .onDisappear() {
            AppDelegate.orientationLock = .all

            if let windowScene = UIApplication.shared.connectedScenes
                                   .compactMap({ $0 as? UIWindowScene })
                                   .first,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}



#Preview {
    UIPracticeView()
}
