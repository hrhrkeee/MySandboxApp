//
//  ObjectDetectionModel.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/22.
//

import AVFoundation    // AVFoundation（オーディオ/ビデオフレームワーク）
import Vision           // Vision（ビジョンフレームワーク）
import CoreML           // Core ML（コアエムエル）
import UIKit

/// 検出結果を表す構造体
struct Detection {
    let boundingBox: CGRect   // 正規化されたバウンディングボックス (0–1)
    let label: String         // クラス名
    let confidence: Float     // 信頼度
}

/// 物体検出＋画像処理モデル
class ObjectDetectionModel: NSObject, ObservableObject {
    @Published var detections: [Detection] = []
    var vnRequest: VNCoreMLRequest!
    private let visionQueue = DispatchQueue(label: "vision.queue")
    
    var confidenceThreshold: Float = 0.5

    override init() {
        // 1. Core MLモデルをロード
        let mlModel = try! YOLOv3TinyInt8LUT(configuration: .init()).model     // YOLOv3.mlmodelc
        let visionModel = try! VNCoreMLModel(for: mlModel)
        
        super.init()
        
        // 2. リクエスト生成
        vnRequest = VNCoreMLRequest(model: visionModel) { [weak self] req, _ in
            guard let self = self,
                  let results = req.results as? [VNRecognizedObjectObservation]
            else { return }

            // 3. しきい値フィルタ＋マッピング
            let filtered: [Detection] = results.compactMap { obs in
                // 最も信頼度の高いラベル
                guard let top = obs.labels.first,
                      top.confidence >= self.confidenceThreshold
                else {
                    return nil
                }
                return Detection(
                    boundingBox: obs.boundingBox,
                    label: top.identifier,
                    confidence: top.confidence
                )
            }

            // メインスレッドで更新
            DispatchQueue.main.async {
                self.detections = filtered
            }
        }
        
        vnRequest.imageCropAndScaleOption = .scaleFill
    }

    /// フレームごとに呼ぶ推論実行メソッド
    func analyze(pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        visionQueue.async {
            try? handler.perform([self.vnRequest])
        }
    }
}
