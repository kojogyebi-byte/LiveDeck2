# LiveDeck Studio (macOS) — v2.1  (vMix-style switcher + live adjustments)

A native Mac live production switcher: Preview/Program buses with a transition T-bar, an input bus with live thumbnails, an audio mixer with VU meters, animated overlay graphics with variants, multiview, and MP4 recording. Built with Swift, SwiftUI, AVFoundation and ScreenCaptureKit. Requires macOS 13 Ventura or newer.

## Build (no terminal needed)

1. Unzip. Reveal the hidden `.github` folder with **Cmd+Shift+.**
2. Create a GitHub repo, **Add file → Upload files**, drag in everything *inside* the `LiveDeck` folder (so `Package.swift` is at the repo root), **Commit**.
3. **Actions** tab → wait ~4–6 min for the green check (the workflow also builds the app icon). Download the **LiveDeck-macOS** artifact, unzip, **right-click → Open** the first time, and grant Camera / Microphone / Screen Recording permissions.

## v2.0 — rebuilt around the vMix workflow

- **Preview → Program switcher.** Click an input to stage it in the Preview monitor (orange). Send it to Program (green) with the transition column or the input tile's **PGM** button.
- **Transitions + T-bar.** Cut, Fade, Wipe, Slide and Zoom. Click a transition to auto-run it, or drag the **T-BAR** to ride it manually. **FTB** fades Program to black.
- **Input bus.** A scrolling row of inputs with live thumbnails, numbers, an on-air/preview border, a per-input audio (mute) toggle, and a direct-to-Program button.
- **Audio mixer panel.** Master and Recording strips with live VU meters, plus a channel strip per input (meter, fader, M-mute), mirroring vMix's mixer.
- **Overlay channels.** Your layers act as overlays; the status-bar buttons 1–4 toggle the first four on air, and the Overlays tab holds the full layer list, inspector and variants.
- **Status bar & top bar.** Resolution/FPS readout, clock + on-air timer, Record/Stream/Snapshot/Multiview, and a vMix-style top bar (Open/Save, Fullscreen output, STREAM, REC).

## v2.1 — live adjustment controls on every element

- **Per-input adjustments (Input tab).** Tap any input's thumbnail, then tune it live: **Zoom, Pan X/Y, Rotate, Crop (each edge), Brightness, Contrast, Saturation**, plus audio **Gain** and **Mute**. A **Reset** button restores defaults. Mirrors vMix's "Zoom, Pan, Rotate, Crop" and real-time colour correction.
- **Per-overlay transform.** Every layer's inspector now has a **Transform** section: **Opacity, Position X/Y, Scale, Rotate** with Reset. Saved inside your `.livedeck` files.
- **Transition speed.** A **Speed** slider in the transition column sets the auto-transition duration (0.2–2.0s).

## Honest scope — what's NOT included

These vMix features need licensed SDKs, Windows-only components, or system extensions and are not in this app: **NDI, virtual camera, vMix Call, Zoom integration, SRT, AJA/Blackmagic/Bluefish hardware output, instant replay, DVD, web-browser input, and the GT title designer.** Direct RTMP streaming also needs a relay and is not wired (capture the Program window in OBS/YouTube to stream for now).

Audio: meters are real on the Master/Recording/program-input strips; faders and mutes are stored per input. Recorded audio is the single selected input device (route your mixer's USB feed there for a full board mix). True simultaneous multi-source audio mixing into the recording is the next milestone.
