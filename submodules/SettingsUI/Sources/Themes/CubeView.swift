import Foundation
import UIKit

@objc protocol CubeViewDelegate: AnyObject {
    
    func cubeViewDidChangePage(_ cubeView: CubeView)
    
}

class CubeView: UIScrollView, UIScrollViewDelegate {
    
    weak var cubeDelegate: CubeViewDelegate?
        
    var pageWidth: CGFloat = 100
    
    var currentPage = 0
    
    var isStretching = false {
        didSet {
            if isStretching {
                stopAnimations()
            }
        }
    }
    
    private let maxAngle: CGFloat = 90.0
    
    private var allAppIconImageViews = [AppIconImageView]()

    private var currentIndex = 0
    
    private var images = [UIImage?]()
    private var names = [String]()
    private var alternativeNames = [String]()
    
    private var isConfiguringCube = false
    
    private var animatorIn = UIViewPropertyAnimator()
    var animatorOut = UIViewPropertyAnimator()
    
    var exitCudeTutorial = false
    
    private let impactGenerator = UIImpactFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private enum TutorialState {
        case opened
        case closed
        case neutral
    }
    private var tutorialState: TutorialState = .neutral
    
    lazy var appIconImageViews: [AppIconImageView] = {
        [
            AppIconImageView(frame: .zero),
            AppIconImageView(frame: .zero),
            AppIconImageView(frame: .zero)
        ]
    }()
    
    var currentAppIconImageView: AppIconImageView {
        appIconImageViews[1]
    }
    
    private var stretchingAppIconImageView: AppIconImageView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configureScrollView()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureScrollView()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        layoutAppIconImageViews()
    }
    
    func removeAllChildViews() {
        
        allAppIconImageViews.forEach {
            $0.removeFromSuperview()
        }
        
        allAppIconImageViews = []
    }
    
    func addChildViews(_ views: [AppIconImageView]) {
        
        guard views.count >= 3 else {
            return
        }
        
        allAppIconImageViews = []
        for view in views {
            allAppIconImageViews.append(view)
        }
        
        (0..<3).forEach { index in
            let name = views[index].name
            let image = views[index].image
            let alternativeAppIconName = views[index].alternativeAppIconName
            
            images.append(image)
            names.append(name)
            alternativeNames.append(alternativeAppIconName)
            
            appIconImageViews[index].image = image
            appIconImageViews[index].name = name
            appIconImageViews[index].alternativeAppIconName = alternativeAppIconName
            
            addSubview(appIconImageViews[index])
        }
        
        isConfiguringCube = true
        contentSize = CGSize(width: 3 * pageWidth, height: pageWidth)
        contentOffset = CGPoint(x: pageWidth, y: 0)
        currentIndex = 1
        isConfiguringCube = false
        
        gestureRecognizers?.forEach { gesture in
            if gesture is UISwipeGestureRecognizer
                || gesture is UIPanGestureRecognizer {
                superview?.addGestureRecognizer(gesture)
            }
        }
    }

    func scrollToViewAtIndex(_ index: Int, animated: Bool) {
        if index > -1 && index < allAppIconImageViews.count {
            
            let width = frame.size.width
            let height = frame.size.height
            
            let frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: height)
            scrollRectToVisible(frame, animated: animated)
        }
    }
    
    // MARK: Scroll view delegate
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView,
                                         willDecelerate decelerate: Bool) {
        
        if !decelerate {
            scrollToNearestPage()
        }
    }
        
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        scrollToNearestPage()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        infinityScrollView(scrollView)
        
        transformViewsInScrollView(scrollView)
    }
    
    public func scrollToNearestPage(animated: Bool = true) {
        let xOffset = contentOffset.x
        let currentPage = Int(round(xOffset / pageWidth))
        scrollToViewAtIndex(currentPage, animated: animated)
    }
    
    // MARK: Private methods
    
    private func stopAnimations() {
        animatorIn.stopAnimation(true)
        animatorOut.stopAnimation(true)
    }

    private func configureScrollView() {
        
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bounces = true
        delegate = self
        impactGenerator.prepare()
        selectionGenerator.prepare()
        
        for numberOfTouchesRequired in 1...3 {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
            tapGesture.numberOfTouchesRequired = numberOfTouchesRequired
            addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        
        if currentAppIconImageView.radians == 0 {
            
            let point = gesture.location(in: self)
            animateTap(at: point)
            
        } else {

            scrollToNearestPage()
        }
    }

    func animateBoom() {
        
        isStretching = true
        
        stretchBoom { [weak self] in
            guard let self else {
                return
            }

            self.isStretching = false
            self.animateToFirstFrame()
        }
    }

    func showCubeTutorial() {
        
        tutorialState = .opened
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            
            if self.exitCudeTutorial {
                self.tutorialState = .neutral
                return
            }
            
            let contentOffsetX = self.pageWidth * 1.45
            self.setContentOffset(.init(x: contentOffsetX, y: 0), animated: true)
        }
    }
    
    private func animateTap(at point: CGPoint) {
        
        isStretching = true
        
        stretch(at: point) { [weak self] in
            guard let self else {
                return
            }

            self.isStretching = false
            self.animateToFirstFrame()
        }
    }
    
    private func animateToFirstFrame() {
        
        let response: CGFloat = 0.7
        let timingParameters = UISpringTimingParameters(damping: 0.5, response: response)
        let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
        animator.addAnimations { [weak self] in
            guard let self else {
                return
            }
            self.stretchingAppIconImageView?.frame.size = CGSize(width: self.pageWidth, height: self.pageWidth)
            self.stretchingAppIconImageView?.center = CGPoint(x: self.pageWidth, y: self.pageWidth / 2)
            self.superview?.layoutIfNeeded()
        }
        animator.startAnimation()
        self.animatorOut = animator
    }
    
    private func stretch(at point: CGPoint, completion: (() -> Void)?) {

        let parameters = stretch(at: point)
        let frame = currentAppIconImageView.layer.presentationFrame
        
        guard round(parameters.size.width) != round(frame.size.width) ||
                round(parameters.size.height) != round(frame.size.height) else {
            completion?()
            return
        }
    
        let animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeInOut)
        animator.addAnimations { [weak self] in
            guard let self else {
                return
            }
            self.currentAppIconImageView.frame.size = parameters.size
            self.currentAppIconImageView.center = parameters.center
            self.superview?.layoutIfNeeded()
        }
        animator.addCompletion { _ in
            completion?()
        }
        animator.startAnimation()
        animatorIn = animator
    }
    
    private func stretchBoom(completion: (() -> Void)?) {

        let parameters = stretchBoom()
        let frame = currentAppIconImageView.layer.presentationFrame
        
        guard round(parameters.size.width) != round(frame.size.width) ||
                round(parameters.size.height) != round(frame.size.height) else {
            completion?()
            return
        }
    
        let animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeInOut)
        animator.addAnimations { [weak self] in
            guard let self else {
                return
            }
            self.currentAppIconImageView.frame.size = parameters.size
            self.currentAppIconImageView.center = parameters.center
            self.superview?.layoutIfNeeded()
        }
        animator.addCompletion { _ in
            completion?()
        }
        animator.startAnimation()
        animatorIn = animator
    }
    
    private func stretch(at point: CGPoint) -> (size: CGSize, center: CGPoint) {
        
        stretchingAppIconImageView = currentAppIconImageView
        
        let center = CGPoint(x: pageWidth, y: pageWidth / 2)
        let x = (point.x - pageWidth - pageWidth / 2) / pageWidth
        let y = (point.y - pageWidth / 2) / pageWidth
        let isHorizontal = abs(x) > abs(y)

        let delta = pageWidth * 0.10
        var offset = isHorizontal ? delta * x / abs(x) : delta * y / abs(y)
        let minOffset = -pageWidth * 0.8
        let maxOffset = pageWidth * 0.8
        offset = min(max(minOffset, offset), maxOffset)
        let absoluteOffset = abs(offset)
        
        /// Увеличение как у Apple
        let square = pageWidth * pageWidth
        let width: CGFloat
        let height: CGFloat
        if isHorizontal {
            width = pageWidth + absoluteOffset
            height = square / width
        } else {
            height = pageWidth + absoluteOffset
            width = square / height
        }
        
        let deltaHeight = isHorizontal ? max(pageWidth - height, 0) : max(pageWidth - width, 0)
        
        let newSize = CGSize(width: width, height: height)
        let newCenter: CGPoint
        
        if offset > 0 {
            newCenter = isHorizontal ?
            CGPoint(x: center.x, y: center.y) :
            CGPoint(x: center.x + deltaHeight / 2, y: center.y + absoluteOffset / 2)
        } else {
            newCenter = isHorizontal ?
            CGPoint(x: center.x - absoluteOffset, y: center.y) :
            CGPoint(x: center.x + deltaHeight / 2, y: center.y - absoluteOffset / 2)
        }
        
        return (newSize, newCenter)
    }
    
    private func stretchBoom() -> (size: CGSize, center: CGPoint) {
        
        stretchingAppIconImageView = currentAppIconImageView
        let zoom: CGFloat = 0.05
        let center = CGPoint(x: pageWidth - (pageWidth * zoom) / 2, y: pageWidth / 2)
        let newSize = CGSize(width: pageWidth * (1 + zoom), height: pageWidth * (1 + zoom))

        return (newSize, center)
    }
    
    private func transformViewsInScrollView(_ scrollView: UIScrollView) {

        let xOffset = scrollView.contentOffset.x
        var degres = maxAngle / pageWidth * xOffset
        let currentPageFloat = xOffset / pageWidth
        let indexLeft = Int(round(currentPageFloat - 0.5))
        let indexRight = Int(round(currentPageFloat + 0.5))
        let currentPage = Int(round(xOffset / pageWidth))
                
        for index in 0..<appIconImageViews.count {
            
            let view = appIconImageViews[index]

            if index == indexLeft || index == indexRight || index == currentPage {
                view.alpha = 1
            } else {
                view.alpha = 0
            }
            
            degres = index == 0 ? degres : degres - maxAngle
            let radians = degres * CGFloat(Double.pi / 180)
            
            var transform = CATransform3DIdentity
            transform.m34 = 1 / 500
            transform = CATransform3DRotate(transform, radians, 0, 1, 0)
            
            view.layer.transform = CATransform3DIdentity
            view.layer.transform = transform
            
            let x = xOffset / pageWidth > CGFloat(index) ? 1.0 : 0.0
            let anchorPoint = CGPoint(x: x, y: 0.5)
            setAnchorPoint(anchorPoint, forView: view)
            
            view.radians = radians
            
            // Отключил тень
            // applyShadowForView(view, index: index)
        }
    }
    
    private func applyShadowForView(_ view: UIView, index: Int) {
        
        let w = self.frame.size.width
        let h = self.frame.size.height
        
        let r1 = frameFor(origin: contentOffset, size: self.frame.size)
        let r2 = frameFor(origin: CGPoint(x: CGFloat(index)*w, y: 0),
                          size: CGSize(width: w, height: h))
        
        // Only show shadow on right-hand side
        if r1.origin.x <= r2.origin.x {
            
            let intersection = r1.intersection(r2)
            let intArea = intersection.size.width*intersection.size.height
            let union = r1.union(r2)
            let unionArea = union.size.width*union.size.height
            
            view.layer.opacity = Float(intArea / unionArea)
        }
    }
    
    private func setAnchorPoint(_ anchorPoint: CGPoint, forView view: UIView) {
        
        var newPoint = CGPoint(x: view.bounds.size.width * anchorPoint.x, y: view.bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: view.bounds.size.width * view.layer.anchorPoint.x, y: view.bounds.size.height * view.layer.anchorPoint.y)
        
        newPoint = newPoint.applying(view.transform)
        oldPoint = oldPoint.applying(view.transform)
        
        var position = view.layer.position
        
        position.x -= oldPoint.x
        position.x += newPoint.x
        
        position.y -= oldPoint.y
        position.y += newPoint.y
        
        view.layer.position = position
        view.layer.anchorPoint = anchorPoint
    }
    
    private func frameFor(origin: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
}

// MARK: - Infinity Scroll

extension CubeView {

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
        if tutorialState == .opened {
            
            if self.exitCudeTutorial {
                tutorialState = .neutral
                return
            }
            
            tutorialState = .closed
            let contentOffsetX = self.pageWidth
            self.setContentOffset(.init(x: contentOffsetX, y: 0), animated: true)
            
            return
        }
        
        if currentAppIconImageView.radians == 0,
            tutorialState == .neutral {
            animateBoom()
            impactGenerator.impactOccurred()
        }
        
        tutorialState = .neutral
    }
    
    func layoutAppIconImageViews() {
        
        if isStretching {
            return
        }
        
        let size = CGSize(width: pageWidth, height: pageWidth)
        
        appIconImageViews.enumerated().forEach { (index: Int, appIconImageView: AppIconImageView) in

            appIconImageView.image = images[index]
            appIconImageView.name = names[index]
            appIconImageView.alternativeAppIconName = alternativeNames[index]

            let origin = CGPoint(x: pageWidth * CGFloat(index), y: 0)
            appIconImageView.frame = CGRect(origin: origin, size: size)
        }
    }
    
    func nextAppIconImageView() -> AppIconImageView {
        currentIndex += 1
        if currentIndex > allAppIconImageViews.count - 1 {
            currentIndex = 0
        }
        var index = currentIndex + 1
        if index > allAppIconImageViews.count - 1 {
            index = 0
        }
        return allAppIconImageViews[index]
    }
    
    func previousAppIconImageView() -> AppIconImageView {
        
        currentIndex -= 1
        if currentIndex < 0 {
            currentIndex = allAppIconImageViews.count - 1
        }
        var index = currentIndex - 1
        if index < 0 {
            index = allAppIconImageViews.count - 1
        }
        return allAppIconImageViews[index]
    }
    
    func infinityScrollView(_ scrollView: UIScrollView) {
        
        if isConfiguringCube {
            return
        }
        
        if scrollView.isTracking {
            exitCudeTutorial = true
        }
        
        stopAnimations()
        isStretching = false
        
        let offsetX = scrollView.contentOffset.x

        if offsetX > scrollView.frame.size.width * 1.5 {
            let newAppIconImageView = nextAppIconImageView()
            
            images.remove(at: 0)
            images.append(newAppIconImageView.image)
            
            names.remove(at: 0)
            names.append(newAppIconImageView.name)

            alternativeNames.remove(at: 0)
            alternativeNames.append(newAppIconImageView.alternativeAppIconName)

            layoutAppIconImageViews()
            contentOffset.x -= pageWidth
            
            selectionGenerator.selectionChanged()
            cubeDelegate?.cubeViewDidChangePage(self)
        }

        if offsetX < scrollView.frame.size.width * 0.5 {
            let newAppIconImageView = previousAppIconImageView()

            images.removeLast()
            images.insert(newAppIconImageView.image, at: 0)

            names.removeLast()
            names.insert(newAppIconImageView.name, at: 0)

            alternativeNames.removeLast()
            alternativeNames.insert(newAppIconImageView.alternativeAppIconName, at: 0)

            layoutAppIconImageViews()
            contentOffset.x += pageWidth

            selectionGenerator.selectionChanged()
            cubeDelegate?.cubeViewDidChangePage(self)
        }
    }
}

final class AppIconImageView: BaseView {
    
    var name = ""
    var alternativeAppIconName = ""
    var radians: CGFloat = 0
    
    var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }
        
    override var frame: CGRect {
        didSet {
            if radians == 0 {
                imageView.frame = CGRect(origin: .zero, size: frame.size)
            }
            setCornerRadius()
        }
    }
    
    private(set) var imageView = UIImageView()
    
    private func setCornerRadius() {
        let maxSide = max(bounds.size.width, bounds.size.height)
        let minSide = min(bounds.size.width, bounds.size.height)
        
        layer.cornerRadius = min(maxSide / 4.5, minSide / 2)
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
    }
    
    override func setup() {
        
        addSubview(imageView)
        imageView.pin(to: self)

        clipsToBounds = true
    }
}

class BaseView: UIView {
    
    private var oldBounds: CGRect = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
    
        if bounds != oldBounds {
            
            layoutSubviewsChangedBounds()
            oldBounds = bounds
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }
    
    open func setup() {
        translatesAutoresizingMaskIntoConstraints = false

    }
    
    open func layoutSubviewsChangedBounds() {
    }
   
}
