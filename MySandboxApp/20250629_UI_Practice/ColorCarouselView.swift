import SwiftUI
import UIKit

/// 1. 表示したい SwiftUI ページ
struct PageView: View {
    let index: Int
    var body: some View {
        ZStack {
            Color(hue: Double(index % 10) / 10, saturation: 0.8, brightness: 0.9)
            Text("ページ \(index + 1)")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

/// 2. UIPageViewController ラッパー
struct InfinitePageView: UIViewControllerRepresentable {
    let pageCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pvc.dataSource = context.coordinator
        // 初期ページは 0
        let initial = UIHostingController(rootView: PageView(index: 0))
        pvc.setViewControllers([initial], direction: .forward, animated: false)
        return pvc
    }

    func updateUIViewController(_ vc: UIPageViewController, context: Context) {}

    class Coordinator: NSObject, UIPageViewControllerDataSource {
        var parent: InfinitePageView

        init(_ parent: InfinitePageView) {
            self.parent = parent
        }

        func pageViewController(
            _ pvc: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let hosting = viewController as? UIHostingController<PageView> else {
                return nil
            }
            let prevIndex = (hosting.rootView.index - 1 + parent.pageCount) % parent.pageCount
            return UIHostingController(rootView: PageView(index: prevIndex))
        }

        func pageViewController(
            _ pvc: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let hosting = viewController as? UIHostingController<PageView> else {
                return nil
            }
            let nextIndex = (hosting.rootView.index + 1) % parent.pageCount
            return UIHostingController(rootView: PageView(index: nextIndex))
        }
    }
}
