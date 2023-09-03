import UIKit
import Display

open class BaseAnimatableLayer: CALayer {
    
    var animationDuration: CGFloat {
        0.5
    }

    var initialVelocity: CGFloat {
        0.0
    }

    var damping: CGFloat {
        88.0
    }

    override init(layer: Any) {
        super.init(layer: layer)

        setup(from: layer)
    }
    
    override init() {
        super.init()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override class func needsDisplay(forKey key: String) -> Bool {
        if isAnimationKeySupported(key) {
            return true
        }
        return super.needsDisplay(forKey: key)
    }

    open override func action(forKey event: String) -> CAAction? {
        if Self.isAnimationKeySupported(event) {
            
            let animation = makeSpringBounceAnimation(event, initialVelocity, damping)

            if let presentation = presentation() {
                animation.fromValue = presentation.value(forKeyPath: event)
                animation.duration = animationDuration
            }

            return animation
        }
        return super.action(forKey: event)
    }
    
    class func isAnimationKeySupported(_ key: String) -> Bool {
        false
    }
    
    func setup(from layer: Any) {
        
    }
}
