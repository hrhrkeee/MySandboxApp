//
//  UISampleMainView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/21.
//


import SwiftUI

struct UISampleMainView: View {
    let scores: [String: Int] = [
        "Alice": 90, "Bob": 75, "Carol": 88
    ]

    var body: some View {
        List(scores.keys.sorted(), id: \.self) { name in
            NavigationLink(destination: DetailView(name: name, score: scores[name]!)) {
                Text(name)
            }
        }
        .navigationTitle("名前一覧")  // ナビゲーションバーのタイトル
    }
}

struct DetailView: View {
    let name: String
    let score: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("\(name) さん")
                .font(.title)
            Text("スコア: \(score)")
                .font(.headline)
        }
        .padding()
        .navigationTitle("サブ詳細")  // ナビゲーションバーのタイトル
    }
}


#Preview {
    UISampleMainView()
}
