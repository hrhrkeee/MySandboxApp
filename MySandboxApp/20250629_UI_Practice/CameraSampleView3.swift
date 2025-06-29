import SwiftUI

struct CameraSampleView3: View {
    @StateObject private var camera = CameraModel2()
    @State private var selectedDeviceID: String = ""
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if let img = camera.currentFrame {
                    CameraImageView(image: img)
                        .border(Color.red, width: 2)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.white)
                }
            }
            .frame(height: proxy.size.height / 3)
        }
        .onAppear(perform: startCamera)
        .onDisappear(perform: stopCamera)
    }
    
    // MARK: - Lifecycle
    private func startCamera() {
        setOrientation(.portrait)
        if selectedDeviceID.isEmpty, let first = camera.devices.first {
            selectedDeviceID = first.uniqueID
        }
        camera.start()
    }
    
    private func stopCamera() {
        setOrientation(.all)
        camera.stop()
    }
    
    // MARK: - Orientation Handling
    private func setOrientation(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

private struct CameraImageView: View {
    let image: UIImage
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.green   // 余白部分を黒に

                Image(uiImage: image.rotated90())
                    .resizable()              // リサイズ可能に
                    .scaledToFit()            // アスペクト比維持でフィット
                    .frame(
                        width:  geo.size.width,
                        height: geo.size.height
                    )
                    // .clipped() は使わず、切り取り禁止
            }
        }
    }
}

// ─── 1. UIImage を回転する Extension ─────────────────────────────
extension UIImage {
    /// 90°（π/2ラジアン）回転した UIImage を返す
    func rotated90() -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return self }

        // 中心を原点に移動してから回転
        ctx.translateBy(x: newSize.width/2, y: newSize.height/2)
        ctx.rotate(by: .pi/2)

        // 元画像を中心合わせで描画
        draw(in: CGRect(
            x: -size.width/2,
            y: -size.height/2,
            width: size.width,
            height: size.height
        ))

        let rotated = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return rotated
    }
}
