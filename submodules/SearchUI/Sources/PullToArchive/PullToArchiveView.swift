import UIKit
import Lottie
import Display
import AppBundle

public final class PullToArchiveView: BaseView {
    
    public var cellHeight: CGFloat = 104.0
    public var topConstant: CGFloat = 0
    public var height: CGFloat = 0 {
        didSet {
            onChangeHeight()
        }
    }
    public var animationDidFinish: (() -> Void)?
    public private(set) var isRefreshing = false
    public private(set) var isTouching = false

    private let grayStarColor = UIColor(rgb: 0xB3B7BE).cgColor
    private let grayEndColor = UIColor(rgb: 0xE1E1E5).cgColor
    private let grayColor = UIColor(rgb: 0xB2B2B2)
    private let blueColor = UIColor(rgb: 0x3C86F6)
    
    private let knobSize: CGFloat = 20
    private lazy var xKnob = knobSize * 1.5
    private lazy var minimumRadius = knobSize / 2
    private lazy var middleRadius: CGFloat = 25.0
    private var maximumRadius: CGFloat = 0
    private let inset: CGFloat = 8
    private var knobBackgroundView = BaseView()
    private var circleBackgroundKnobView = CircleBackgroundKnobView()
    private var knobView = KnobView()
    private let animationView = AnimationView()
    private var isAnimatingWithBounce = false
    
    private lazy var gradientLayer = CAGradientLayer()

    private lazy var swipeDownForArchiveLabel = UILabel()
    private lazy var releaseForArchiveLabel = UILabel()

    private var tick: CGFloat = 0
        
    private var isDraggingEndedInReleaseState = false {
        didSet {
            GlobalPullToArchiveState.shared.isDraggingEndedInReleaseState = isDraggingEndedInReleaseState
        }
    }

    private var isReleaseState = false {
        didSet {

            animateKnobView()
            animateToTargetRadius()
            animateLabels()
        }
    }

    public override func setup() {
        super.setup()
        
        layer.masksToBounds = true
        backgroundColor = .clear
        
        setupGradientLayer()
        
        addSubview(circleBackgroundKnobView)
        circleBackgroundKnobView.radius = 0
        
        addSubview(knobBackgroundView)
        knobBackgroundView.backgroundColor = .white.withAlphaComponent(0.3)
        knobBackgroundView.layer.cornerRadius = minimumRadius
        
        setupAnimationView()

        setupLabels()

        addSubview(knobView)
        knobView.backgroundColor = .white
        knobView.lineColor = grayColor.cgColor
        knobView.layer.cornerRadius = minimumRadius
        
        height = 0
    }
    
    private func setupLabels() {
        
        swipeDownForArchiveLabel.text = "Swipe down for archive"
        swipeDownForArchiveLabel.font = .boldSystemFont(ofSize: 19.0)
        swipeDownForArchiveLabel.textColor = .white
        swipeDownForArchiveLabel.sizeToFit()
        swipeDownForArchiveLabel.layer.position.x = frame.size.width / 2
        addSubview(swipeDownForArchiveLabel)

        releaseForArchiveLabel.text = "Release for archive"
        releaseForArchiveLabel.font = .boldSystemFont(ofSize: 19.0)
        releaseForArchiveLabel.textColor = .white
        releaseForArchiveLabel.layer.opacity = 0.0
        releaseForArchiveLabel.sizeToFit()
        releaseForArchiveLabel.layer.position.x = -releaseForArchiveLabel.frame.size.width / 2
        addSubview(releaseForArchiveLabel)
    }

    private func setupAnimationView() {
        
        if let url = getAppBundle().url(forResource: "archive", withExtension: "json"), let maybeAnimation = Animation.filepath(url.path) {
            animationView.animation = maybeAnimation
        }
        
        animationView.alpha = 0
        let size = 2 * middleRadius // 60
        animationView.frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        addSubview(animationView)

        let keypath = AnimationKeypath(keys: ["**", "Stroke 1", "**", "Color"])
        let colorProvider = ColorValueProvider(blueColor.lottieColorValue)
        animationView.setValueProvider(colorProvider, keypath: keypath)

        let keypathFill = AnimationKeypath(keys: ["**", "Fill 1", "**", "Color"])
        let colorProviderFill = ColorValueProvider(UIColor.white.lottieColorValue)
        animationView.setValueProvider(colorProviderFill, keypath: keypathFill)
    }

    private func animateLabels(duration: Double = 0.42) {
        if isRefreshing {
            return
        }

        if isReleaseState {
            
            animateLabelsToSecondStage(duration: duration)

        } else {
            
            animateLabelsToFirstStage(duration: duration)
        }
    }
    
    private func animateLabelsToSecondStage(duration: Double = 0.42) {

        let damping: CGFloat = 100
        let toCenterX = frame.size.width / 2

        swipeDownForArchiveLabel.layer.animateSpring(from: swipeDownForArchiveLabel.layer.currentXPosition as NSNumber, to: frame.size.width + swipeDownForArchiveLabel.frame.size.width / 2 as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)
        
        releaseForArchiveLabel.layer.animateAlpha(from: releaseForArchiveLabel.layer.currentOpacity, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
        releaseForArchiveLabel.layer.animateSpring(from: releaseForArchiveLabel.layer.currentXPosition as NSNumber, to: toCenterX as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)

    }
    
    private func animateLabelsToFirstStage(duration: Double = 0.42) {
        
        let damping: CGFloat = 100
        let toCenterX = frame.size.width / 2

        releaseForArchiveLabel.layer.animateAlpha(from: releaseForArchiveLabel.layer.currentOpacity, to: 0, duration: 0.1, removeOnCompletion: false)
        
        releaseForArchiveLabel.layer.animateSpring(from: releaseForArchiveLabel.layer.currentXPosition as NSNumber, to: -releaseForArchiveLabel.frame.size.width / 2 as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)
        
        swipeDownForArchiveLabel.layer.animateSpring(from: swipeDownForArchiveLabel.layer.currentXPosition as NSNumber, to: toCenterX as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)
    }
    
    private func animateKnobView() {
        if !isRefreshing {
            knobView.layer.rotate(to: isReleaseState ? .up : .down, duration: 0.42, damping: 100.0)
            knobView.layer.strokeColor(to: isReleaseState ? blueColor.cgColor : grayColor.cgColor, duration: 0.3)
        }
    }
    
    private func animateToTargetRadius() {
        circleBackgroundKnobView.animationDuration = 0.3
        circleBackgroundKnobView.damping = 104.0
        circleBackgroundKnobView.initialVelocity = 0.0
        
        var toRadius = minimumRadius
        if isAnimatingWithBounce {
            circleBackgroundKnobView.animationDuration = 1.0
            circleBackgroundKnobView.damping = 110.0
            circleBackgroundKnobView.initialVelocity = 10.0
            toRadius = middleRadius
        }
        circleBackgroundKnobView.radius = isReleaseState ? maximumRadius : toRadius
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        maximumRadius = bounds.size.width

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = layer.bounds
        CATransaction.commit()
        
    }
    
    public func willBeginDragging() {
        gradientLayer.isHidden = false
        isAnimatingWithBounce = false
        isRefreshing = false
        isReleaseState = false
        isTouching = true
        isDraggingEndedInReleaseState = false
        animationView.stop()
        tick = 0
        height = 0
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        knobView.alpha = 1.0
        animationView.alpha = 0
        circleBackgroundKnobView.alpha = 1.0
        knobView.layer.removeAllAnimations()
        knobBackgroundView.layer.removeAllAnimations()
        knobBackgroundView.alpha = 1.0
        swipeDownForArchiveLabel.layer.position.x = frame.size.width / 2
        releaseForArchiveLabel.layer.position.x = -releaseForArchiveLabel.frame.size.width / 2
        CATransaction.commit()
        
        DispatchQueue.main.async {
            self.circleBackgroundKnobView.radius = 0
        }
    }
    
    public func didEndDragging() {
        
        GlobalPullToArchiveState.shared.scrollView?.isUserInteractionEnabled = false
        
        gradientLayer.isHidden = isReleaseState
        isAnimatingWithBounce = isReleaseState
        isTouching = false
        
        // Duration of the lottie animation is 1 sec.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            GlobalPullToArchiveState.shared.scrollView?.isUserInteractionEnabled = true
        })

        guard isReleaseState else {
            return
        }
        
        isDraggingEndedInReleaseState = true

        releaseForArchiveLabel.layer.animateAlpha(from: releaseForArchiveLabel.layer.currentOpacity, to: 0.0, duration: 0.1, removeOnCompletion: false)

        knobBackgroundView.layer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
        
        isRefreshing = true
        tick = 1
        
        knobView.alpha = 0.0
        animationView.alpha = 1.0

        playAnimation { [weak self] in
            
            self?.animationView.alpha = 0.0
            self?.circleBackgroundKnobView.alpha = 0
            self?.knobBackgroundView.alpha = 0
            self?.knobView.alpha = 0
            GlobalPullToArchiveState.shared.scrollView?.isUserInteractionEnabled = true
            
            self?.isRefreshing = false


            self?.animationDidFinish?()
        }
    }
    
    private func setupGradientLayer() {
        
        layer.addSublayer(gradientLayer)
        
        gradientLayer.colors = [grayStarColor, grayEndColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
    
    private func onChangeHeight() {

        var height = self.height
        var frameHeight = self.height
        
        if height <= 0 {
            swipeDownForArchiveLabel.layer.position.x = frame.size.width / 2
            releaseForArchiveLabel.layer.position.x = -releaseForArchiveLabel.frame.size.width / 2
        }
        
        if isRefreshing {
            let targetHeight = (cellHeight - 2 * middleRadius) / 2 + inset + cellHeight / 2
            if height < targetHeight {
                height = targetHeight
            }
            if frameHeight < cellHeight {
                frameHeight = cellHeight
            }
        }
        
        let width = superview?.frame.size.width ?? 0
        frame = CGRect(origin: CGPoint(x: 0, y: topConstant),
                       size: CGSize(width: width, height: frameHeight))
        
        var knobBackgroundViewHeight = max(height - 2 * inset, knobSize)
        if isRefreshing {
            knobBackgroundViewHeight -= 12 * tick
            knobBackgroundViewHeight = max(knobBackgroundViewHeight, knobSize)
            
            tick += 1 - tick * 0.2
        }

        let knobBackgroundViewY = isRefreshing ? (frameHeight - knobBackgroundViewHeight) / 2 : height - knobBackgroundViewHeight - inset
              knobBackgroundView.frame = CGRect(origin: CGPoint(x: xKnob, y: knobBackgroundViewY),
                                                size: CGSize(width: knobSize, height: knobBackgroundViewHeight))

        knobView.frame = CGRect(origin: CGPoint(x: xKnob, y: height - knobSize - inset),
                                size: CGSize(width: knobSize, height: knobSize))

        circleBackgroundKnobView.frame = CGRect(origin: .zero,
                                                size: CGSize(width: 2 * maximumRadius, height: 2 * maximumRadius))
        circleBackgroundKnobView.layer.position = knobView.layer.position
        circleBackgroundKnobView.syncLayers()
        
        if isRefreshing {
            circleBackgroundKnobView.layer.position = CGPoint(x: knobView.layer.position.x, y: frameHeight / 2)
        }
        animationView.layer.position = CGPoint(x: knobView.layer.position.x, y: knobBackgroundViewY + knobBackgroundViewHeight - knobSize / 2)

        let labelY = self.height - swipeDownForArchiveLabel.frame.size.height / 2 - inset
        swipeDownForArchiveLabel.layer.position.y = labelY
        releaseForArchiveLabel.layer.position.y = labelY
        
        let isReleaseState = height >= cellHeight
        if isReleaseState != self.isReleaseState {
            self.isReleaseState = isReleaseState

            if isTouching {
                if isReleaseState {
                    HapticFeedback().tap()
                } else {
                    HapticFeedback().impact(.veryLight)
                }
            }
        }
    }
    
    private func playAnimation(completion: (() -> Void)?) {
        animationView.play(toProgress: 1, loopMode: .playOnce) { _ in
            completion?()
        }
    }
}

extension PullToArchiveView {
        
    public final class KnobView: BaseView {
        
        var lineColor: CGColor = UIColor.white.cgColor {
            didSet {
                shapeLayer.strokeColor = lineColor
            }
        }
        
        private var lineWidth: CGFloat = 2
        
        private var shapeLayer: CAShapeLayer {
            layer as! CAShapeLayer
        }
        
        public override class var layerClass: AnyClass {
            CAShapeLayer.self
        }
        
        public override func setup() {
            super.setup()
            
            setupShapeLayer()
        }
        
        public override func layoutSubviews() {
            super.layoutSubviews()
            
            shapeLayer.path = makeArrowModel().path.cgPath
        }
        
        private func setupShapeLayer() {
            shapeLayer.lineWidth = lineWidth
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = UIColor.white.cgColor
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
        }
        
        private func makeArrowModel() -> ShapeModel {
            let radius = bounds.height / 2
            let startY = radius + 4.5
            
            let firstLine = LineModel(startPoint: CGPoint(x: radius - 4.5, y: radius),
                                      endPoint: CGPoint(x: radius, y: startY))
            
            let secondLine = LineModel(startPoint: CGPoint(x: radius, y: startY),
                                       endPoint: CGPoint(x: radius + 4.5, y: radius))
            
            let thirdLine = LineModel(startPoint: CGPoint(x: radius, y: startY - 1),
                                      endPoint: CGPoint(x: radius, y: startY - 9))
            
            return ShapeModel(firstLine: firstLine, secondLine: secondLine, thirdLine: thirdLine)
        }
    }
    
    public final class CircleBackgroundKnobView: BaseView {
        
        private class AnimatableLayer: BaseAnimatableLayer {

            @NSManaged var radius: CGFloat
            
            var internalAnimationDuration: CGFloat = 0.5
            var internalDamping: CGFloat = 88.0
            var internalinitialVelocity: CGFloat = 0.0

            override var animationDuration: CGFloat {
                internalAnimationDuration
            }
            
            override var damping: CGFloat {
                internalDamping
            }
            
            override var initialVelocity: CGFloat {
                internalinitialVelocity
            }

            override func setup(from layer: Any) {
                if let layer = layer as? AnimatableLayer {
                    self.radius = layer.radius
                }
            }

            override class func isAnimationKeySupported(_ key: String) -> Bool {
                key == #keyPath(radius)
            }
        }

        var radius: CGFloat = 0.0 {
            didSet {
                animatableLayer.radius = radius
            }
        }
        
        var animationDuration: CGFloat = 0.5 {
            didSet {
                animatableLayer.internalAnimationDuration = animationDuration
            }
        }
        
        var damping: CGFloat = 88.0 {
            didSet {
                animatableLayer.internalDamping = damping
            }
        }
        
        var initialVelocity: CGFloat = 88.0 {
            didSet {
                animatableLayer.internalinitialVelocity = initialVelocity
            }
        }

        private let blueStarColor = UIColor(rgb: 0x3D86EB).cgColor
        private let blueEndColor = UIColor(rgb: 0x87C2F9).cgColor

        private let gradientLayer = CAGradientLayer()
        
        private var animatableLayer: AnimatableLayer {
            layer as! AnimatableLayer
        }
        
        private let maskLayer = CAShapeLayer()
        
        public override class var layerClass: AnyClass {
            AnimatableLayer.self
        }
        
        public override func setup() {
            super.setup()
            setupGradientLayer()
        }
        
        public func syncLayers() {
            
            gradientLayer.frame = layer.bounds
        }
        
        public override func display(_ layer: CALayer) {
            guard let presentationLayer = layer.presentation() as? AnimatableLayer else {
                return
            }
            
            render(radius: presentationLayer.radius)
        }
        
        private func render(radius: CGFloat) {
            
            let path = makePath(radius: radius)
            maskLayer.path = path.cgPath
            gradientLayer.mask = maskLayer
        }
        
        private func setupGradientLayer() {

            gradientLayer.colors = [blueStarColor, blueStarColor, blueEndColor]
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            layer.addSublayer(gradientLayer)
            
            maskLayer.fillColor = UIColor.black.cgColor

            render(radius: 0.0)
        }
        
        private func makePath(radius: CGFloat) -> UIBezierPath {
            let centerX = bounds.midX
            let centerY = bounds.midY
            let path = UIBezierPath()
            path.addArc(withCenter: CGPoint(x: centerX, y: centerY),
                        radius: radius,
                        startAngle: 0.radians,
                        endAngle: 360.radians,
                        clockwise: true)
            return path
        }
    }
}
