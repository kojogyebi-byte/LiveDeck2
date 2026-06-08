# LiveDeck Studio (macOS) — v1.2

A native Mac live video production app: mix cameras, screen captures, video files and images; overlay animated graphics with reusable variants; monitor audio levels; record to MP4; and send a clean feed or a multiview to a second display. Built with Swift, SwiftUI, AVFoundation and ScreenCaptureKit. Requires macOS 13 Ventura or newer.

## Build it (no terminal needed)

1. Unzip this folder. Reveal the hidden `.github` folder in Finder with **Cmd+Shift+.**
2. Create a repository on github.com (Private is fine), then **Add file → Upload files** and drag in everything *inside* the `LiveDeck` folder (so `Package.swift` sits at the repo root). **Commit changes.**
3. Open the **Actions** tab. The build runs automatically (~4–6 min). The workflow also turns the included `AppIcon-1024.png` into a proper `.icns` and embeds it, so the app ships with its icon.
4. Download the **LiveDeck-macOS** artifact, unzip, and the first time **right-click → Open → Open**.
5. Grant Camera, Microphone and Screen Recording permissions.

## What's new in v1.2 (modelled on mimoLive)

- **App icon** — a layered live-switcher mark, built into the bundle by the workflow.
- **Program preview bar** — live resolution + fps readout, a green/red activity dot (turns red on REC), and a real-time **audio level meter** down the right edge (driven by your selected input).
- **Safe-area guides** — toggle 90% / 80% guides over the preview (not recorded).
- **Multiview window** — a broadcast-style grid of every source, with the on-air source ringed in red. Drag it to a second monitor.
- **Layer variants** — mimoLive's signature feature: save multiple states per layer (e.g. each speaker's name and title) and switch or cycle them live with the ◀ ▶ buttons. Variants are saved inside your `.livedeck` show files.
- **Output Destinations panel** — a unified row of outputs with live state, mirroring mimoLive's destinations list: Record (MP4), Program Window, and Still Image are active; Live Stream, NDI/Syphon and Virtual Camera are shown but disabled (they need licensed SDKs or a streaming relay — on the roadmap).

## How layers work

Layers stack with the top of the list rendered in front. The red switch animates a layer on/off air. Click a layer to edit it; the **Variants** strip at the top of the inspector lets you snapshot the current look and recall it instantly during a service.

## Still not included (honest scope)

Direct RTMP streaming, NDI, Syphon, Blackmagic and virtual-camera output require third-party SDKs / system extensions and aren't bundled. Recorded audio is the single selected input device (route your mixer's USB feed there for a full board mix); multi-source in-app audio mixing is the next major item.
