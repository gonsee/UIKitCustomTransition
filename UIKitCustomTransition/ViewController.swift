//
//  ViewController.swift
//  UIKitCustomTransition
//
//  Created by Shingo Sato on 2025/12/21.
//

import UIKit

final class ViewController: UIViewController {
    weak var customPresentationController: CustomPresentationController?

    @IBAction func open(_ sender: Any) {
        let viewController = ChildViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .custom
        navigationController.transitioningDelegate = self
        present(navigationController, animated: true)
    }
}

final class ChildViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Transitioning Delegate

extension ViewController: UIViewControllerTransitioningDelegate {
    /// Presentation Controllerを返す
    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        let presentationController = CustomPresentationController(
            presentedViewController: presented,
            presenting: presenting,
            backgroundColor: UIColor.systemBlue
        )
        customPresentationController = presentationController
        return presentationController
    }

    /// 開くとき用のAnimatorを返す
    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        SlideInAnimator()
    }

    /// 閉じるとき用のAnimatorを返す
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        SlideOutAnimator()
    }

    /// ドラッグで閉じるための InteractiveTransitioning のインスタンスを返す
    func interactionControllerForDismissal(using animator: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        customPresentationController?.interactiveTransition
    }
}

// MARK: - Animator

/// モーダルを開くアニメーションを担当するクラス
final class SlideInAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    /// アニメーション継続時間
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }

    /// アニメーションの実行
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to),
              let toView = transitionContext.view(forKey: .to) else {
            return
        }

        // 最終的なビューの座標
        let finalFrame = transitionContext.finalFrame(for: toVC)
        // 初期位置は画面下に隠れるように配置
        toView.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
        transitionContext.containerView.addSubview(toView)

        // アニメーションが必要かどうかをチェック
        if transitionContext.isAnimated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0,
                animations: {
                    toView.frame = finalFrame
                },
                completion: { _ in
                    // 遷移がキャンセルされていた場合に後片付けをする
                    if transitionContext.transitionWasCancelled {
                        toView.removeFromSuperview()
                    }
                    // アニメーションの完了をUIKitに伝える
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        } else {
            toView.frame = finalFrame
        }
    }
}

/// モーダルを閉じるアニメーションを担当するクラス
final class SlideOutAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from) else {
            return
        }

        let initialFrame = fromView.frame
        // 画面下に隠れる位置
        let finalFrame = initialFrame.offsetBy(dx: 0, dy: initialFrame.height)

        if transitionContext.isAnimated {
            if transitionContext.isInteractive {
                // ドラッグで閉じる場合はアニメーションをlinearにすることで、手の動きに自然に追従するようにする
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: .curveLinear,
                    animations: {
                        fromView.frame = finalFrame
                    },
                    completion: { _ in
                        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                    }
                )
            } else {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 1,
                    initialSpringVelocity: 0,
                    animations: {
                        fromView.frame = finalFrame
                    },
                    completion: { _ in
                        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                    }
                )
            }
        } else {
            fromView.frame = finalFrame
        }
    }
}

// MARK: - Presentation Controller

final class CustomPresentationController: UIPresentationController {
    /// アニメーション完了時の背景色
    private let backgroundColor: UIColor
    /// 色をつける背景のビュー。最終的にステータスバー領域だけが見えるようになる。
    private let backgroundView = UIView(frame: .zero)
    /// 表示される画面の中身を配置するビュー。presentedViewになる。
    private let sheetView = SheetView(frame: .zero)

    /// ドラッグで閉じるためのジェスチャー
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
    /// ドラッグで閉じるための InteractiveTransition
    private(set) var interactiveTransition: UIPercentDrivenInteractiveTransition?

    /// 初期化
    /// - Parameters:
    ///   - presentedViewController: モーダルとして表示されるViewController
    ///   - presentingViewController: 表示元のViewController
    ///   - backgroundColor: アニメーション完了時の背景色
    init(presentedViewController: UIViewController,
         presenting presentingViewController: UIViewController?,
         backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    override var presentedView: UIView? {
        sheetView
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        // 色をつける背景のビューを配置
        backgroundView.frame = container.bounds
        container.insertSubview(backgroundView, at: 0)
        backgroundView.backgroundColor = .clear
        // 遷移先のビューをSheetViewの上に配置
        sheetView.addSubview(presentedViewController.view)
        // Auto Layoutを使うと、表示した画面の上に modalPresentationStyle = .fullScreen で別画面を表示し、
        // それを閉じたときに、元の画面の幅が0になって表示されなくなる問題があったため、autoresizingMaskにしている。
        presentedViewController.view.frame = sheetView.bounds
        presentedViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // ドラッグで閉じるためのジェスチャーを追加
        presentedViewController.view.addGestureRecognizer(panGestureRecognizer)
        // 画面を開くのに応じて背景に色をつける
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.backgroundView.backgroundColor = self.backgroundColor
        }, completion: nil)
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        // 表示がキャンセルされた場合
        if !completed {
            backgroundView.removeFromSuperview()
        }
    }

    override func dismissalTransitionWillBegin() {
        // 画面が閉じるのに応じて背景の色を透明に戻す
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.backgroundView.backgroundColor = .clear
        }, completion: nil)
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        // dismissが完了した場合
        if completed {
            backgroundView.removeFromSuperview()
        }
    }

    /// containerViewの中に配置する表示すべき画面のframe
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        // 上部 safe area の分、高さを減らして下にずらす
        return CGRect(
            x: 0,
            y: containerView.safeAreaInsets.top,
            width: containerView.bounds.width,
            height: containerView.bounds.height - containerView.safeAreaInsets.top
        )
    }

    /// ドラッグジェスチャーのハンドラー
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let container = containerView else { return }
        let translation = gesture.translation(in: container)
        let velocity = gesture.velocity(in: container)
        // 0〜1の範囲で進行度合いを算出
        let progress = min(max(translation.y / sheetView.frame.height, 0), 1)

        switch gesture.state {
        case .possible:
            break
        case .began:
            // InteractiveTransitionのインスタンスを作成してdismissを開始
            interactiveTransition = UIPercentDrivenInteractiveTransition()
            presentingViewController.dismiss(animated: true)
        case .changed:
            // 進行状態を更新
            interactiveTransition?.update(progress)
        case .ended:
            if velocity.y > 500 || progress > 0.3 {
                // 速度または移動距離の閾値を超えたら完了させる
                interactiveTransition?.finish()
            } else {
                // それ以外は画面遷移をキャンセル
                interactiveTransition?.cancel()
            }
            interactiveTransition = nil
        case .cancelled, .failed:
            interactiveTransition?.cancel()
            interactiveTransition = nil
        @unknown default:
            interactiveTransition?.cancel()
            interactiveTransition = nil
        }
    }
}

/// 表示先のビューを上に乗せる、上部が角丸のビュー
final class SheetView: UIView {
    /// コンテンツ切り抜き用のマスクレイヤー
    private let contentMaskLayer: CAShapeLayer = .init()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.masksToBounds = true
        layer.mask = contentMaskLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 上だけ角丸に切り抜く
        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 24, height: 24)
        )
        contentMaskLayer.path = path.cgPath
    }
}
