import AppKit
import SwiftUI

final class IslandPanel: NSPanel {
    static let canvasSize = CGSize(width: 660, height: 450)

    var allowsKeyFocus: Bool = false
    var isPointInsideIsland: ((CGPoint) -> Bool)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onPerformDrop: ((NSDraggingInfo) -> Bool)?

    init<Content: View>(rootView: Content, geometry: NotchGeometry) {
        let initialFrame = Self.panelFrame(for: geometry)
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = false
        becomesKeyOnlyIfNeeded = true
        canHide = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: 2006)
        collectionBehavior = [
            .stationary,
            .ignoresCycle
        ]
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        animationBehavior = .none

        let container = DropContainerView(frame: NSRect(origin: .zero, size: Self.canvasSize))
        container.autoresizingMask = [.width, .height]
        container.isPointInsideIsland = { [weak self] point in
            self?.isPointInsideIsland?(point) ?? false
        }
        container.onDragEntered = { [weak self] in self?.onDragEntered?() }
        container.onDragExited = { [weak self] in self?.onDragExited?() }
        container.onPerformDrop = { [weak self] info in self?.onPerformDrop?(info) ?? false }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(hostingView)

        contentView = container
    }

    override var canBecomeKey: Bool { allowsKeyFocus }
    override var canBecomeMain: Bool { false }

    func updateFrame(for geometry: NotchGeometry) {
        let target = Self.panelFrame(for: geometry)
        if frame != target {
            setFrame(target, display: true)
        }
    }

    static func panelFrame(for geometry: NotchGeometry) -> CGRect {
        let originX = round(geometry.notchCenterX - canvasSize.width / 2.0)
        let originY = geometry.screenFrame.maxY - canvasSize.height
        return CGRect(x: originX, y: originY, width: canvasSize.width, height: canvasSize.height)
    }
}

private final class DropContainerView: NSView {
    var isPointInsideIsland: ((CGPoint) -> Bool)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onPerformDrop: ((NSDraggingInfo) -> Bool)?

    private var cursorTrackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
            NSPasteboard.PasteboardType("com.apple.NSFilePromiseItemMetaData")
        ]
        types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        registerForDraggedTypes(types)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseEntered(with: event)
    }

    private var isMouseCurrentlyInsideIsland: Bool {
        isPointInsideIsland?(NSEvent.mouseLocation) ?? false
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource == nil, isMouseCurrentlyInsideIsland else { return [] }
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingSource == nil else { return [] }
        if isMouseCurrentlyInsideIsland {
            onDragEntered?()
            return .copy
        } else {
            onDragExited?()
            return []
        }
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDragExited?()
        guard sender.draggingSource == nil, isMouseCurrentlyInsideIsland else { return false }
        return onPerformDrop?(sender) ?? false
    }
}
