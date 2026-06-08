import Foundation
import AppKit
import SwiftUI
import CoreImage

// MARK: - Layer model

final class Layer: ObservableObject, Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case lowerThird = "Lower Third"
        case ticker = "Ticker / Crawl"
        case countdown = "Countdown"
        case clock = "Clock"
        case scoreboard = "Scoreboard"
        case title = "Title"
        case logo = "Logo / Image"
        case qrcode = "QR Code"
        case pip = "Picture in Picture"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .lowerThird: return "rectangle.bottomthird.inset.filled"
            case .ticker: return "text.line.last.and.arrowtriangle.forward"
            case .countdown: return "timer"
            case .clock: return "clock"
            case .scoreboard: return "sportscourt"
            case .title: return "textformat"
            case .logo: return "photo"
            case .qrcode: return "qrcode"
            case .pip: return "pip"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    @Published var name: String
    @Published var isLive = false
    var liveT: Double = 0

    @Published var text1: String
    @Published var text2: String
    @Published var accent: Color = Color(red: 1.0, green: 0.69, blue: 0.13)
    @Published var number1: Double = 5
    @Published var scoreA: Int = 0
    @Published var scoreB: Int = 0
    @Published var position: Int = 1
    @Published var use24h: Bool = true
    @Published var style: Int = 0          // lower-third preset
    @Published var sourceRef: UUID?        // PiP source

    // Overlay transform adjustments
    @Published var opacity: Double = 1.0
    @Published var offsetX: Double = 0     // fraction of width
    @Published var offsetY: Double = 0     // fraction of height
    @Published var scaleAdj: Double = 1.0
    @Published var rotationAdj: Double = 0 // degrees

    func resetTransform() { opacity = 1; offsetX = 0; offsetY = 0; scaleAdj = 1; rotationAdj = 0 }

    var remaining: Double = 300
    @Published var isRunning = false
    var lastTick: CFTimeInterval = 0

    var logoImage: CGImage?
    var qrCache: CGImage?
    var qrCachedText: String = ""

    // mimoLive-style variants: saved states you cycle through and push live
    @Published var variants: [LayerVariant] = []
    @Published var activeVariant: Int = 0

    func captureVariant() {
        let c = accent.rgbaComponents()
        let v = LayerVariant(name: "Variant \(variants.count + 1)",
                             text1: text1, text2: text2,
                             aR: c.0, aG: c.1, aB: c.2, aA: c.3,
                             number1: number1, scoreA: scoreA, scoreB: scoreB,
                             position: position, style: style)
        variants.append(v)
        activeVariant = variants.count - 1
    }

    func applyVariant(_ i: Int) {
        guard variants.indices.contains(i) else { return }
        let v = variants[i]
        text1 = v.text1; text2 = v.text2
        accent = Color(.sRGB, red: v.aR, green: v.aG, blue: v.aB, opacity: v.aA)
        number1 = v.number1; scoreA = v.scoreA; scoreB = v.scoreB
        position = v.position; style = v.style
        activeVariant = i
    }

    func cycleVariant(_ delta: Int) {
        guard !variants.isEmpty else { return }
        let n = variants.count
        applyVariant(((activeVariant + delta) % n + n) % n)
    }

    init(kind: Kind) {
        self.kind = kind
        self.name = kind.rawValue
        switch kind {
        case .lowerThird:
            text1 = "Evangelist Dag Heward-Mills"; text2 = "Healing Jesus Campaign"
        case .ticker:
            text1 = "Welcome to the Healing Jesus Campaign  ✦  Jesus saves, heals and delivers  ✦  "
            text2 = ""; number1 = 90
        case .countdown:
            text1 = "STARTING IN"; text2 = ""; number1 = 5
        case .scoreboard:
            text1 = "TEAM A"; text2 = "TEAM B"
        case .title:
            text1 = "WELCOME"; text2 = ""; number1 = 9
        case .qrcode:
            text1 = "https://daghewardmills.org"; text2 = ""; number1 = 150
        case .logo:
            text1 = ""; text2 = ""; number1 = 14
        case .clock:
            text1 = ""; text2 = ""
        case .pip:
            text1 = ""; text2 = ""; number1 = 28; position = 3
        }
    }
}

// MARK: - Rendering helpers (CG origin is bottom-left)

private func ease(_ t: Double) -> CGFloat {
    let x = max(0, min(1, t))
    return CGFloat(x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2)
}

private func draw(_ string: String, at point: CGPoint, font: NSFont, color: NSColor,
                  in ctx: CGContext, centered: Bool = false) {
    let attr = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    let prev = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    var p = point
    if centered { p.x -= attr.size().width / 2 }
    attr.draw(at: p)
    NSGraphicsContext.current = prev
}

private func textWidth(_ string: String, font: NSFont) -> CGFloat {
    NSAttributedString(string: string, attributes: [.font: font]).size().width
}

private func coverDraw(_ img: CGImage, in rect: CGRect, ctx: CGContext) {
    let iw = CGFloat(img.width), ih = CGFloat(img.height)
    guard iw > 0, ih > 0 else { return }
    let s = max(rect.width / iw, rect.height / ih)
    let dw = iw * s, dh = ih * s
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.draw(img, in: CGRect(x: rect.midX - dw / 2, y: rect.midY - dh / 2, width: dw, height: dh))
    ctx.restoreGState()
}

// MARK: - Layer renderer

enum LayerRenderer {

    static func render(_ layer: Layer, in ctx: CGContext, width: Int, height: Int,
                       time: CFTimeInterval, sourceImage: (UUID) -> CGImage?) {
        let k = ease(layer.liveT)
        guard k > 0 else { return }
        let W = CGFloat(width), H = CGFloat(height)
        ctx.saveGState()

        switch layer.kind {

        case .lowerThird:
            let barW: CGFloat = 640, barH: CGFloat = 96
            let x = -barW + (barW + 60) * k
            let y: CGFloat = 110
            ctx.setAlpha(min(1, k * 1.4))
            let acc = NSColor(layer.accent)
            switch layer.style {
            case 1: // boxed, no strip
                ctx.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.9).cgColor)
                ctx.fill(CGRect(x: x, y: y, width: barW, height: barH))
                draw(layer.text1, at: CGPoint(x: x + 26, y: y + 44),
                     font: NSFont.boldSystemFont(ofSize: H * 0.045), color: .white, in: ctx)
                draw(layer.text2.uppercased(), at: CGPoint(x: x + 26, y: y + 12),
                     font: NSFont.boldSystemFont(ofSize: H * 0.026), color: acc, in: ctx)
            case 2: // minimal underline
                draw(layer.text1, at: CGPoint(x: x + 10, y: y + 40),
                     font: NSFont.boldSystemFont(ofSize: H * 0.05), color: .white, in: ctx)
                let w = textWidth(layer.text1, font: NSFont.boldSystemFont(ofSize: H * 0.05))
                ctx.setFillColor(acc.cgColor)
                ctx.fill(CGRect(x: x + 12, y: y + 30, width: w, height: 4))
                draw(layer.text2.uppercased(), at: CGPoint(x: x + 12, y: y - 2),
                     font: NSFont.boldSystemFont(ofSize: H * 0.026), color: acc, in: ctx)
            default: // accent strip (classic)
                ctx.setFillColor(acc.cgColor)
                ctx.fill(CGRect(x: x, y: y, width: 10, height: barH))
                ctx.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.88).cgColor)
                ctx.fill(CGRect(x: x + 10, y: y, width: barW, height: barH))
                draw(layer.text1, at: CGPoint(x: x + 34, y: y + 44),
                     font: NSFont.boldSystemFont(ofSize: H * 0.045), color: .white, in: ctx)
                draw(layer.text2.uppercased(), at: CGPoint(x: x + 34, y: y + 12),
                     font: NSFont.boldSystemFont(ofSize: H * 0.026), color: acc, in: ctx)
            }

        case .ticker:
            let barH = H * 0.07
            let y = -barH + barH * k
            ctx.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.92 * k).cgColor)
            ctx.fill(CGRect(x: 0, y: y, width: W, height: barH))
            ctx.setAlpha(k)
            let font = NSFont.boldSystemFont(ofSize: barH * 0.5)
            let tw = max(1, textWidth(layer.text1, font: font))
            let speed = CGFloat(max(10, layer.number1))
            var x = W - CGFloat(time).truncatingRemainder(dividingBy: (tw + W) / speed) * speed
            if x < -tw { x += tw + W }
            draw(layer.text1, at: CGPoint(x: x, y: y + barH * 0.22), font: font, color: .white, in: ctx)
            if x + tw < W {
                draw(layer.text1, at: CGPoint(x: x + tw, y: y + barH * 0.22), font: font, color: .white, in: ctx)
            }

        case .countdown:
            if layer.isRunning {
                let now = CACurrentMediaTime()
                if layer.lastTick > 0 { layer.remaining = max(0, layer.remaining - (now - layer.lastTick)) }
                layer.lastTick = now
                if layer.remaining == 0 { DispatchQueue.main.async { layer.isRunning = false } }
            }
            let m = Int(layer.remaining) / 60, s = Int(layer.remaining) % 60
            ctx.setAlpha(k)
            let cx = W / 2, cy = H * 0.55
            ctx.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.75).cgColor)
            ctx.fill(CGRect(x: cx - 220, y: cy - 100, width: 440, height: 200))
            draw(layer.text1.uppercased(), at: CGPoint(x: cx, y: cy + 50),
                 font: NSFont.boldSystemFont(ofSize: H * 0.035),
                 color: NSColor(layer.accent), in: ctx, centered: true)
            draw(String(format: "%02d:%02d", m, s), at: CGPoint(x: cx, y: cy - 70),
                 font: NSFont.monospacedDigitSystemFont(ofSize: H * 0.14, weight: .heavy),
                 color: .white, in: ctx, centered: true)

        case .clock:
            let date = Date(); let cal = Calendar.current
            var hour = cal.component(.hour, from: date)
            let minute = cal.component(.minute, from: date)
            var suffix = ""
            if !layer.use24h {
                suffix = hour >= 12 ? " PM" : " AM"; hour = hour % 12; if hour == 0 { hour = 12 }
            }
            let str = String(format: "%02d:%02d%@", hour, minute, suffix)
            ctx.setAlpha(k)
            ctx.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.8).cgColor)
            ctx.fill(CGRect(x: W - 230, y: H - 86, width: 200, height: 58))
            draw(str, at: CGPoint(x: W - 130, y: H - 72),
                 font: NSFont.monospacedDigitSystemFont(ofSize: H * 0.04, weight: .bold),
                 color: .white, in: ctx, centered: true)

        case .scoreboard:
            let y = H + 70 - 168 * k
            let cx = W / 2
            ctx.setFillColor(NSColor(layer.accent).cgColor)
            ctx.fill(CGRect(x: cx - 330, y: y, width: 250, height: 56))
            ctx.setFillColor(NSColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 0.92).cgColor)
            ctx.fill(CGRect(x: cx - 80, y: y, width: 160, height: 56))
            ctx.setFillColor(NSColor(red: 1, green: 0.23, blue: 0.23, alpha: 1).cgColor)
            ctx.fill(CGRect(x: cx + 80, y: y, width: 250, height: 56))
            let f = NSFont.boldSystemFont(ofSize: H * 0.036)
            draw(layer.text1.uppercased(), at: CGPoint(x: cx - 205, y: y + 14), font: f, color: .white, in: ctx, centered: true)
            draw(layer.text2.uppercased(), at: CGPoint(x: cx + 205, y: y + 14), font: f, color: .white, in: ctx, centered: true)
            draw("\(layer.scoreA) : \(layer.scoreB)", at: CGPoint(x: cx, y: y + 12),
                 font: NSFont.monospacedDigitSystemFont(ofSize: H * 0.042, weight: .heavy),
                 color: .white, in: ctx, centered: true)

        case .title:
            ctx.setAlpha(k)
            ctx.setShadow(offset: .zero, blur: 18, color: NSColor.black.withAlphaComponent(0.7).cgColor)
            let size = H * CGFloat(max(2, layer.number1)) / 100
            draw(layer.text1, at: CGPoint(x: W / 2, y: H * 0.5 - size / 2 - (1 - k) * 30),
                 font: NSFont.boldSystemFont(ofSize: size),
                 color: NSColor(layer.accent), in: ctx, centered: true)

        case .logo:
            if let img = layer.logoImage {
                ctx.setAlpha(k)
                let w = W * CGFloat(max(2, layer.number1)) / 100
                let h = w * CGFloat(img.height) / CGFloat(img.width)
                let m: CGFloat = 30
                let origins: [CGPoint] = [
                    CGPoint(x: m, y: H - h - m), CGPoint(x: W - w - m, y: H - h - m),
                    CGPoint(x: m, y: m), CGPoint(x: W - w - m, y: m)]
                let p = origins[min(max(layer.position, 0), 3)]
                ctx.draw(img, in: CGRect(x: p.x, y: p.y, width: w, height: h))
            }

        case .qrcode:
            if layer.qrCachedText != layer.text1 || layer.qrCache == nil {
                layer.qrCachedText = layer.text1
                layer.qrCache = Self.makeQR(layer.text1)
            }
            if let qr = layer.qrCache {
                let s = CGFloat(max(60, layer.number1)); let pad: CGFloat = 12
                let x = W - s - 40, y: CGFloat = 40
                ctx.setAlpha(k)
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fill(CGRect(x: x - pad, y: y - pad, width: s + pad * 2, height: s + pad * 2))
                ctx.interpolationQuality = .none
                ctx.draw(qr, in: CGRect(x: x, y: y, width: s, height: s))
            }

        case .pip:
            guard let ref = layer.sourceRef, let img = sourceImage(ref) else { break }
            ctx.setAlpha(k)
            let w = W * CGFloat(max(8, layer.number1)) / 100
            let h = w * CGFloat(img.height) / CGFloat(img.width)
            let m: CGFloat = 36
            let origins: [CGPoint] = [
                CGPoint(x: m, y: H - h - m), CGPoint(x: W - w - m, y: H - h - m),
                CGPoint(x: m, y: m), CGPoint(x: W - w - m, y: m)]
            let p = origins[min(max(layer.position, 0), 3)]
            let rect = CGRect(x: p.x, y: p.y, width: w, height: h)
            ctx.setFillColor(NSColor(layer.accent).cgColor)
            ctx.fill(rect.insetBy(dx: -4, dy: -4))
            coverDraw(img, in: rect, ctx: ctx)
        }
        ctx.restoreGState()
    }

    static func makeQR(_ text: String) -> CGImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return sharedCIContext.createCGImage(scaled, from: scaled.extent)
    }
}

// MARK: - Save / Load model

struct LayerVariant: Codable, Identifiable {
    var id = UUID()
    var name: String
    var text1: String, text2: String
    var aR: Double, aG: Double, aB: Double, aA: Double
    var number1: Double, scoreA: Int, scoreB: Int
    var position: Int, style: Int
}

struct ShowLayer: Codable {
    var kind: String, name: String, isLive: Bool
    var text1: String, text2: String
    var aR: Double, aG: Double, aB: Double, aA: Double
    var number1: Double, scoreA: Int, scoreB: Int
    var position: Int, use24h: Bool, style: Int
    var variants: [LayerVariant] = []
    var opacity: Double = 1
    var offsetX: Double = 0, offsetY: Double = 0
    var scaleAdj: Double = 1, rotationAdj: Double = 0
}

struct ShowFile: Codable {
    var width: Int, height: Int
    var layers: [ShowLayer]
}

extension Color {
    func rgbaComponents() -> (Double, Double, Double, Double) {
        let n = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.white
        return (Double(n.redComponent), Double(n.greenComponent),
                Double(n.blueComponent), Double(n.alphaComponent))
    }
}

extension Layer {
    func toShowLayer() -> ShowLayer {
        let c = accent.rgbaComponents()
        return ShowLayer(kind: kind.rawValue, name: name, isLive: isLive,
                         text1: text1, text2: text2,
                         aR: c.0, aG: c.1, aB: c.2, aA: c.3,
                         number1: number1, scoreA: scoreA, scoreB: scoreB,
                         position: position, use24h: use24h, style: style,
                         variants: variants,
                         opacity: opacity, offsetX: offsetX, offsetY: offsetY,
                         scaleAdj: scaleAdj, rotationAdj: rotationAdj)
    }

    static func from(_ s: ShowLayer) -> Layer? {
        guard let kind = Kind(rawValue: s.kind) else { return nil }
        let l = Layer(kind: kind)
        l.name = s.name; l.isLive = s.isLive; l.text1 = s.text1; l.text2 = s.text2
        l.accent = Color(.sRGB, red: s.aR, green: s.aG, blue: s.aB, opacity: s.aA)
        l.number1 = s.number1; l.scoreA = s.scoreA; l.scoreB = s.scoreB
        l.position = s.position; l.use24h = s.use24h; l.style = s.style
        l.variants = s.variants
        l.opacity = s.opacity; l.offsetX = s.offsetX; l.offsetY = s.offsetY
        l.scaleAdj = s.scaleAdj; l.rotationAdj = s.rotationAdj
        if kind == .countdown { l.remaining = s.number1 * 60 }
        return l
    }
}
