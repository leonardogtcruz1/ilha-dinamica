#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="IlhaDinamica"
FINAL_BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
STAGE_DIR="$(mktemp -d)"
TMP_ICON_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR" "$TMP_ICON_DIR"' EXIT

BUNDLE_DIR="$STAGE_DIR/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Compilando $APP_NAME (release)..."
swift build -c release

echo "Montando bundle em $BUNDLE_DIR..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ROOT_DIR/dist"

cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt_BR</string>
    <key>CFBundleDisplayName</key>
    <string>Ilha Dinâmica</string>
    <key>CFBundleExecutable</key>
    <string>IlhaDinamica</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.leonardo.ilhadinamica</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Ilha Dinâmica</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>A Ilha Dinâmica precisa de permissão para exibir e controlar músicas do Spotify e do Apple Music.</string>
    <key>NSCameraUsageDescription</key>
    <string>A Ilha Dinâmica usa a câmera apenas quando você abre o espelho rápido na ilha.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>A Ilha Dinâmica exibe seus próximos compromissos e links de reunião.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>A Ilha Dinâmica exibe seus próximos compromissos e links de reunião.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>A Ilha Dinâmica pode incluir áudio do microfone nas gravações de tela.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>A Ilha Dinâmica salva as gravações de tela na sua Mesa.</string>
</dict>
</plist>
EOF

ICONSET_DIR="$TMP_ICON_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

swift - "$ICONSET_DIR" << 'SWIFT'
import AppKit
import Foundation

let iconsetPath = CommandLine.arguments[1]
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func renderIcon(px: Int) -> Data? {
    let size = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: size * 0.22, yRadius: size * 0.22)

    let bgGradient = NSGradient(colors: [
        NSColor(srgbRed: 0.14, green: 0.16, blue: 0.24, alpha: 1.0),
        NSColor(srgbRed: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
    ])
    bgGradient?.draw(in: cardPath, angle: -90)

    NSColor(white: 1.0, alpha: 0.14).setStroke()
    cardPath.lineWidth = max(1.0, size * 0.012)
    cardPath.stroke()

    let pillW = size * 0.64
    let pillH = size * 0.24
    let pillRect = NSRect(
        x: (size - pillW) / 2.0,
        y: size * 0.44,
        width: pillW,
        height: pillH
    )
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2.0, yRadius: pillH / 2.0)
    NSColor.black.setFill()
    pillPath.fill()

    NSColor(white: 1.0, alpha: 0.22).setStroke()
    pillPath.lineWidth = max(0.8, size * 0.01)
    pillPath.stroke()

    // Album dot on left inside pill
    let dotSize = pillH * 0.56
    let dotRect = NSRect(
        x: pillRect.minX + pillH * 0.24,
        y: pillRect.minY + (pillH - dotSize) / 2.0,
        width: dotSize,
        height: dotSize
    )
    let dotPath = NSBezierPath(roundedRect: dotRect, xRadius: dotSize * 0.30, yRadius: dotSize * 0.30)
    let accentGradient = NSGradient(colors: [
        NSColor(srgbRed: 0.18, green: 0.88, blue: 0.48, alpha: 1.0),
        NSColor(srgbRed: 0.24, green: 0.68, blue: 1.0, alpha: 1.0)
    ])
    accentGradient?.draw(in: dotPath, angle: 45)

    // Audio equalizer bars on right inside pill
    let barHeights: [CGFloat] = [0.36, 0.58, 0.44, 0.28]
    let barW = max(1.0, pillW * 0.032)
    let barGap = max(1.0, pillW * 0.025)
    let startX = pillRect.maxX - pillH * 0.26 - CGFloat(barHeights.count) * barW - CGFloat(barHeights.count - 1) * barGap

    for (idx, hFactor) in barHeights.enumerated() {
        let barH = pillH * hFactor
        let barRect = NSRect(
            x: startX + CGFloat(idx) * (barW + barGap),
            y: pillRect.minY + (pillH - barH) / 2.0,
            width: barW,
            height: barH
        )
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: barW / 2.0, yRadius: barW / 2.0)
        NSColor(srgbRed: 0.22, green: 0.90, blue: 0.52, alpha: 1.0).setFill()
        barPath.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for (name, px) in sizes {
    if let data = renderIcon(px: px) {
        let outURL = URL(fileURLWithPath: iconsetPath).appendingPathComponent(name)
        try? data.write(to: outURL)
    }
}
SWIFT

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/Apple Development:|Developer ID Application:/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
    echo "Limpando atributos estendidos e assinando bundle (ad-hoc)..."
else
    echo "Limpando atributos estendidos e assinando bundle com: $SIGN_IDENTITY"
fi
xattr -cr "$BUNDLE_DIR"
codesign --force --deep --sign "$SIGN_IDENTITY" "$BUNDLE_DIR"
codesign --verify --deep --strict "$BUNDLE_DIR"

rm -rf "$FINAL_BUNDLE_DIR"
mv "$BUNDLE_DIR" "$FINAL_BUNDLE_DIR"
xattr -d com.apple.FinderInfo "$FINAL_BUNDLE_DIR" 2>/dev/null || true

echo "Pronto: $FINAL_BUNDLE_DIR"
