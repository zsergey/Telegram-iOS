import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import LegacyComponents
import AccountContext
import MergeLists

private let itemSize = CGSize(width: 88.0, height: 88.0)
private let inset: CGFloat = 12.0


private struct WallpaperPatternEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    let selected: Bool
    
    var stableId: Int64 {
        if case let .file(file) = self.wallpaper {
            return file.id
        } else {
            return Int64(self.index)
        }
    }
    
    static func ==(lhs: WallpaperPatternEntry, rhs: WallpaperPatternEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        return true
    }
    
    static func <(lhs: WallpaperPatternEntry, rhs: WallpaperPatternEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, action: @escaping (TelegramWallpaper) -> Void) -> ListViewItem {
        return WallpaperPatternItem(context: context, wallpaper: self.wallpaper, selected: self.selected, action: action)
    }
}

private class WallpaperPatternItem: ListViewItem {
    let context: AccountContext
    let wallpaper: TelegramWallpaper
    let selected: Bool
    let action: (TelegramWallpaper) -> Void
    
    public init(context: AccountContext, wallpaper: TelegramWallpaper, selected: Bool, action: @escaping (TelegramWallpaper) -> Void) {
        self.context = context
        self.wallpaper = wallpaper
        self.selected = selected
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WallpaperPatternItemNode()
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is WallpaperPatternItemNode)
            if let nodeValue = node() as? WallpaperPatternItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(self.wallpaper)
    }
}

private final class WallpaperPatternItemNode : ListViewItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    
    var item: WallpaperPatternItem?

    init() {
        self.wallpaperNode = SettingsThemeWallpaperNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)

        self.addSubnode(self.wallpaperNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (WallpaperPatternItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let currentItem = self.item

        return { [weak self] item, params in
            var updatedWallpaper = false
            var updatedSelected = false
            
            if currentItem?.wallpaper != item.wallpaper {
                updatedWallpaper = true
            }
            if currentItem?.selected != item.selected {
                updatedSelected = true
            }
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 112.0, height: 112.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.wallpaperNode.frame = CGRect(x: 0.0, y: 12.0, width: itemSize.width, height: itemSize.height)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

final class WallpaperPatternPanelNode: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    
    private let backgroundNode: NavigationBackgroundNode
    private let topSeparatorNode: ASDisplayNode
    
    let scrollNode: ASScrollNode
    
    private let titleNode: ImmediateTextNode
    private let labelNode: ImmediateTextNode
    private var sliderView: TGPhotoEditorSliderView?
    
    private var disposable: Disposable?
    var wallpapers: [TelegramWallpaper] = []
    private var currentWallpaper: TelegramWallpaper?
    
    var serviceBackgroundColor: UIColor = UIColor(rgb: 0x748698) {
        didSet {
            guard let nodes = self.scrollNode.subnodes else {
                return
            }
            for case let node as SettingsThemeWallpaperNode in nodes {
                node.setOverlayBackgroundColor(self.serviceBackgroundColor.withAlphaComponent(0.4))
            }
        }
    }
    
    var backgroundColors: ([UInt32], Int32?)? = nil {
        didSet {
            if oldValue?.0 != self.backgroundColors?.0 || oldValue?.1 != self.backgroundColors?.1 {
                self.updateWallpapers()
            }
        }
    }
    
    private var validLayout: CGSize?
    
    var patternChanged: ((TelegramWallpaper?, Int32?, Bool) -> Void)?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        
        self.backgroundNode = NavigationBackgroundNode(color: theme.chat.inputPanel.panelBackgroundColor)
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
     
        self.scrollNode = ASScrollNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.attributedText = NSAttributedString(string: strings.WallpaperPreview_PatternTitle, font: Font.bold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
    
        self.labelNode = ImmediateTextNode()
        self.labelNode.attributedText = NSAttributedString(string: strings.WallpaperPreview_PatternIntensity, font: Font.regular(14.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        
        super.init()
        
        self.allowsGroupOpacity = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.scrollNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        
        self.disposable = ((telegramWallpapers(postbox: context.account.postbox, network: context.account.network)
        |> map { wallpapers in
            return wallpapers.filter { wallpaper in
                if case let .file(file) = wallpaper, wallpaper.isPattern, file.file.mimeType != "image/webp" {
                    return true
                } else {
                    return false
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] wallpapers in
            if let strongSelf = self {
                strongSelf.wallpapers = wallpapers
                strongSelf.updateWallpapers()
            }
        }))
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.alwaysBounceHorizontal = true
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 2.0
        sliderView.minimumValue = 0.0
        sliderView.startValue = 0.0
        sliderView.maximumValue = 200.0
        sliderView.value = 150.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.backgroundColor = .clear
        sliderView.backColor = self.theme.list.disclosureArrowColor
        sliderView.trackColor = self.theme.list.itemAccentColor
        
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
    }
    
    func updateWallpapers() {
        guard let subnodes = self.scrollNode.subnodes else {
            return
        }
        
        for node in subnodes {
            node.removeFromSupernode()
        }
          
        let backgroundColors = self.backgroundColors ?? ([0xd6e2ee], nil)
        
        var selectedFileId: Int64?
        if let currentWallpaper = self.currentWallpaper, case let .file(file) = currentWallpaper {
            selectedFileId = file.id
        }
        
        for wallpaper in self.wallpapers {
            let node = SettingsThemeWallpaperNode(overlayBackgroundColor: self.serviceBackgroundColor.withAlphaComponent(0.4))
            node.clipsToBounds = true
            node.cornerRadius = 5.0
            
            var updatedWallpaper = wallpaper
            if case let .file(file) = updatedWallpaper {
                let settings = WallpaperSettings(colors: backgroundColors.0, intensity: 100, rotation: backgroundColors.1)
                updatedWallpaper = .file(id: file.id, accessHash: file.accessHash, isCreator: file.isCreator, isDefault: file.isDefault, isPattern: updatedWallpaper.isPattern, isDark: file.isDark, slug: file.slug, file: file.file, settings: settings)
            }
            
            var selected = false
            if case let .file(file) = wallpaper, file.id == selectedFileId {
                selected = true
            }
            
            node.setWallpaper(context: self.context, wallpaper: updatedWallpaper, selected: selected, size: itemSize)
            node.pressed = { [weak self, weak node] in
                if let strongSelf = self {
                    strongSelf.currentWallpaper = updatedWallpaper
                    if let sliderView = strongSelf.sliderView {
                        strongSelf.patternChanged?(updatedWallpaper, Int32(sliderView.value - 100.0), false)
                    }
                    if let subnodes = strongSelf.scrollNode.subnodes {
                        for case let subnode as SettingsThemeWallpaperNode in subnodes {
                            let selected = node === subnode
                            subnode.setSelected(selected, animated: true)
                            if selected {
                                strongSelf.scrollToNode(subnode, animated: true)
                            }
                        }
                    }
                }
            }
            self.scrollNode.addSubnode(node)
        }
        
        self.scrollNode.view.contentSize = CGSize(width: (itemSize.width + inset) * CGFloat(wallpapers.count) + inset, height: 112.0)
        self.layoutItemNodes(transition: .immediate)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.color = self.theme.chat.inputPanel.panelBackgroundColor
        self.topSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
            
        self.sliderView?.backColor = self.theme.list.disclosureArrowColor
        self.sliderView?.trackColor = self.theme.list.itemAccentColor
        self.titleNode.attributedText = NSAttributedString(string: self.labelNode.attributedText?.string ?? "", font: Font.bold(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
        self.labelNode.attributedText = NSAttributedString(string: self.labelNode.attributedText?.string ?? "", font: Font.regular(14.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        
        if let wallpaper = self.currentWallpaper {
            self.patternChanged?(wallpaper, Int32(sliderView.value - 100.0), sliderView.isTracking)
        }
    }
    
    func didAppear(initialWallpaper: TelegramWallpaper? = nil, intensity: Int32? = nil) {
        var wallpaper = initialWallpaper ?? self.wallpapers.first
        
        if let wallpaper = wallpaper {
            var selectedFileId: Int64?
            if case let .file(file) = wallpaper {
                selectedFileId = file.id
            }
            
            self.currentWallpaper = wallpaper
            self.sliderView?.value = CGFloat(intensity.flatMap { $0 + 100 } ?? 150)
            
            self.scrollNode.view.contentOffset = CGPoint()
            
            var selectedNode: SettingsThemeWallpaperNode?
            if let subnodes = self.scrollNode.subnodes {
                for case let subnode as SettingsThemeWallpaperNode in subnodes {
                    var selected = false
                    if case let .file(file) = subnode.wallpaper, file.id == selectedFileId {
                        selected = true
                        selectedNode = subnode
                    }
                    subnode.setSelected(selected, animated: false)
                }
            }
                        
            if initialWallpaper == nil, let wallpaper = self.currentWallpaper, let sliderView = self.sliderView {
                self.patternChanged?(wallpaper, Int32(sliderView.value - 100.0), false)
            }
            
            if let selectedNode = selectedNode {
                self.scrollToNode(selectedNode)
            }
        }
    }
    
    private func scrollToNode(_ node: SettingsThemeWallpaperNode, animated: Bool = false) {
        let bounds = self.scrollNode.view.bounds
        let frame = node.frame.insetBy(dx: -48.0, dy: 0.0)
        
        if frame.minX < bounds.minX || frame.maxX > bounds.maxX {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
            
            var origin = CGPoint()
            if frame.minX < bounds.minX {
                origin.x = max(0.0, frame.minX)
            } else if frame.maxX > bounds.maxX {
                origin.x = min(self.scrollNode.view.contentSize.width - bounds.width, frame.maxX - bounds.width)
            }
            
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: origin, size: self.scrollNode.frame.size))
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: UIScreenPixel))
        
        let titleSize = self.titleNode.updateLayout(self.bounds.size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((self.bounds.width - titleSize.width) / 2.0), y: 19.0), size: titleSize))
        
        let scrollViewFrame = CGRect(x: 0.0, y: 52.0, width: size.width, height: 114.0)
        transition.updateFrame(node: self.scrollNode, frame: scrollViewFrame)
        
        let labelSize = self.labelNode.updateLayout(self.bounds.size)
        var combinedHeight = labelSize.height + 34.0
        
        var originY: CGFloat = scrollViewFrame.maxY + floor((size.height - scrollViewFrame.maxY - combinedHeight) / 2.0)
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: 14.0, y: originY), size: labelSize))
        
        self.sliderView?.frame = CGRect(origin: CGPoint(x: 15.0, y: originY + 8.0), size: CGSize(width: size.width - 15.0 * 2.0, height: 44.0))
        
        self.layoutItemNodes(transition: transition)
    }
    
    private func layoutItemNodes(transition: ContainedViewLayoutTransition) {
        var offset: CGFloat = 12.0
        if let subnodes = self.scrollNode.subnodes {
            for node in subnodes {
                transition.updateFrame(node: node, frame: CGRect(x: offset, y: 12.0, width: itemSize.width, height: itemSize.height))
                offset += inset + itemSize.width
            }
        }
    }
}
