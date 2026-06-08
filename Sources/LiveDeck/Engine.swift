import Foundation
import AVFoundation
import AppKit
import CoreMedia
import Combine
import UniformTypeIdentifiers

final class Engine: ObservableObject {
    @Published var width = 1280
    @Published var height = 720

    @Published var sources: [Source] = []
    @Published var layers: [Layer] = []
    @Published var selectedLayerID: UUID?
    @Published var programID: UUID?
    @Published var useFade = true
    @Published var isRecording = false
    @Published var recordSeconds = 0
    @Published var lastRecordingURL: URL?

    @Published var audioDevices: [AudioDeviceInfo] = []
    @Published var selectedAudioDeviceID: String?

    @Published var audioLevel: Float = 0
    @Published var fps: Int = 0
    @Published var showSafeGuides = false

    // Output destinations (mimoLive-style list with live toggles)
    @Published var fileOutputActive = false        // mirrors isRecording
    @Published var programWindowActive = false

    private var previousID: UUID?
    private var fade: Double = 1
    private var timer: Timer?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    private var fpsClock: CFTimeInterval = 0

    private var consumers = NSHashTable<FrameNSView>.weakObjects()
    private var multiviewConsumer: FrameNSView?
    private var multiviewWindow: NSWindow?

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let audioCapture = AudioCapture()
    private var recordTimer: Timer?

    private var outputWindow: NSWindow?

    // MARK: lifecycle

    func start() {
        guard timer == nil else { return }
        audioDevices = AudioCapture.availableDevices()
        lastFrameTime = CACurrentMediaTime()
        fpsClock = lastFrameTime
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.renderFrame()
        }
        t.tolerance = 0.005
        RunLoop.main.add(t, forMode: .common)
        timer = t
        audioCapture.onSampleBuffer = { [weak self] sb in
            guard let self, self.isRecording,
                  let input = self.audioInput, input.isReadyForMoreMediaData else { return }
            input.append(sb)
        }
        audioCapture.onLevel = { [weak self] lvl in self?.audioLevel = lvl }
        audioCapture.start(deviceID: selectedAudioDeviceID)   // runs continuously for metering
    }

    /// Switch the metering / recording input device.
    func setAudioDevice(_ id: String?) {
        selectedAudioDeviceID = id
        audioCapture.start(deviceID: id)
    }

    func addConsumer(_ v: FrameNSView) { consumers.add(v) }

    func setResolution(width: Int, height: Int) {
        guard !isRecording else { return }
        self.width = width; self.height = height
    }

    // MARK: sources

    func addCamera(_ device: AVCaptureDevice) { let s = CameraSource(device: device); sources.append(s); if programID == nil { take(s.id) } }
    func addScreen() { let s = ScreenSource(); sources.append(s); if programID == nil { take(s.id) } }
    func addFile(url: URL) { let s = FileSource(url: url); sources.append(s); if programID == nil { take(s.id) } }
    func addImage(url: URL) { let s = ImageSource(url: url); sources.append(s); if programID == nil { take(s.id) } }
    func addColor() { let s = ColorSource(); sources.append(s); if programID == nil { take(s.id) } }

    func removeSource(_ id: UUID) {
        if let s = sources.first(where: { $0.id == id }) { s.stop() }
        sources.removeAll { $0.id == id }
        if programID == id { programID = nil }
        if previousID == id { previousID = nil }
    }

    func take(_ id: UUID) {
        guard programID != id else { return }
        previousID = programID; programID = id; fade = useFade ? 0 : 1
    }

    // MARK: layers

    func addLayer(_ kind: Layer.Kind) { let l = Layer(kind: kind); layers.insert(l, at: 0); selectedLayerID = l.id }
    func removeLayer(_ id: UUID) { layers.removeAll { $0.id == id }; if selectedLayerID == id { selectedLayerID = nil } }
    func moveLayer(_ id: UUID, by delta: Int) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta; guard j >= 0, j < layers.count else { return }
        layers.swapAt(i, j)
    }

    // MARK: frame loop

    private func renderFrame() {
        let now = CACurrentMediaTime()
        let dt = now - lastFrameTime
        lastFrameTime = now

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

        if fade < 1 { fade = min(1, fade + dt / 0.5) }
        if fade < 1, let prev = previousID, let s = sources.first(where: { $0.id == prev }) {
            s.draw(in: ctx, width: width, height: height)
        }
        if let cur = programID, let s = sources.first(where: { $0.id == cur }) {
            ctx.saveGState()
            ctx.setAlpha(CGFloat(fade < 1 ? fade * fade : 1))
            s.draw(in: ctx, width: width, height: height)
            ctx.restoreGState()
        }

        let provider: (UUID) -> CGImage? = { [weak self] id in
            self?.sources.first(where: { $0.id == id })?.currentImage()
        }
        for layer in layers.reversed() {
            layer.liveT += (layer.isLive ? 1 : -1) * dt / 0.45
            layer.liveT = max(0, min(1, layer.liveT))
            if layer.liveT > 0 {
                LayerRenderer.render(layer, in: ctx, width: width, height: height,
                                     time: now, sourceImage: provider)
            }
        }

        if let img = ctx.makeImage() {
            for v in consumers.allObjects { v.show(img) }
        }

        if isRecording, let input = videoInput, input.isReadyForMoreMediaData, let adaptor = adaptor {
            let pts = CMClockGetTime(CMClockGetHostTimeClock())
            adaptor.append(pb, withPresentationTime: pts)
        }

        // Multiview grid (broadcast multiviewer of all sources)
        if let mv = multiviewConsumer, multiviewWindow?.isVisible == true {
            if let grid = composeMultiview() { mv.show(grid) }
        }

        // fps
        frameCount += 1
        if now - fpsClock >= 1.0 {
            fps = frameCount
            frameCount = 0
            fpsClock = now
        }
    }

    private func composeMultiview() -> CGImage? {
        let cells = sources
        let n = max(1, cells.count)
        let cols = Int(ceil(sqrt(Double(n))))
        let rows = Int(ceil(Double(n) / Double(cols)))
        let cw = 320, ch = 180
        let gw = cols * cw, gh = rows * ch
        guard let ctx = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: gw, height: gh))
        for (i, src) in cells.enumerated() {
            let cx = (i % cols) * cw
            let cy = gh - ((i / cols) + 1) * ch   // top-to-bottom
            let rect = CGRect(x: cx + 4, y: cy + 4, width: cw - 8, height: ch - 8)
            ctx.saveGState()
            ctx.clip(to: rect)
            if let img = src.currentImage() {
                let iw = CGFloat(img.width), ih = CGFloat(img.height)
                let s = max(rect.width / iw, rect.height / ih)
                ctx.draw(img, in: CGRect(x: rect.midX - iw * s / 2, y: rect.midY - ih * s / 2,
                                         width: iw * s, height: ih * s))
            } else if let color = (src as? ColorSource)?.color {
                ctx.setFillColor(color.cgColor); ctx.fill(rect)
            }
            ctx.restoreGState()
            let onAir = programID == src.id
            ctx.setStrokeColor((onAir ? NSColor.red : NSColor(white: 0.25, alpha: 1)).cgColor)
            ctx.setLineWidth(onAir ? 4 : 2)
            ctx.stroke(rect)
        }
        return ctx.makeImage()
    }

    // MARK: recording

    func toggleRecording() { isRecording ? stopRecording() : startRecording() }

    private func startRecording() {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = movies.appendingPathComponent("LiveDeck_\(fmt.string(from: Date())).mp4")

        do {
            let w = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let vSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width, AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: height >= 1080 ? 12_000_000 : 6_000_000]
            ]
            let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
            vIn.expectsMediaDataInRealTime = true
            let ad = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: vIn,
                sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            if w.canAdd(vIn) { w.add(vIn) }

            let aSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000]
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
            aIn.expectsMediaDataInRealTime = true
            if w.canAdd(aIn) { w.add(aIn) }

            w.startWriting()
            w.startSession(atSourceTime: CMClockGetTime(CMClockGetHostTimeClock()))

            writer = w; videoInput = vIn; audioInput = aIn; adaptor = ad
            recordSeconds = 0; isRecording = true; fileOutputActive = true
            recordTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordSeconds += 1
            }
        } catch {
            NSLog("Recording failed to start: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        isRecording = false; fileOutputActive = false
        recordTimer?.invalidate(); recordTimer = nil
        guard let w = writer else { return }
        videoInput?.markAsFinished(); audioInput?.markAsFinished()
        let url = w.outputURL
        w.finishWriting { [weak self] in
            DispatchQueue.main.async {
                self?.lastRecordingURL = url
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        writer = nil; videoInput = nil; audioInput = nil; adaptor = nil
    }

    // MARK: snapshot

    func snapshot() {
        guard let c = consumers.allObjects.first?.layer?.contents else { return }
        let img = c as! CGImage
        let rep = NSBitmapImageRep(cgImage: img)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let url = desktop.appendingPathComponent("LiveDeck_\(fmt.string(from: Date())).png")
        try? data.write(to: url)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: save / load show

    func saveShow() {
        let show = ShowFile(width: width, height: height, layers: layers.map { $0.toShowLayer() })
        guard let data = try? JSONEncoder().encode(show) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Untitled.livedeck"
        if let t = UTType(filenameExtension: "livedeck") { panel.allowedContentTypes = [t] }
        panel.begin { resp in
            if resp == .OK, let url = panel.url { try? data.write(to: url) }
        }
    }

    func loadShow() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let t = UTType(filenameExtension: "livedeck") { panel.allowedContentTypes = [t] }
        panel.begin { [weak self] resp in
            guard let self, resp == .OK, let url = panel.url,
                  let data = try? Data(contentsOf: url),
                  let show = try? JSONDecoder().decode(ShowFile.self, from: data) else { return }
            self.setResolution(width: show.width, height: show.height)
            self.layers = show.layers.compactMap { Layer.from($0) }
            self.selectedLayerID = self.layers.first?.id
        }
    }

    // MARK: output window

    func openOutputWindow() {
        if let w = outputWindow { w.makeKeyAndOrderFront(nil); return }
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
        programWindowActive = true
    }

    // MARK: multiview

    func openMultiviewWindow() {
        if let w = multiviewWindow { w.makeKeyAndOrderFront(nil); return }
        let view = FrameNSView(frame: NSRect(x: 0, y: 0, width: 960, height: 540))
        multiviewConsumer = view
        let win = NSWindow(contentRect: NSRect(x: 260, y: 160, width: 960, height: 540),
                           styleMask: [.titled, .closable, .resizable],
                           backing: .buffered, defer: false)
        win.title = "LiveDeck — Multiview"
        win.contentView = view
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        multiviewWindow = win
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
    func show(_ image: CGImage) { layer?.contents = image }
}
