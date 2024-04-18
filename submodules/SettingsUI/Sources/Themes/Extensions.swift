import Foundation
import UIKit

extension UIView {
    
    static func deactivate(constraints: [NSLayoutConstraint]) {
        NSLayoutConstraint.deactivate(constraints)
    }
    
    static func activate(constraints: [NSLayoutConstraint]) {
        constraints.forEach { ($0.firstItem as? UIView)?.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate(constraints)
    }
    
    @discardableResult
    func pin(to view: UIView, insets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        let anchors = [
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left),
            rightAnchor.constraint(equalTo: view.rightAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
        ]
        UIView.activate(constraints: anchors)
        return anchors
    }
    
    @discardableResult
    func center(in view: UIView) -> [NSLayoutConstraint] {
        let anchors = [
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        UIView.activate(constraints: anchors)
        return anchors
    }

    @discardableResult
    func centerX(in view: UIView) -> [NSLayoutConstraint] {
        let anchors = [
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ]
        UIView.activate(constraints: anchors)
        return anchors
    }

    @discardableResult
    func centerY(in view: UIView) -> [NSLayoutConstraint] {
        let anchors = [
            centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ]
        UIView.activate(constraints: anchors)
        return anchors
    }

    @discardableResult
    func vertical(in view: UIView) -> NSLayoutConstraint {
        let anchor = centerXAnchor.constraint(equalTo: view.centerXAnchor)
        UIView.activate(constraints: [anchor])
        return anchor
    }
    
    @discardableResult
    func left(to view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = leftAnchor.constraint(equalTo: view.leftAnchor, constant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func left(toRight view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = leftAnchor.constraint(equalTo: view.rightAnchor, constant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func right(to view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = rightAnchor.constraint(equalTo: view.rightAnchor, constant: -constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func top(to view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = topAnchor.constraint(equalTo: view.topAnchor, constant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func top(toSafeArea view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func bottom(toSafeArea view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func bottom(to view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func top(toBottom view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = topAnchor.constraint(equalTo: view.bottomAnchor, constant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func bottom(toTop view: UIView, constant: CGFloat = 0) -> NSLayoutConstraint {
        let anchor = bottomAnchor.constraint(equalTo: view.topAnchor, constant: -constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func height(_ constant: CGFloat) -> NSLayoutConstraint {
        let anchor = heightAnchor.constraint(equalToConstant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func width(_ constant: CGFloat) -> NSLayoutConstraint {
        let anchor = widthAnchor.constraint(equalToConstant: constant)
        UIView.activate(constraints: [anchor])
        return anchor
    }

    @discardableResult
    func size(_ size: CGSize) -> [NSLayoutConstraint] {
        let anchors = [
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height)
        ]
        UIView.activate(constraints: anchors)
        return anchors
    }
}

extension UISpringTimingParameters {
    
    /// A design-friendly way to create a spring timing curve.
    ///
    /// - Parameters:
    ///   - damping: The 'bounciness' of the animation. Value must be between 0 and 1.
    ///   - response: The 'speed' of the animation.
    ///   - initialVelocity: The vector describing the starting motion of the property. Optional, default is `.zero`.
    public convenience init(damping: CGFloat, response: CGFloat, initialVelocity: CGVector = .zero) {
        let stiffness = pow(2 * .pi / response, 2)
        let damp = 4 * .pi * damping / response
        self.init(mass: 1, stiffness: stiffness, damping: damp, initialVelocity: initialVelocity)
    }
    
}

public extension CALayer {
    
    /// Значение `frame` презентационного слоя.
    var presentationFrame: CGRect {
        presentation()?.frame ?? frame
    }
}
