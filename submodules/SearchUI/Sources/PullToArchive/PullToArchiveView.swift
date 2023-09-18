import UIKit
import Lottie
import Display
import AppBundle
import AsyncDisplayKit
import AvatarNode

public final class PullToArchiveView: BaseView {
    
    public var cellHeight: CGFloat = 77.0
    public var topConstant: CGFloat = 0 {
        didSet {
            frame.origin.y = topConstant
        }
    }
    public var beginRefreshing: (() -> Void)?
    public private(set) var isTouching = false
    public private(set) var isRefreshing = false {
        didSet {
            PullToArchiveSettings.isRefreshing = isRefreshing
        }
    }
    public var height: CGFloat = 0 {
        didSet {
            onChangeHeight()
        }
    }
    
    private var safeAreaLeftInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.left ?? 0
    }
    
    private var targetRadius: CGFloat = 0

    private var isDraggingEndedInReleaseState = false {
        didSet {
            PullToArchiveSettings.isDraggingEndedInReleaseState = isDraggingEndedInReleaseState
        }
    }
    private(set) var isReleaseState = false {
        didSet {
            animateKnobView()
            print("isReleaseState \(isReleaseState)")
        }
    }

    private let grayStarColor = UIColor(rgb: 0xB3B7BE).cgColor
    private let grayEndColor = UIColor(rgb: 0xE1E1E5).cgColor
    private let grayColor = UIColor(rgb: 0xB2B2B2)
    private let blueStarColor = UIColor(rgb: 0x2a9ef1)
    
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator()
    
    // 26 * 2 - 26 * 3 / 2, или 26 * 0.5
    private let knobSize: CGFloat = 20
    private var xKnob: CGFloat {
        knobSize * 1.5 + safeAreaLeftInset
    }
    private lazy var minimumRadius = knobSize / 2
    private var middleRadius: CGFloat {
        PullToArchiveSettings.avatarDiameter * 0.5 * PullToArchiveSettings.avatarScale
    }
    
    private var maximumRadius: CGFloat = 0
    private let inset: CGFloat = 8
    private var tick: CGFloat = 0
    private var wasCalledBeginRefreshing = false
    
    private let knobBackgroundView = BaseView()
    private let circleBackgroundKnobView = CircleBackgroundKnobView()
    private let knobView = KnobView()
    private let animationView = AnimationView()
    private let swipeDownForArchiveLabel = UILabel()
    private let releaseForArchiveLabel = UILabel()
    private lazy var gradientLayer = CAGradientLayer()
    private let hapticFeedback = HapticFeedback()
    private var archiveAvatarNode: ASDisplayNode? = nil
    private var areLabelsConfigured = false
    
    private var onArchivedChatsDidAppear: (() -> Void)?
    
    public override func setup() {
        super.setup()
        
        selectionGenerator.prepare()
        impactGenerator.prepare()
        
        layer.masksToBounds = true
        backgroundColor = .clear
        
        isUserInteractionEnabled = false
        
        layer.addSublayer(gradientLayer)
        setupGradientLayer()
        
        addSubview(circleBackgroundKnobView)
        circleBackgroundKnobView.radius = 0
        
        addSubview(knobBackgroundView)
        knobBackgroundView.backgroundColor = .white.withAlphaComponent(0.5)
        knobBackgroundView.layer.cornerRadius = minimumRadius

        setupAnimationView()
        
        setupLabels()
        
        addSubview(knobView)
        knobView.backgroundColor = .white
        knobView.lineColor = grayColor.cgColor
        knobView.layer.cornerRadius = minimumRadius
        
        height = 0

        PullToArchiveSettings.addObserver(self)
    }
    
    private func setupLabels() {
        
        swipeDownForArchiveLabel.text = "Swipe down for archive"
        swipeDownForArchiveLabel.font = .boldSystemFont(ofSize: 16.0)
        swipeDownForArchiveLabel.textColor = .white
        swipeDownForArchiveLabel.sizeToFit()
        addSubview(swipeDownForArchiveLabel)

        releaseForArchiveLabel.text = "Release for archive"
        releaseForArchiveLabel.font = .boldSystemFont(ofSize: 16.0)
        releaseForArchiveLabel.textColor = .white
        releaseForArchiveLabel.layer.opacity = 0.0
        releaseForArchiveLabel.sizeToFit()
        addSubview(releaseForArchiveLabel)
    }
    
    private func setupAnimationView() {
        
        if let url = getAppBundle().url(forResource: "archive", withExtension: "json"), let maybeAnimation = Animation.filepath(url.path) {
            animationView.animation = maybeAnimation
        }
        animationView.alpha = 0
        animationView.frame = CGRect(origin: .zero, size: CGSize(width: PullToArchiveSettings.avatarDiameter, height: PullToArchiveSettings.avatarDiameter))
        addSubview(animationView)

        let keypath = AnimationKeypath(keys: ["**", "Stroke 1", "**", "Color"])
        /// Lottie dosent understand clear color
        let colorProvider = ColorValueProvider(UIColor(rgb: 0x53BCF8).lottieColorValue)
        animationView.setValueProvider(colorProvider, keypath: keypath)

        let keypathFill = AnimationKeypath(keys: ["**", "Fill 1", "**", "Color"])
        let colorProviderFill = ColorValueProvider(UIColor.white.lottieColorValue)
        animationView.setValueProvider(colorProviderFill, keypath: keypathFill)
    }

    private func animateLabels(duration: Double = 0.42) {
        if isRefreshing {
            return
        }

        let damping: CGFloat = 100
        let toCenterX = frame.size.width / 2
        
        if isReleaseState {
            
            swipeDownForArchiveLabel.layer.animateSpring(from: swipeDownForArchiveLabel.layer.currentXPosition as NSNumber, to: frame.size.width + swipeDownForArchiveLabel.frame.size.width / 2 as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)
            
            releaseForArchiveLabel.layer.animateAlpha(from: releaseForArchiveLabel.layer.currentOpacity, to: 1.0, duration: 0.1, removeOnCompletion: false)
            
            releaseForArchiveLabel.layer.animateSpring(from: releaseForArchiveLabel.layer.currentXPosition as NSNumber, to: toCenterX as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)

        } else {
            
            releaseForArchiveLabel.layer.animateAlpha(from: releaseForArchiveLabel.layer.currentOpacity, to: 0, duration: 0.1, removeOnCompletion: false)
            
            releaseForArchiveLabel.layer.animateSpring(from: releaseForArchiveLabel.layer.currentXPosition as NSNumber, to: -releaseForArchiveLabel.frame.size.width / 2 as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)
            
            swipeDownForArchiveLabel.layer.animateSpring(from: swipeDownForArchiveLabel.layer.currentXPosition as NSNumber, to: toCenterX as NSNumber, keyPath: "position.x", duration: duration, damping: damping, removeOnCompletion: false)
        }
    }
    
    private func hapticFeedbackByReleaseState() {
        if isTouching {
            if isReleaseState {
                hapticFeedback.tap()
            } else {
                hapticFeedback.impact(.veryLight)
            }
        }
    }
    
    private func animateKnobView() {
        if !isRefreshing {
            knobView.layer.rotate(to: isReleaseState ? .up : .down, duration: 0.42, damping: 100.0)
            knobView.layer.strokeColor(to: isReleaseState ? blueStarColor.cgColor : grayColor.cgColor, duration: 0.3)
        }
    }

    private func animateToRadius(_ radius: CGFloat, withBounce: Bool, completion: (() -> Void)? = nil) {
        circleBackgroundKnobView.animationDuration = 0.3
        circleBackgroundKnobView.damping = 104.0
        circleBackgroundKnobView.initialVelocity = 0.0
        
        if withBounce {
            circleBackgroundKnobView.animationDuration = 1.0
            circleBackgroundKnobView.damping = 115.0
            circleBackgroundKnobView.initialVelocity = 10.0
        }

        print("==================")
        print("animate to radius: \(radius); last radius \(circleBackgroundKnobView.lastRenderedRadius)")

        if circleBackgroundKnobView.lastRenderedRadius == radius {
            let hasCompletion = completion != nil
            print("hasCompletion \(hasCompletion)")
            completion?()
            return
        }

        circleBackgroundKnobView.targetRadius = radius
        circleBackgroundKnobView.radius = radius
        circleBackgroundKnobView.completion = completion
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        maximumRadius = bounds.size.width

        if !areLabelsConfigured && frame.size.width > 0 {
            areLabelsConfigured = true
            setLabelsPosition()
        }
    }
    
    private func setLabelsPosition() {
        swipeDownForArchiveLabel.layer.removeAllAnimations()
        releaseForArchiveLabel.layer.removeAllAnimations()
        swipeDownForArchiveLabel.layer.position.x = frame.size.width / 2
        releaseForArchiveLabel.layer.position.x = -releaseForArchiveLabel.frame.size.width / 2
    }
    
    public func willBeginDragging() {
        if isRefreshing {
            return
        }
        
        isDraggingEndedInReleaseState = false
        isRefreshing = false
        isTouching = true
        isReleaseState = false
        wasCalledBeginRefreshing = false
        animationView.stop()
        tick = 0
        height = 0
        
        targetRadius = 0
        circleBackgroundKnobView.radius = 0
        circleBackgroundKnobView.targetRadius = 0

        CATransaction.disableAnimations {
            self.gradientLayer.isHidden = false
            self.gradientLayer.removeAllAnimations()
            self.animationView.alpha = 0
            self.animationView.layer.removeAllAnimations()
            self.knobView.alpha = 1.0
            self.knobView.layer.removeAllAnimations()
            self.circleBackgroundKnobView.alpha = 1.0
            self.circleBackgroundKnobView.setupGradientLayer(isHorizontal: true)
            self.knobBackgroundView.layer.removeAllAnimations()
            self.knobBackgroundView.alpha = 1.0
            self.setLabelsPosition()
        }
    }
    
    public func willEndDragging() {
        if isRefreshing {
            return
        }
        
        isTouching = false
        
        guard isReleaseState else {
            return
        }
        
        isRefreshing = true
        isDraggingEndedInReleaseState = true
        
        onArchivedChatsDidAppear = startArchivedChatsAnimation
    }
      
    private func startArchivedChatsAnimation() {
        
        tick = 1
        impactGenerator.impactOccurred()
        
        let isWholeReleaseGradientVisible = circleBackgroundKnobView.lastRenderedRadius >= maximumRadius

        knobView.alpha = 0.0
        animationView.alpha = 1.0
        
        let finishAnimation = { [weak self] in
            guard let self else {
                return
            }
            
            self.animationView.alpha = 0.0
            self.circleBackgroundKnobView.alpha = 0
            self.knobBackgroundView.alpha = 0
            self.knobView.alpha = 0

            self.isReleaseState = false
            self.isRefreshing = false

            PullToArchiveSettings.isScrollingUnderPullToArchive = false
            self.height = 0
        }
        
        animateToRadius(middleRadius, withBounce: true) { [weak self] in
            guard let self else {
                return
            }
            
            if PullToArchiveSettings.avatarScale < 1.0 {
                UIView.animate(withDuration: 0.3) {
                    self.archiveAvatarNode?.alpha = 1.0
                } completion: { _ in
                    finishAnimation()
                }
            } else {
                self.archiveAvatarNode?.alpha = 1.0
                finishAnimation()
            }
        }
        
        releaseForArchiveLabel.layer.animateAlpha(from: releaseForArchiveLabel.layer.currentOpacity, to: 0.0, duration: 0.1, removeOnCompletion: false)
        knobBackgroundView.layer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
        circleBackgroundKnobView.setupGradientLayer(isHorizontal: false)

        if isWholeReleaseGradientVisible {
            gradientLayer.isHidden = true
        } else {
            gradientLayer.animateAlpha(from: 1, to: 0, duration: 0.25, removeOnCompletion: false)
        }
        
        if PullToArchiveSettings.avatarScale < 1.0 {
            animationView.layer.animateScale(from: 1.0, to: PullToArchiveSettings.avatarScale, duration: 0.5, removeOnCompletion: false)
        }
        animationView.play(toProgress: 1, loopMode: .playOnce)
    }
    
    private func setupGradientLayer() {
        
        gradientLayer.colors = [grayStarColor, grayEndColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
    
    private func onChangeHeight() {

        var height = self.height
        var frameHeight = self.height // значение высоты фрейма, не меньше чем высота ячейки
        
        if isRefreshing {
            PullToArchiveSettings.isScrollingUnderPullToArchive = height > cellHeight
        } else if height <= 0 {
            PullToArchiveSettings.isScrollingUnderPullToArchive = false
        }
        
        if isReleaseState && !isRefreshing && isTouching {
            CATransaction.disableAnimations {
                print("==========")
                let radius = sqrt(pow(height, 2) + pow(self.maximumRadius, 2))
                self.circleBackgroundKnobView.targetRadius = radius
                self.circleBackgroundKnobView.radius = radius
                print("Set static radius: \(radius)")
                print("==========")
            }
        }
        if isRefreshing && height <= cellHeight && !wasCalledBeginRefreshing {
            wasCalledBeginRefreshing = true
            beginRefreshing?()
        }
        
        if isRefreshing {
            let targetHeight = (cellHeight - PullToArchiveSettings.avatarDiameter) / 2 + inset + cellHeight / 2
            if height < targetHeight {
                height = targetHeight
            }
            
            if frameHeight < cellHeight {
                frameHeight = cellHeight
            }
        }
        
        CATransaction.disableAnimations {
            let width = superview?.frame.size.width ?? 0
            frame = CGRect(origin: CGPoint(x: 0, y: topConstant), size: CGSize(width: width, height: frameHeight))
            gradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: width, height: frameHeight))
        }
        
        var knobBackgroundViewHeight = max(height - 2 * inset, knobSize)
        if isRefreshing {
            knobBackgroundViewHeight -= 10 * tick
            knobBackgroundViewHeight = max(knobBackgroundViewHeight, knobSize)
            print("knobBackgroundViewHeight \(knobBackgroundViewHeight), knobSize \(knobSize)")
            tick += 1 + tick * 0.1
        }
        
        let knobBackgroundViewY = isRefreshing ? (frameHeight - knobBackgroundViewHeight) / 2 : height - knobBackgroundViewHeight - inset
        knobBackgroundView.frame = CGRect(origin: CGPoint(x: xKnob, y: knobBackgroundViewY),
                                          size: CGSize(width: knobSize, height: knobBackgroundViewHeight))
        knobView.frame = CGRect(origin: CGPoint(x: xKnob, y: height - knobSize - inset),
                                size: CGSize(width: knobSize, height: knobSize))

        var y = knobBackgroundViewY + knobBackgroundViewHeight - knobSize / 2
        if isRefreshing {
            let deltaHeight = frameHeight - cellHeight
            let minY = deltaHeight + cellHeight / 2
            if y < minY {
                y = minY
            }
        }
        let position = CGPoint(x: knobView.layer.position.x, y: y)
        animationView.layer.position = position
        circleBackgroundKnobView.layer.position = position
        
        swipeDownForArchiveLabel.layer.position.y = position.y
        releaseForArchiveLabel.layer.position.y = position.y
        
        if !isRefreshing && isTouching {
            let isReleaseState = height >= cellHeight
            if isReleaseState != self.isReleaseState {
                
                self.isReleaseState = isReleaseState

                animateLabels()

                hapticFeedbackByReleaseState()

                targetRadius = isReleaseState ? maximumRadius : minimumRadius
                animateToRadius(targetRadius, withBounce: false)

                print("isReleaseState to \(isReleaseState)")
                print("targetRadius to \(targetRadius)")
            }
        }
    }
    

}

extension PullToArchiveView: PullToArchiveObserverProtocol {

     public func archivedChatsHidden(_ isHidden: Bool, node: ASDisplayNode) {

         if let onArchivedChatsDidAppear,
            !isHidden && isRefreshing {
             archiveAvatarNode = findArchiveAvatarNode(in: node)
             archiveAvatarNode?.alpha = 0.0
             
             onArchivedChatsDidAppear()
             self.onArchivedChatsDidAppear = nil
         }
         
         if isHidden {
             circleBackgroundKnobView.alpha = 0.0
             animationView.alpha = 0
         }
    }
    
    public func orientationChanged() {
        
        /*if PullToArchiveSettings.isScrollingUnderPullToArchive {
            willEndDragging()
            willBeginDragging()
        }*/
    }

    private func findArchiveAvatarNode(in node: ASDisplayNode) -> ASDisplayNode? {
        
        if node.frame.size.width == PullToArchiveSettings.avatarDiameter &&
            node.frame.size.height == PullToArchiveSettings.avatarDiameter {
            return node
        }
        
        if let subnodes = node.subnodes {
            for subnode in subnodes {
                if let foundNode = findArchiveAvatarNode(in: subnode) {
                    return foundNode
                }
            }
        }
        
        return nil
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
            @NSManaged var startPoint: CGPoint
            @NSManaged var endPoint: CGPoint
            @NSManaged var colors: [Any]?

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
                    self.startPoint = layer.startPoint
                    self.endPoint = layer.endPoint
                    self.colors = layer.colors
                }
            }

            override class func isAnimationKeySupported(_ key: String) -> Bool {
                key == #keyPath(radius) || key == #keyPath(startPoint) || key == #keyPath(endPoint)
                || key == #keyPath(colors)
            }
        }

        var targetRadius: CGFloat = 0.0

        var radius: CGFloat = 0.0 {
            didSet {
                animatableLayer.radius = radius
            }
        }
        
        var completion: (() -> Void)?
        
        var lastRenderedRadius: CGFloat {
            animatableLayer.presentation()?.radius ?? animatableLayer.radius
        }
        
        var startPoint: CGPoint = CGPoint(x: 0.0, y: 0.5) {
            didSet {
                animatableLayer.startPoint = startPoint
            }
        }

        var endPoint: CGPoint = CGPoint(x: 1, y: 0.5) {
            didSet {
                animatableLayer.endPoint = endPoint
            }
        }

        lazy var colors: [Any]? = nil {
            didSet {
                animatableLayer.colors = colors
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
        
        var initialVelocity: CGFloat = 0.0 {
            didSet {
                animatableLayer.internalinitialVelocity = initialVelocity
            }
        }
        
        private let blueStarColor = UIColor(rgb: 0x2a9ef1).cgColor
        private let blueEndColor = UIColor(rgb: 0x72d5fd).cgColor

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

            layer.addSublayer(gradientLayer)
            gradientLayer.type = .axial
            gradientLayer.colors = [blueStarColor, blueEndColor]
            
            setupGradientLayer(isHorizontal: true)

            maskLayer.fillColor = UIColor.black.cgColor
            render(radius: 0.0)
        }
                
        public override func display(_ layer: CALayer) {
            guard let presentationLayer = layer.presentation() as? AnimatableLayer else {
                return
            }
            
            print("Rendered radius: \(presentationLayer.radius), targetRadius: \(targetRadius)")
            
            setFrame(by: presentationLayer.radius)
            render(radius: presentationLayer.radius)
            gradientLayer.startPoint = presentationLayer.startPoint
            gradientLayer.endPoint = presentationLayer.endPoint
            gradientLayer.colors = presentationLayer.colors
            
            if targetRadius == presentationLayer.radius {
                completion?()
                completion = nil
            }
        }
        
        private func setFrame(by radius: CGFloat) {
            CATransaction.disableAnimations {
                let position = self.layer.position
                let size = 2 * radius
                let origin = CGPoint(x: position.x - size / 2.0, y: position.y - size / 2.0)
                self.frame = CGRect(origin: origin, size: .square(size))
                gradientLayer.frame = self.bounds
            }
        }
        
        private func render(radius: CGFloat) {
            
            let path = makePath(radius: radius)
            maskLayer.path = path.cgPath
            gradientLayer.mask = maskLayer
        }
        
        func setupGradientLayer(isHorizontal: Bool) {
            
            if isHorizontal {
                colors = [blueStarColor, blueStarColor, blueEndColor]
                startPoint = CGPoint(x: 0.0, y: 0.5)
                endPoint = CGPoint(x: 1, y: 0.5)
            } else {
                colors = [blueStarColor, blueEndColor]
                startPoint = CGPoint(x: 0.5, y: 1.0)
                endPoint = CGPoint(x: 0.5, y: 0.0)
            }
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
