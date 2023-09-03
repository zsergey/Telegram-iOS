import AsyncDisplayKit

public class PullToArchiveNode: ASDisplayNode {
    
    public var pullToArchiveView = PullToArchiveView()
    
    public override var view: UIView {
        pullToArchiveView
    }
}
