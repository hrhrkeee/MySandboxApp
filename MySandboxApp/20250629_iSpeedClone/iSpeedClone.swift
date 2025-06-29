//
//  iSpeedClone.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/29.
//

import SwiftUI
import Charts

// MARK: - 市場情報モデル
struct MarketItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let price: String
    let change: String
    let percent: String
    let isUp: Bool
    let chartData: [Double]
}

// MARK: - カードビュー（変更なし）
struct MarketCard: View {
    let item: MarketItem
    @State var isFavorite = false

    var body: some View {
        NavigationLink(destination: CardDetailView(item: item)) {
            VStack(alignment: .leading, spacing: 4) {
                // ── 銘柄情報
                HStack() {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(item.price)
                            .font(.title2)
                            .bold()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // ボタンタップ時の処理
                        print("丸アイコンボタンがタップされました [\(item.title)]")
                        isFavorite.toggle()
                    }) {
                        if isFavorite {
                            Image(systemName: "heart.fill")        // SF Symbols のアイコン
                                .font(.headline)                     // アイコンサイズ
                                .foregroundColor(.black)           // アイコン色
                                .padding(8)                       // タップ領域を広げる
                                .background(.pink)             // 背景色を設定
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "heart.fill")        // SF Symbols のアイコン
                                .font(.headline)                     // アイコンサイズ
                                .foregroundColor(.white)           // アイコン色
                                .padding(8)                       // タップ領域を広げる
                                .background(Color.gray)             // 背景色を設定
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(DefaultButtonStyle())            // 押下時のデフォルトエフェクトを抑制
                    
                }
                HStack() {
                    Text(item.change)
                        .font(.subheadline)
                        .foregroundColor(item.isUp ? .green : .red)
                    Spacer()
                    Text(item.percent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Chart {
                    ForEach(Array(item.chartData.enumerated()), id: \.offset) { idx, val in
                        LineMark(
                            x: .value("Index", idx),
                            y: .value("Value", val)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(item.isUp ? .green : .red)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, item.chartData.count/2, item.chartData.count-1]) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: {
                        let min = item.chartData.min() ?? 0
                        let max = item.chartData.max() ?? 0
                        if min == max {
                            let delta = min == 0 ? 1 : min * 0.1
                            return [min - delta, min, max + delta]
                        } else {
                            return [min, (min+max)/2, max]
                        }
                    }()) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 70)
                .padding(.top, 10)
                
                
                HStack(alignment: .center, spacing: 8) {
                    Button("切断") {
                        print("切断")
                    }
                    .font(.caption2)                           // 最小文字サイズ
                    .lineLimit(1)                              // 1行に制限
                    .truncationMode(.tail)                     // はみ出したら … に
                    .frame(maxWidth: .infinity)                // 均等に幅を割り振る
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))    // 親背景と差をつける色
                    .foregroundColor(.gray)
                    .cornerRadius(6)

                    Button("リセット") {
                        print("リセット")
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .foregroundColor(.gray)
                    .cornerRadius(6)

                    Button("端末詳細") {
                        print("端末詳細")
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .foregroundColor(.gray)
                    .cornerRadius(6)
                }
                .frame(maxWidth: .infinity)  // HStack 自体も親幅いっぱいに
                .padding([.top], 4)
                
                
                
                
            }
            .padding(.all, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle()) // タップ時の青ハイライトを抑制
    }
}


// MARK: - 遷移先の詳細ビュー（全画面機能追加）
struct CardDetailView: View {
    let item: MarketItem
    @State private var isFullScreenPresented = false

    var body: some View {
        VStack(spacing: 16) {
            // 通常時の詳細コンテンツ
            Text(item.title)
                .font(.largeTitle)
                .bold()
            Text("現在値: \(item.price)")
                .font(.title2)
            Text(item.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Text(item.change)
                    .font(.subheadline)
                    .foregroundColor(item.isUp ? .green : .red)
                Text(item.percent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            // 簡易チャート（必要に応じて調整）
            GeometryReader { proxy in
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let maxY = item.chartData.max() ?? 1
                    let points = item.chartData.enumerated().map { idx, val in
                        CGPoint(
                            x: w * CGFloat(idx) / CGFloat(item.chartData.count - 1),
                            y: h * (1 - CGFloat(val) / CGFloat(maxY))
                        )
                    }
                    guard points.count > 1 else { return }
                    path.move(to: points[0])
                    for p in points.dropFirst() { path.addLine(to: p) }
                }
                .stroke(item.isUp ? Color.green : Color.red, lineWidth: 1)
            }
            .frame(height: 200)
        }
        .padding()
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 右側に全画面モーダル起動ボタンを配置
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isFullScreenPresented = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("全画面表示")
            }
        }
        // 全画面用のモーダル
        .fullScreenCover(isPresented: $isFullScreenPresented) {
            FullScreenDetailView(item: item)
        }
    }
}

// MARK: - 全画面表示用ビュー
struct FullScreenDetailView: View {
    let item: MarketItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 24) {
                Spacer()
                Text(item.title)
                    .font(.largeTitle)
                    .bold()
                Text("現在値: \(item.price)")
                    .font(.title2)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                }
                .accessibilityLabel("閉じる")
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - メインビュー（変更なし）
struct iSpeedCloneView: View {
    let items: [MarketItem] = [
        MarketItem(title: "日経225", subtitle: "15:15", price: "26,763.39",
                   change: "-43.28", percent: "-0.16%", isUp: false,
                   chartData: [100,102,101,99,98,97,98,100,64,56,23,21,23,4,5,4,454,65,43,332,2,4,3,546,345,423,42,12,3,43,345,543,45,6,4,3,423]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,99,100,101,103,105,104,106,29,10,23,4,5,6,7,8,12,32,35,43,79,90,100,99,100,101,103,105,104,106,29,10,23,4,5,6,7,8,12,32,35,43,79,90,100,99,100,101,103,105,104,106,29,10,23,4,5,6,7,8,12,32,35,43,79,90,100,99,100,101,103,105,104,106,29,10,23,4,5,6,7,8,12,32,35,43,79,90,100]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
        MarketItem(title: "日経225先物(期近)", subtitle: "17:19", price: "26,770",
                   change: "+30", percent: "+0.11%", isUp: true,
                   chartData: [98,98]),
    ]

    let columns = [
        GridItem(.flexible(), spacing: 5),
        GridItem(.flexible(), spacing: 5)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(items) { item in
                    MarketCard(item: item)
                }
            }
            .padding(5)
        }
        .navigationTitle("Market Today")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - プレビュー
#Preview{
    iSpeedCloneView()
}
