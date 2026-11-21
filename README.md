# Ilha Dinâmica

Native **Dynamic Island** for macOS built with **SwiftUI** and **AppKit**, seamlessly integrated with your MacBook notch.

> Every genuinely good Dynamic Island app for macOS was paid — so I built my own and open-sourced it.

[![Ilha Dinâmica Demo Preview](media/ilha-dinamica-preview.gif)](media/ilha-dinamica-demo-en.mp4)

<p align="center">
  <a href="media/ilha-dinamica-demo-en.mp4">▶ Watch full 1080p @ 60fps MP4 demo</a>
</p>

## Key Features

- **9 Customizable Layout Presets:** Switch in one click between **DynamicLake**, **Atoll**, **SuperIsland**, **Glass Studio**, **Aurora Pulse**, **Creator Deck**, **Central Pro**, **Zen Titanium**, and **Obsidian**.
- **3-Channel Color Engine:** Customize the island surface/border, buttons/tabs, and sliders/progress bars independently with live preview.
- **Interactive Volume & Brightness HUD:** Drag volume or brightness directly inside the notch popup HUD with your mouse, click to mute, or jump straight to the full Audio & Display tab.
- **Live Hardware Telemetry Popups:** Rich USB-C fast-charging card (real-time wattage, voltage, ETA, battery health, and cycles) plus Bluetooth & AirPods split battery popups.
- **Dynamic Music Player:** Spotify and Apple Music controls, adaptive artwork scaling, audio visualizer, scrub bar, and track change toasts.
- **Files Shelf & AirDrop:** Drag images, videos, or files directly into the notch with visual thumbnails and one-click AirDrop sharing.
- **Weather, Productivity & Utilities:** Expanded weather forecast, Pomodoro focus timer, Calendar events, Quick Notes & Tasks, Clipboard history, Camera Mirror, System Monitor (CPU, RAM, network), and ScreenCaptureKit screen recording.
- **Preferences:** Customizable widget order, extra utility tabs, hover delay, animation speed, and native system HUD replacement.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.10 or later (Xcode or Command Line Tools)

## Build & Run

Compile the release bundle and sign `dist/IlhaDinamica.app`:

```bash
./scripts/build_app.sh
```
