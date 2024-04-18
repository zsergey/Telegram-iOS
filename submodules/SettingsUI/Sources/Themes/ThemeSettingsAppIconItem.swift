import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AppBundle

private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor(theme.list.itemBlocksBackgroundColor.cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        context.fillEllipse(in: bounds)
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat
        if selected {
            var accentColor = theme.list.itemAccentColor
            if accentColor.rgb == 0xffffff {
                accentColor = UIColor(rgb: 0x999999)
            }
            context.setStrokeColor(accentColor.cgColor)
            lineWidth = 2.0
        } else {
            context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
            lineWidth = 1.0
        }
        
        if bordered || selected {
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
        }
    })?.stretchableImage(withLeftCapWidth: 15, topCapHeight: 15)
}

class ThemeSettingsAppIconItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let icons: [PresentationAppIcon]
    let isPremium: Bool
    let currentIconName: String?
    let updated: (PresentationAppIcon) -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, icons: [PresentationAppIcon], isPremium: Bool, currentIconName: String?, updated: @escaping (PresentationAppIcon) -> Void, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.strings = strings
        self.icons = icons
        self.isPremium = isPremium
        self.currentIconName = currentIconName
        self.updated = updated
        self.tag = tag
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsAppIconItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ThemeSettingsAppIconItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

private final class ThemeSettingsAppIconNode : ASDisplayNode {
    private let iconNode: ASImageNode
    private let overlayNode: ASImageNode
    private let lockNode: ASImageNode
    private let textNode: ImmediateTextNode
    private var action: (() -> Void)?
    
    private let activateAreaNode: AccessibilityAreaNode
    
    private var locked = false
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 62.0))
        self.iconNode.isLayerBacked = true
        
        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 62.0))
        self.overlayNode.isLayerBacked = true
        
        self.lockNode = ASImageNode()
        self.lockNode.contentMode = .scaleAspectFit
        self.lockNode.displaysAsynchronously = false
        self.lockNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.activateAreaNode = AccessibilityAreaNode()
        self.activateAreaNode.accessibilityTraits = [.button]
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.overlayNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.lockNode)
        self.addSubnode(self.activateAreaNode)
    }
    
    func setup(theme: PresentationTheme, icon: UIImage, title: NSAttributedString, locked: Bool, color: UIColor, bordered: Bool, selected: Bool, action: @escaping () -> Void) {
        self.locked = locked
        self.iconNode.image = icon
        self.textNode.attributedText = title
        self.overlayNode.image = generateBorderImage(theme: theme, bordered: bordered, selected: selected)
        self.lockNode.image = locked ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/TextLockIcon"), color: color) : nil
        self.action = {
            action()
        }
        
        self.activateAreaNode.accessibilityLabel = title.string
        if locked {
            self.activateAreaNode.accessibilityTraits = [.button, .notEnabled]
        } else {
            self.activateAreaNode.accessibilityTraits = [.button]
        }
        
        self.setNeedsLayout()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action?()
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.iconNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 14.0), size: CGSize(width: 62.0, height: 62.0))
        self.overlayNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 14.0), size: CGSize(width: 62.0, height: 62.0))
        
        let textSize = self.textNode.updateLayout(bounds.size)
        var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - textSize.width)) / 2.0, y: 87.0), size: textSize)
        if self.locked {
            textFrame = textFrame.offsetBy(dx: 5.0, dy: 0.0)
        }
        self.textNode.frame = textFrame
        
        self.lockNode.frame = CGRect(x: self.textNode.frame.minX - 10.0, y: 90.0, width: 6.0, height: 8.0)
        
        self.activateAreaNode.frame = self.bounds
    }
}


private let textFont = Font.regular(12.0)
private let selectedTextFont = Font.bold(12.0)

class ThemeSettingsAppIconItemNode: ListViewItemNode, ItemListItemNode {
    
    let cubeView = CubeView()
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let scrollNode: ASScrollNode
    private var nodes: [ThemeSettingsAppIconNode] = []
        
    private var item: ThemeSettingsAppIconItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.scrollNode = ASScrollNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
    }
    
    private func scrollToNode(_ node: ThemeSettingsAppIconNode, animated: Bool) {
        let bounds = self.scrollNode.view.bounds
        let frame = node.frame.insetBy(dx: -48.0, dy: 0.0)
        
        if frame.minX < bounds.minX || frame.maxX > bounds.maxX {
            self.scrollNode.view.scrollRectToVisible(frame, animated: animated)
        }
    }
    
    func asyncLayout() -> (_ item: ThemeSettingsAppIconItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let contentHeight: CGFloat = 160
            contentSize = CGSize(width: params.width, height: contentHeight)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.scrollNode.view.contentInset = UIEdgeInsets()
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 2.0), size: CGSize(width: layoutSize.width - params.leftInset - params.rightInset, height: layoutSize.height))
                    
                    if !(strongSelf.scrollNode.view.subviews.last is CubeView) {
                        
                        strongSelf.cubeView.translatesAutoresizingMaskIntoConstraints = false
                        strongSelf.cubeView.clipsToBounds = false

                        let pageWidth: CGFloat = contentHeight - 2 * 20
                        strongSelf.cubeView.pageWidth = pageWidth
                        strongSelf.cubeView.cubeDelegate = self
                        strongSelf.scrollNode.view.addSubview(strongSelf.cubeView)
                        strongSelf.cubeView.center(in: strongSelf.scrollNode.view)
                        strongSelf.cubeView.height(pageWidth)
                        strongSelf.cubeView.width(pageWidth)
                        
                        var appIconImageViews: [AppIconImageView] = []
                        var selectedAppIconImageView: AppIconImageView?
                        for icon in item.icons {
                            
                            if let image = UIImage(named: icon.imageName, in: getAppBundle(), compatibleWith: nil) {
                                
                                let appIconImageView = AppIconImageView()
                                appIconImageView.name = icon.imageName
                                appIconImageView.image = image
                                appIconImageView.frame = CGRect(origin: .zero, size: CGSize(width: pageWidth, height: pageWidth))
                                
                                let selected = icon.name == item.currentIconName
                                if selected {
                                    selectedAppIconImageView = appIconImageView
                                } else {
                                    appIconImageViews.append(appIconImageView)
                                }
                            }
                        }
                        if let selectedAppIconImageView {
                            appIconImageViews.insert(selectedAppIconImageView, at: 1)
                        }
                        strongSelf.cubeView.addChildViews(appIconImageViews)
                        
                        strongSelf.cubeView.showCubeTutorial()
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

extension ThemeSettingsAppIconItemNode: CubeViewDelegate {
    
    func cubeViewDidChangePage(_ cubeView: CubeView) {
        
        setApplicationIconNamed(cubeView.currentAppIconImageView.name)
    }
    
    func setApplicationIconNamed(_ iconName: String?, completion: (() -> Void)? = nil) {
        if UIApplication.shared.responds(to: #selector(getter: UIApplication.supportsAlternateIcons)) && UIApplication.shared.supportsAlternateIcons {
            
            typealias setAlternateIconName = @convention(c) (NSObject, Selector, NSString?, @escaping (NSError) -> ()) -> ()
            
            let selectorString = "_setAlternateIconName:completionHandler:"
            
            let selector = NSSelectorFromString(selectorString)
            let imp = UIApplication.shared.method(for: selector)
            let method = unsafeBitCast(imp, to: setAlternateIconName.self)
            method(UIApplication.shared, selector, iconName as NSString?, { _ in
                completion?()
            })
        }
    }
}
