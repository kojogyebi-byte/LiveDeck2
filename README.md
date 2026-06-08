# LiveDeck Studio (macOS)

A native Mac live video production app: mix cameras, screen captures, video files and images; overlay animated lower thirds, tickers, countdowns, clocks, scoreboards, titles, logos and QR codes; record the program to MP4; and send a clean full-screen feed to a projector or streaming encoder.

Built with Swift, SwiftUI, AVFoundation and ScreenCaptureKit. Requires macOS 13 Ventura or newer.

## How to build it (no terminal needed)

1. Create a new repository on github.com (private is fine).
2. Upload this entire folder's contents to the repository, keeping the structure:
   - `Package.swift`
   - `Sources/LiveDeck/` (the four .swift files)
   - `Resources/Info.plist`
   - `.github/workflows/build.yml`

   Tip: when uploading via the GitHub web interface, drag the whole folder in so the paths are preserved. The `.github` folder is hidden on Mac — press Cmd+Shift+. in Finder to see it.
3. Go to the repository's **Actions** tab. The build starts automatically on upload (or press "Run workflow").
4. When the green check appears (about 3–5 minutes), open the run and download the **LiveDeck-macOS** artifact.
5. Unzip it. The first time you open LiveDeck.app, **right-click → Open → Open** (it is ad-hoc signed, not notarized, so macOS asks once).
6. Grant Camera, Microphone and Screen Recording permissions when prompted. Screen Recording may require a quit-and-reopen after granting (that's a macOS rule, not a bug).

## Using it

- **Sources (left):** add cameras (the Camera button lists every connected device, including USB capture cards that show up as webcams), full-screen captures, looping video files, images and solid colors. Press **TAKE** to switch the Program, with an optional crossfade.
- **Layers (right):** add graphics with ＋. The red switch animates a layer on/off air. Top of the list renders in front. Click a layer to edit its text, colors, sizes and controls (countdown start/pause/reset, scoreboard +/−).
- **REC (⌘R):** records Program video + microphone audio to an MP4 in your Movies folder (H.264/AAC — uploads straight to YouTube, plays anywhere).
- **Snapshot:** saves a PNG of the program to your Desktop.
- **Output Window:** a clean program feed. Drag it to a projector/second display and make it full screen, or capture this window in OBS / YouTube Studio's "stream from webcam" page to go live.

## Current limitations (v1.0)

- Program output is fixed at 1280×720, 30 fps.
- Recorded audio comes from the system default microphone (choose it in System Settings → Sound → Input). Audio from video files and screen captures plays out loud but is not yet mixed into the recording.
- Direct RTMP streaming, NDI, Syphon, ATEM control and virtual-camera output are not included — those require licensed third-party SDKs and system extensions.

## Roadmap candidates

1080p output, multi-source audio mixer, picture-in-picture layouts, show save/load, lower-third style presets, and a built-in RTMP streamer (via a bundled ffmpeg).
