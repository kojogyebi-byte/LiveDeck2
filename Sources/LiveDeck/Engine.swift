import Foundation
import AVFoundation
import AppKit
import CoreMedia
import Combine

final class Engine: ObservableObject {
    let width = 1280
    let height = 720

    @Published var sources: [Source] = []
    @Published var layers: [Layer] = []
    @Published var selectedLayerID: UUID?
    @Published var programID: UUID?
    @Published var useFade = true
    @Published var isRecording = false
    @Published var recordSeconds = 0
    @Published var lastRecordingURL: URL?

    private var previousID: UUID?
    private var fade: Double = 1
    private var timer: Timer?
    private var lastFrameTime: CFTimeInterval = 0

    // Frame consumers (preview views, output window)
    private var consumers = NSHashTable<FrameNSView>.weakObjects()

    // Recording
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let mic = MicCapture()
    private var recordTimer: Timer?

    private var outputWindow: NSWindow?

    // MARK: lifecycle

    func start() {
        guard timer == nil else { return }
        lastFrameTime = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.renderFrame()
        }
        t.tolerance = 0.005
        RunLoop.main.add(t, forMode: .common)
        timer = t
        mic.onSampleBuffer = { [weak self] sb in
            guard let self, self.isRecording,
                  let input = self.audioInput, input.isReadyForMoreMediaData else { return }
            input.append(sb)
        }
    }

    func addConsumer(_ v: FrameNSView) { consumers.add(v) }

    // MARK: sources

    func addCamera(_ device: AVCaptureDevice) {
        let s = CameraSource(device: device)
        sources.append(s)
        if programID == nil { take(s.id) }
    }

    func addScreen() {
        let s = ScreenSource()
        sources.append(s)
        if programID == nil { take(s.id) }
    }

    func addFile(url: URL) {
        let s = FileSource(url: url)
        sources.append(s)
        if programID == nil { take(s.id) }
    }

    func addImage(url: URL) {
        let s = ImageSource(url: url)
        sources.append(s)
        if programID == nil { take(s.id) }
    }

    func addColor() {
        let s = ColorSource()
        sources.append(s)
        if programID == nil { take(s.id) }
    }

    func removeSource(_ id: UUID) {
        if let s = sources.first(where: { $0.id == id }) { s.stop() }
        sources.removeAll { $0.id == id }
        if programID == id { programID = nil }
        if previousID == id { previousID = nil }
    }

    func take(_ id: UUID) {
        guard programID != id else { return }
        previousID = programID
        programID = id
        fade = useFade ? 0 : 1
    }

    // MARK: layers

    func addLayer(_ kind: Layer.Kind) {
        let l = Layer(kind: kind)
        layers.insert(l, at: 0)
        selectedLayerID = l.id
    }

    func removeLayer(_ id: UUID) {
        layers.removeAll { $0.id == id }
        if selectedLayerID == id { selectedLayerID = nil }
    }

    func moveLayer(_ id: UUID, by delta: Int) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard j >= 0, j < layers.count else { return }
        layers.swapAt(i, j)
    }

    // MARK: frame loop

    private func renderFrame() {
        let now = CACurrentMediaTime()
        let dt = now - lastFrameTime
        lastFrameTime = now

        // Pixel buffer backing the frame
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var pbOut: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pbOut)
        guard let pb = pbOut else { return }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Background with crossfade
        if fade < 1 { fade = min(1, fade + dt / 0.5) }
        if fade < 1, let prev = previousID,
           let s = sources.first(where: { $0.id == prev }) {
            s.draw(in: ctx, width: width, height: height)
        }
        if let cur = programID, let s = sources.first(where: { $0.id == cur }) {
            ctx.saveGState()
            ctx.setAlpha(CGFloat(fade < 1 ? fade * fade : 1))
            s.draw(in: ctx, width: width, height: height)
            ctx.restoreGState()
        }

        // Layers: bottom of list first, top of list in front
        for layer in layers.reversed() {
            layer.liveT += (layer.isLive ? 1 : -1) * dt / 0.45
            layer.liveT = max(0, min(1, layer.liveT))
            if layer.liveT > 0 {
                LayerRenderer.render(layer, in: ctx, width: width, height: height, time: now)
            }
        }

        // Show in previews
        if let img = ctx.makeImage() {
            for v in consumers.allObjects { v.show(img) }
        }

        // Append to recording
        if isRecording, let input = videoInput, input.isReadyForMoreMediaData,
           let adaptor = adaptor {
            let pts = CMClockGetTime(CMClockGetHostTimeClock())
            adaptor.append(pb, withPresentationTime: pts)
        }
    }

    // MARK: recording

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = movies.appendingPathComponent("LiveDeck_\(fmt.string(from: Date())).mp4")

        do {
            let w = try AVAssetWriter(outputURL: url, fileType: .mp4)

            let vSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000]
            ]
            let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
            vIn.expectsMediaDataInRealTime = true
            let ad = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: vIn,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ])
            if w.canAdd(vIn) { w.add(vIn) }

            let aSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000
            ]
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
            aIn.expectsMediaDataInRealTime = true
            if w.canAdd(aIn) { w.add(aIn) }

            mic.start()
            w.startWriting()
            w.startSession(atSourceTime: CMClockGetTime(CMClockGetHostTimeClock()))

            writer = w
            videoInput = vIn
            audioInput = aIn
            adaptor = ad
            recordSeconds = 0
            isRecording = true
            recordTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordSeconds += 1
            }
        } catch {
            NSLog("Recording failed to start: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        isRecording = false
        recordTimer?.invalidate()
        recordTimer = nil
        guard let w = writer else { return }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        let url = w.outputURL
        w.finishWriting { [weak self] in
            DispatchQueue.main.async {
                self?.lastRecordingURL = url
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        writer = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
    }

    // MARK: snapshot

    func snapshot() {
        // Render current preview content from the first consumer's layer
        guard let v = consumers.allObjects.first,
              let contents = v.layer?.contents else { return }
        let img = contents as! CGImage
        let rep = NSBitmapImageRep(cgImage: img)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let url = desktop.appendingPathComponent("LiveDeck_\(fmt.string(from: Date())).png")
        try? data.write(to: url)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: output window

    func openOutputWindow() {
        if let w = outputWindow {
            w.makeKeyAndOrderFront(nil)
            return
        }
        let view = FrameNSView(frame: NSRect(x: 0, y: 0, width: 960, height: 540))
        addConsumer(view)
        let win = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 960, height: 540),
                           styleMask: [.titled, .closable, .resizable],
                           backing: .buffered, defer: false)
        win.title = "LiveDeck — Program Out  (⌘⌃F for full screen)"
        win.contentView = view
        win.collectionBehavior = [.fullScreenPrimary]
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        outputWindow = win
    }
}

// MARK: - Frame display view

final class FrameNSView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func show(_ image: CGImage) {
        layer?.contents = image
    }
}
