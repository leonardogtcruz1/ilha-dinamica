import AppKit
import Foundation

struct NotchGeometry: Equatable {
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let topInset: CGFloat
    let screenFrame: CGRect
    let notchCenterX: CGFloat

    static func current() -> NotchGeometry {
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? screens.first

        guard let screen = targetScreen else {
            return NotchGeometry(
                hasNotch: false,
                notchWidth: 126,
                notchHeight: 32,
                topInset: 8,
                screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                notchCenterX: 735
            )
        }

        let frame = screen.frame
        let safeTop = screen.safeAreaInsets.top
        let hasNotch = safeTop > 0

        let notchWidth: CGFloat
        let notchCenterX: CGFloat

        if hasNotch {
            if let leftAux = screen.auxiliaryTopLeftArea,
               let rightAux = screen.auxiliaryTopRightArea,
               leftAux.width > 0,
               rightAux.width > 0 {
                let rawWidth = frame.width - leftAux.width - rightAux.width
                notchWidth = min(max(rawWidth, 170), 240)
                notchCenterX = (leftAux.maxX + rightAux.minX) / 2.0
            } else {
                notchWidth = 190
                notchCenterX = frame.midX
            }
        } else {
            notchWidth = 126
            notchCenterX = frame.midX
        }

        let notchHeight = hasNotch ? max(safeTop, 32) : 32
        let topInset: CGFloat = hasNotch ? 0 : 8

        return NotchGeometry(
            hasNotch: hasNotch,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            topInset: topInset,
            screenFrame: frame,
            notchCenterX: notchCenterX
        )
    }
}
