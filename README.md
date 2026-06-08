# LiveDeck Studio (macOS) — v2.3  (loop, mixer + effects, resizable UI, stream settings)

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

## v2.3 — playback, mixing, resizable UI & streaming setup

- **Loop & playback control.** Video file inputs have a **Loop** toggle plus **Pause/Play** and **Restart** in the Input tab.
- **Editable input names.** Rename any input in the Input tab; the name updates everywhere (bus, monitors, mixer).
- **Per-input audio metering.** Assign an audio device to each input (Input tab → Audio) and its channel strip shows a **live VU meter**. Strips have fader, **Mute** and **Solo**.
- **Audio effects per input.** An **EQ** (low/mid/high), **Compressor** (threshold/ratio) and **Gate** (threshold) editor on every input and in the mixer's FX popover. Parameters are stored per input.
- **Resizable sections.** The monitors area, input bus and right panel are now separated by draggable dividers — size each section to taste.
- **Stream settings.** The **STREAM** button opens a destinations manager: add multiple targets, pick a **platform** (YouTube / Facebook Live / Twitch / Custom) which auto-fills the ingest URL, choose a **protocol** (RTMP / RTMPS / SRT), and enter your server URL + stream key. Destinations are saved between launches.

> Honest note on audio & streaming: per-input meters are real and effect/fader/mute settings are stored, but the recording still captures the master input device — summing every input through its effects into the recording is the remaining audio-engine milestone. Likewise, stream destinations are saved and the full ingest URL is composed for you, but going live needs a streaming encoder that isn't bundled yet (capture the Program window in OBS / YouTube to broadcast today).

## v2.2 — flexible inputs & external video devices

- **Five blank input slots** are created on launch. Click a slot's **Select input** button to assign it to a camera/device, screen capture, video file, image or colour — just like vMix's input list. **Add Input** (bus header) also has a **Blank Input** option to add more empty slots.
- **External video devices.** The device list now enumerates everything AVFoundation can see: built-in cameras, USB webcams, HDMI/SDI capture cards, and — when their macOS drivers are installed — **Blackmagic DeckLink** and **AJA** inputs, plus virtual cameras (e.g. OBS). This uses the CoreMediaIO opt-in so DAL/hardware devices appear without needing each vendor's SDK. Use **Refresh devices** if you plug something in while running.
- **More video formats.** The file picker now accepts MOV, MP4, M4V, MPEG-4, MPEG/TS, AVI, WMV and MKV containers. Note: playback depends on macOS having a codec for the file — Apple natively decodes H.264/HEVC/ProRes in MOV/MP4/M4V (and MPEG-TS); AVI/WMV/MKV play only if you have the matching codecs installed, otherwise the input stays black.

## v2.1 — live adjustment controls on every element

- **Per-input adjustments (Input tab).** Tap any input's thumbnail, then tune it live: **Zoom, Pan X/Y, Rotate, Crop (each edge), Brightness, Contrast, Saturation**, plus audio **Gain** and **Mute**. A **Reset** button restores defaults. Mirrors vMix's "Zoom, Pan, Rotate, Crop" and real-time colour correction.
- **Per-overlay transform.** Every layer's inspector now has a **Transform** section: **Opacity, Position X/Y, Scale, Rotate** with Reset. Saved inside your `.livedeck` files.
- **Transition speed.** A **Speed** slider in the transition column sets the auto-transition duration (0.2–2.0s).

## Honest scope — what's NOT included

These vMix features need licensed SDKs, Windows-only components, or system extensions and are not in this app: **NDI, virtual camera, vMix Call, Zoom integration, SRT, AJA/Blackmagic hardware *output* (input via drivers now works), instant replay, DVD, web-browser input, and the GT title designer.** Direct RTMP streaming also needs a relay and is not wired (capture the Program window in OBS/YouTube to stream for now).

Audio: meters are real on the Master/Recording/program-input strips; faders and mutes are stored per input. Recorded audio is the single selected input device (route your mixer's USB feed there for a full board mix). True simultaneous multi-source audio mixing into the recording is the next milestone.
