import UIKit

public class BaseView: UIView {

    public override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    open func setup() {
        
        translatesAutoresizingMaskIntoConstraints = false
    }
}
