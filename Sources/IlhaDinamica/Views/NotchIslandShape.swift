import SwiftUI

struct NotchIslandShape: Shape {
    var hasNotch: Bool
    var topEarRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topEarRadius, bottomCornerRadius) }
        set {
            topEarRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 2, rect.height > 2 else { return Path() }

        if !hasNotch {
            let clamped = min(bottomCornerRadius, min(rect.width, rect.height) / 2.0)
            return RoundedRectangle(cornerRadius: clamped, style: .continuous).path(in: rect)
        }

        let ear = max(0, min(topEarRadius, rect.width * 0.14, rect.height * 0.42))
        let maxBottomR = max(0, min((rect.width - ear * 2.0) * 0.48, rect.height - ear))
        let r = max(0, min(bottomCornerRadius, maxBottomR))

        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let rightBodyX = rect.maxX - ear
        let leftBodyX = rect.minX + ear

        var path = Path()
        path.move(to: topLeft)
        path.addLine(to: topRight)

        if ear > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rightBodyX, y: rect.minY + ear),
                control: CGPoint(x: rightBodyX, y: rect.minY)
            )
        }

        path.addLine(to: CGPoint(x: rightBodyX, y: rect.maxY - r))

        if r > 0 {
            let k: CGFloat = 0.42
            path.addCurve(
                to: CGPoint(x: rightBodyX - r, y: rect.maxY),
                control1: CGPoint(x: rightBodyX, y: rect.maxY - r * k),
                control2: CGPoint(x: rightBodyX - r * k, y: rect.maxY)
            )
        }

        path.addLine(to: CGPoint(x: leftBodyX + r, y: rect.maxY))

        if r > 0 {
            let k: CGFloat = 0.42
            path.addCurve(
                to: CGPoint(x: leftBodyX, y: rect.maxY - r),
                control1: CGPoint(x: leftBodyX + r * k, y: rect.maxY),
                control2: CGPoint(x: leftBodyX, y: rect.maxY - r * k)
            )
        }

        path.addLine(to: CGPoint(x: leftBodyX, y: rect.minY + ear))

        if ear > 0 {
            path.addQuadCurve(
                to: topLeft,
                control: CGPoint(x: leftBodyX, y: rect.minY)
            )
        }

        path.closeSubpath()
        return path
    }
}
