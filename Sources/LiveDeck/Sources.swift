import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreImage
import AppKit

let sharedCIContext = CIContext()

// MARK: - Base source

class Source: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    let kindLabel: String

    var latestBuffer: CVPixelBuffer?
    private var cachedImage: CGImage?

    init(name: String, kindLabel: String) {
        self.name = name
        self.kindLabel = kindLabel
        super.init()
    }

    /// Latest video frame as CGImage (converted lazily).
    func currentImage() -> CGImage? {
        if let pb = latestBuffer {
            let ci = CIImage(cvPixelBuffer: pb)
            cachedImage = sharedCIContext.createCGImage(ci, from: ci.extent)
            latestBuffer = nil
        }
        return cachedImage
    }

    /// Draw this source cover-fit into the context.
    func draw(in ctx: CGContext, width: Int, height: Int) {
        guard let img = currentImage() else { return }
        let iw = CGFloat(img.width), ih = CGFloat(img.height)
        guard iw > 0, ih > 0 else { return }
        let scale = max(CGFloat(width) / iw, CGFloat(height) / ih)
        let dw = iw * scale, dh = ih * scale
        ctx.draw(img, in: CGRect(x: (CGFloat(width) - dw) / 2,
                                 y: (CGFloat(height) - dh) / 2,
                                 width: dw, height: dh))
    }

    func stop() {}
}

// MARK: - Camera

final class CameraSource: Source, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "cam.queue")

    init(device: AVCaptureDevice) {
        super.init(name: device.localizedName, kindLabel: "CAMERA")
        session.sessionPreset = .high
        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(out) { session.addOutput(out) }
        queue.async { [weak self] in self?.session.startRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) {
            DispatchQueue.main.async { [weak self] in self?.latestBuffer = pb }
        }
    }

    override func stop() { queue.async { [session] in session.stopRunning() } }
}

// MARK: - Screen capture (ScreenCaptureKit)

final class ScreenSource: Source, SCStreamOutput {
    private var stream: SCStream?

    init() {
        super.init(name: "Screen", kindLabel: "SCREEN")
        Task { await startCapture() }
    }

    private func startCapture() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let cfg = SCStreamConfiguration()
            cfg.width = display.width
            cfg.height = display.height
            cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            cfg.pixelFormat = kCVPixelFormatType_32BGRA
            cfg.showsCursor = true
            let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
            try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "screen.queue"))
            try await s.startCapture()
            self.stream = s
        } catch {
            NSLog("Screen capture failed: \(error.localizedDescription)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        DispatchQueue.main.async { [weak self] in self?.latestBuffer = pb }
    }

    override func stop() {
        stream?.stopCapture { _ in }
        stream = nil
    }
}

// MARK: - Video file (loops)

final class FileSource: Source {
    private let player: AVPlayer
    private let output: AVPlayerItemVideoOutput
    private var loopObserver: NSObjectProtocol?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        item.add(output)
        player = AVPlayer(playerItem: item)
        super.init(name: url.lastPathComponent, kindLabel: "FILE")
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        player.play()
    }

    override func currentImage() -> CGImage? {
        let time = player.currentTime()
        if output.hasNewPixelBuffer(forItemTime: time),
           let pb = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
            latestBuffer = pb
        }
        return super.currentImage()
    }

    override func stop() {
        player.pause()
        if let o = loopObserver { NotificationCenter.default.removeObserver(o) }
    }
}

// MARK: - Still image

final class ImageSource: Source {
    private let image: CGImage?

    init(url: URL) {
        let nsimg = NSImage(contentsOf: url)
        var rect = CGRect(origin: .zero, size: nsimg?.size ?? .zero)
        image = nsimg?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        super.init(name: url.lastPathComponent, kindLabel: "IMAGE")
    }

    override func currentImage() -> CGImage? { image }
}

// MARK: - Solid color

final class ColorSource: Source {
    @Published var color: NSColor

    init(color: NSColor = NSColor(red: 0.10, green: 0.43, blue: 0.85, alpha: 1)) {
        self.color = color
        super.init(name: "Color", kindLabel: "COLOR")
    }

    override func draw(in ctx: CGContext, width: Int, height: Int) {
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

// MARK: - Microphone capture (feeds the recorder)

final class MicCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "mic.queue")
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }
        let out = AVCaptureAudioDataOutput()
        out.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(out) { session.addOutput(out) }
        queue.async { [session] in session.startRunning() }
        isRunning = true
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)
    }
}
