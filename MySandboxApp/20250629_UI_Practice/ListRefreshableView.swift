//
//  ListRefreshableView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/29.
//

import SwiftUI

struct ListRefreshableView: View {
    @State private var items: [String] = (1...20).map { "項目 \($0)" }  // 初期 20 項目
    @State private var isLoadingMore = false

    var body: some View {
        
        VStack {
            List {                                                  // リスト
                // --- リストアイテム ---
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .onAppear {                                // セルが画面表示されたとき
                            if item == items.last {                // 最後の項目なら
                                Task { await loadMore() }          // 次ページを読み込む
                            }
                        }
                }

                // --- フッターにプログレスビューを表示 ---
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .id(items.count)      // ← 読み込みごとに items.count が変わるので新規ビュー扱い
                        Spacer()
                    }
                }
            }
            .listStyle(.insetGrouped)                                      // プレーンスタイルで余白削除
            .refreshable {                                          // プル・トゥ・リフレッシュ
                await shuffleItems()
            }
            .navigationTitle("プル＆無限スクロール")                 // タイトル
        }
        
        
    }

    /// リストをシャッフル（プル更新用）
    private func shuffleItems() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)          // デモで 1秒待機
        items = (1...20).map { "項目 \($0)" }  // 初期 20 項目
        items.shuffle()                                           // 順序をランダムに
    }

    /// 最下部到達で次の項目を追加読み込み
    private func loadMore() async {
        guard !isLoadingMore else { return }                      // 多重呼び出し防止
        isLoadingMore = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)          // デモで 1秒待機

        let start = items.count + 1
        let more = (start...start+19).map { "項目 \($0)" }         // 新たに 20 項目生成
        items.append(contentsOf: more)                            // 配列に追加

        isLoadingMore = false
    }
}
