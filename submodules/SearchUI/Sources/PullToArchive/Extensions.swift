import UIKit
import Display

extension CGFloat {
    
    var radians: CGFloat {
        CGFloat.pi * self / 180.0
    }
}

extension Int {
    
    var radians: CGFloat {
        CGFloat(self).radians
    }
}

extension CALayer {
    
    public enum UpDownDirection {
        case up
        case down
    }

    public func rotate(to direction: UpDownDirection, duration: CFTimeInterval, damping: CGFloat) {
        
        let keyPath = "transform.rotation.z"
        let currentRotation = value(forKeyPath: "presentationLayer." + keyPath) as? Double ?? Double.pi
        
        let fromValue: Double
        let toValue: Double
        
        if direction == .down {
            fromValue = -1.0 * abs(currentRotation)
            toValue = 0
        } else {
            fromValue = currentRotation
            toValue = -Double.pi
        }

        animateSpring(from: fromValue as NSNumber, to: toValue as NSNumber, keyPath: keyPath, duration: duration, initialVelocity: 0.0, damping: damping, removeOnCompletion: false, additive: true)
    }

    func strokeColor(to toValue: CGColor, duration: CFTimeInterval) {
        
        let keyPath = "strokeColor"
        let animation = CABasicAnimation(keyPath: keyPath)
        let currentStrokeColor = value(forKeyPath: "presentationLayer." + keyPath)
        animation.fromValue = currentStrokeColor
        animation.toValue = toValue
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        add(animation, forKey: keyPath)
    }
    
    var currentXPosition: CGFloat {
        presentation()?.position.x ?? position.x
    }
    
    var currentOpacity: CGFloat {
        CGFloat(presentation()?.opacity ?? opacity)
    }
}
