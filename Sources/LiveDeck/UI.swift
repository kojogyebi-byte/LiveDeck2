import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

// vMix-ish palette
private let cBG = Color(red: 0.10, green: 0.10, blue: 0.12)
private let cPanel = Color(red: 0.14, green: 0.14, blue: 0.17)
private let cBar = Color(red: 0.17, green: 0.17, blue: 0.20)
private let cPreview = Color(red: 0.88, green: 0.55, blue: 0.18)
private let cProgram = Color(red: 0.18, green: 0.70, blue: 0.30)
private let cBtn = Color(white: 0.20)

private let pipNoneTag = UUID()

struct MainView: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        MonitorPane(title: previewName, accent: cPreview, isProgram: false)
                        TransitionColumn()
                        MonitorPane(title: programName, accent: engine.isRecording ? .red : cProgram, isProgram: true)
                    }
                    .padding(6).frame(maxHeight: .infinity)
                    InputBus().frame(height: 156)
                }
                RightPanel().frame(width: 300)
            }
            StatusBar()
        }
        .background(cBG).preferredColorScheme(.dark)
    }
    var previewName: String { engine.sources.first { $0.id == engine.previewID }?.name ?? "Preview" }
    var programName: String { engine.sources.first { $0.id == engine.programID }?.name ?? "Program" }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        HStack(spacing: 8) {
            Text("LIVE").font(.system(size: 16, weight: .heavy)) + Text("DECK").font(.system(size: 16, weight: .heavy)).foregroundColor(cPreview)
            Divider().frame(height: 18)
            TBtn("Open") { engine.loadShow() }
            TBtn("Save") { engine.saveShow() }
            Spacer()
            TBtn("Fullscreen", tint: cProgram) { engine.openOutputWindow() }
            TBtn("STREAM", tint: .red).disabled(true).opacity(0.5)
            TBtn(engine.isRecording ? "● REC" : "REC", tint: .red, filled: engine.isRecording) { engine.toggleRecording() }
            Spacer()
            Text("\(engine.width)×\(engine.height)").font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            Menu {
                Button("720p") { engine.setResolution(width: 1280, height: 720) }
                Button("1080p") { engine.setResolution(width: 1920, height: 1080) }
            } label: { Image(systemName: "gearshape") }.frame(width: 34)
        }
        .padding(.horizontal, 12).frame(height: 44).background(cBar)
    }
}

struct TBtn: View {
    var title: String; var tint: Color = cBtn; var filled = false; var action: () -> Void = {}
    init(_ t: String, tint: Color = cBtn, filled: Bool = false, action: @escaping () -> Void = {}) {
        self.title = t; self.tint = tint; self.filled = filled; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(filled ? tint : cBtn)
                .foregroundColor(filled ? .white : (tint == cBtn ? .white : tint))
                .cornerRadius(4)
        }.buttonStyle(.plain)
    }
}

// MARK: - Monitors

struct MonitorPane: View {
    @EnvironmentObject var engine: Engine
    var title: String; var accent: Color; var isProgram: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isProgram ? title : title).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text(isProgram ? (engine.isRecording ? "REC" : "PGM") : "PRV")
                    .font(.system(size: 9, weight: .heavy)).foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8).frame(height: 22).background(accent)
            ZStack {
                if isProgram { ProgramMonitorView() } else { PreviewMonitorView() }
                if isProgram && engine.showSafeGuides {
                    GeometryReader { g in
                        Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .frame(width: g.size.width * 0.9, height: g.size.height * 0.9)
                            .position(x: g.size.width / 2, y: g.size.height / 2)
                    }.allowsHitTesting(false)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .background(Color.black)
        }
        .background(cPanel).overlay(Rectangle().stroke(accent, lineWidth: 2))
    }
}

struct ProgramMonitorView: NSViewRepresentable {
    @EnvironmentObject var engine: Engine
    func makeNSView(context: Context) -> FrameNSView { let v = FrameNSView(frame: .zero); engine.addConsumer(v); return v }
    func updateNSView(_ v: FrameNSView, context: Context) {}
}
struct PreviewMonitorView: NSViewRepresentable {
    @EnvironmentObject var engine: Engine
    func makeNSView(context: Context) -> FrameNSView { let v = FrameNSView(frame: .zero); engine.addPreviewConsumer(v); return v }
    func updateNSView(_ v: FrameNSView, context: Context) {}
}

// MARK: - Transition column

struct TransitionColumn: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(spacing: 6) {
            XBtn("Cut", color: cProgram) { engine.cut() }
            XBtn("Fade") { engine.quickTransition(.fade) }
            XBtn("Wipe") { engine.quickTransition(.wipe) }
            XBtn("Slide") { engine.quickTransition(.slide) }
            XBtn("Zoom") { engine.quickTransition(.zoom) }
            XBtn("FTB", color: engine.ftbOn ? .red : cBtn) { engine.toggleFTB() }
            Divider()
            VStack(spacing: 4) {
                Text("T-BAR").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                Slider(value: Binding(get: { engine.tbar }, set: { engine.setTBar($0) }), in: 0...1)
                Text("SPEED \(String(format: "%.1fs", engine.transitionDuration))").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                Slider(value: $engine.transitionDuration, in: 0.2...2.0)
            }
            VStack(spacing: 1) {
                Text(engine.clockText).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(cProgram)
                Text(String(format: "%02d:%02d:%02d", engine.recordSeconds / 3600, (engine.recordSeconds % 3600) / 60, engine.recordSeconds % 60))
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
            }
            .padding(6).frame(maxWidth: .infinity).background(Color.black).cornerRadius(4)
        }
        .frame(width: 96).padding(.vertical, 22)
    }
    func XBtn(_ t: String, color: Color = cBtn, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 11, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(color).foregroundColor(.white).cornerRadius(4)
        }.buttonStyle(.plain)
    }
}

// MARK: - Input bus

struct InputBus: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AddInputMenu()
                Text("INPUTS").font(.system(size: 9, weight: .heavy)).kerning(2).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8).frame(height: 22).background(cBar)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(engine.sources.enumerated()), id: \.element.id) { idx, src in
                        InputTile(index: idx + 1, source: src)
                    }
                }.padding(8)
            }
        }
        .background(cPanel)
    }
}

let videoFileTypes = ["public.movie", "public.video", "public.audiovisual-content",
                      "com.apple.quicktime-movie", "public.mpeg-4", "public.avi",
                      "public.mpeg", "public.mpeg-2-transport-stream",
                      "org.matroska.mkv", "com.microsoft.windows-media-wmv"]

struct InputAssignMenu<Label: View>: View {
    @EnvironmentObject var engine: Engine
    var slotID: UUID
    @ViewBuilder var label: () -> Label
    @State private var devices: [AVCaptureDevice] = []
    var body: some View {
        Menu {
            Menu("Cameras & Capture Devices") {
                ForEach(devices, id: \.uniqueID) { d in
                    Button(d.localizedName) { engine.replaceSource(slotID, with: CameraSource(device: d)) }
                }
                if devices.isEmpty { Text("No devices found") }
                Divider()
                Button("Refresh devices") { devices = VideoDevices.all() }
            }
            Button("Screen Capture") { engine.replaceSource(slotID, with: ScreenSource()) }
            Button("Video File…") { pickFile(types: videoFileTypes) { engine.replaceSource(slotID, with: FileSource(url: $0)) } }
            Button("Image…") { pickFile(types: ["public.image"]) { engine.replaceSource(slotID, with: ImageSource(url: $0)) } }
            Button("Colour") { engine.replaceSource(slotID, with: ColorSource()) }
        } label: { label() }
        .onAppear { if devices.isEmpty { devices = VideoDevices.all() } }
    }
}

struct InputTile: View {
    @EnvironmentObject var engine: Engine
    var index: Int
    @ObservedObject var source: Source
    var isProgram: Bool { engine.programID == source.id }
    var isPreview: Bool { engine.previewID == source.id }
    var border: Color { source.isPlaceholder ? Color(white: 0.22) : (isProgram ? .red : isPreview ? cProgram : Color(white: 0.25)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("\(index)").font(.system(size: 9, weight: .heavy))
                    .frame(width: 16, height: 16).background(border).cornerRadius(2)
                Text(source.isPlaceholder ? "Empty" : source.name).font(.system(size: 10))
                    .foregroundColor(source.isPlaceholder ? .secondary : .primary).lineLimit(1)
                Spacer()
                Button { engine.removeSource(source.id) } label: { Image(systemName: "xmark").font(.system(size: 8)) }
                    .buttonStyle(.plain).foregroundColor(.secondary)
            }
            .padding(.horizontal, 5).frame(height: 20).background(cBar)

            if source.isPlaceholder {
                InputAssignMenu(slotID: source.id) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle").font(.system(size: 22)).foregroundColor(Color(white: 0.4))
                        Text("Select input").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .frame(width: 176, height: 99).background(Color(white: 0.10))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundColor(Color(white: 0.3)))
                }
                .menuStyle(.borderlessButton)
                Color.clear.frame(height: 22)
            } else {
                SourceThumb(source: source)
                    .frame(width: 176, height: 99).background(Color.black)
                    .onTapGesture { engine.setPreview(source.id); engine.selectedSourceID = source.id }
                HStack(spacing: 4) {
                    Button("PGM") { engine.setPreview(source.id); engine.cut() }
                        .font(.system(size: 9, weight: .bold)).buttonStyle(.plain)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color(white: 0.18)).cornerRadius(3)
                    Spacer()
                    Button { source.muted.toggle() } label: {
                        Image(systemName: source.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 9))
                            .foregroundColor(source.muted ? .red : cProgram)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 5).frame(height: 22).background(cBar)
            }
        }
        .overlay(Rectangle().stroke(border, lineWidth: 2))
    }
}

struct SourceThumb: NSViewRepresentable {
    @ObservedObject var source: Source
    func makeNSView(context: Context) -> SourceThumbNSView { let v = SourceThumbNSView(frame: .zero); v.source = source; return v }
    func updateNSView(_ v: SourceThumbNSView, context: Context) { v.source = source }
}

struct AddInputMenu: View {
    @EnvironmentObject var engine: Engine
    @State private var devices: [AVCaptureDevice] = []
    var body: some View {
        Menu {
            Menu("Cameras & Capture Devices") {
                ForEach(devices, id: \.uniqueID) { d in Button(d.localizedName) { engine.addCamera(d) } }
                if devices.isEmpty { Text("No devices found") }
                Divider()
                Button("Refresh devices") { devices = VideoDevices.all() }
            }
            Button("Screen Capture") { engine.addScreen() }
            Button("Video File…") { pickFile(types: videoFileTypes) { engine.addFile(url: $0) } }
            Button("Image…") { pickFile(types: ["public.image"]) { engine.addImage(url: $0) } }
            Button("Colour") { engine.addColor() }
            Divider()
            Button("Blank Input") { engine.addBlankInput() }
        } label: {
            Text("Add Input").font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8).padding(.vertical, 3).background(cProgram).foregroundColor(.white).cornerRadius(3)
        }
        .menuStyle(.borderlessButton).fixedSize()
        .onAppear { if devices.isEmpty { devices = VideoDevices.all() } }
    }
}

// MARK: - Right panel (Audio Mixer / Overlays)

struct RightPanel: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $engine.rightTab) {
                Text("Audio").tag(0); Text("Input").tag(1); Text("Overlays").tag(2)
            }.pickerStyle(.segmented).padding(8)
            Divider()
            if engine.rightTab == 0 { AudioMixerPanel() }
            else if engine.rightTab == 1 { InputSettingsPanel() }
            else { OverlaysPanel() }
        }
        .background(cPanel).overlay(Rectangle().frame(width: 1).foregroundColor(Color(white: 0.2)), alignment: .leading)
    }
}

// Shared labelled slider for adjustments
@ViewBuilder
func adjSlider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        HStack {
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.2f", value.wrappedValue)).font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
        }
        Slider(value: value, in: range)
    }
}

struct InputSettingsPanel: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        ScrollView {
            if let s = engine.sources.first(where: { $0.id == engine.selectedSourceID }) {
                InputAdjust(source: s)
            } else {
                Text("Tap an input's thumbnail to adjust its zoom, pan, rotation, crop, colour and audio here.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(12)
            }
        }
    }
}

struct InputAdjust: View {
    @ObservedObject var source: Source
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(source.name.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(1).foregroundColor(cPreview).lineLimit(1)
                Spacer()
                Button("Reset") { source.resetAdjustments() }.font(.system(size: 10))
            }
            Text("GEOMETRY").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
            adjSlider("Zoom", $source.zoom, 0.2...4)
            adjSlider("Pan X", $source.panX, -1...1)
            adjSlider("Pan Y", $source.panY, -1...1)
            adjSlider("Rotate", $source.rotation, -180...180)
            Divider()
            Text("CROP").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
            adjSlider("Left", $source.cropL, 0...0.45)
            adjSlider("Right", $source.cropR, 0...0.45)
            adjSlider("Top", $source.cropT, 0...0.45)
            adjSlider("Bottom", $source.cropB, 0...0.45)
            Divider()
            Text("COLOUR").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
            adjSlider("Brightness", $source.brightness, -0.5...0.5)
            adjSlider("Contrast", $source.contrast, 0...2)
            adjSlider("Saturation", $source.saturation, 0...2)
            Divider()
            Text("AUDIO").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
            adjSlider("Gain", $source.gain, 0...1.5)
            Toggle("Mute", isOn: $source.muted).font(.system(size: 11))
        }
        .padding(12)
    }
}

struct AudioMixerPanel: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                MasterStrip(label: "MASTER", level: engine.audioLevel)
                MasterStrip(label: "RECORDING", level: engine.isRecording ? engine.audioLevel : 0)
                Divider()
                ForEach(engine.sources.filter { !$0.isPlaceholder }) { s in
                    ChannelStrip(source: s, level: engine.programID == s.id ? engine.audioLevel : 0)
                }
                Text("Faders & mutes are stored per input. Recorded audio is the selected input device; full multi-source mixing is the next milestone.")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }.padding(10)
        }
    }
}

struct MasterStrip: View {
    var label: String; var level: Float
    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 10, weight: .bold)).frame(width: 80, alignment: .leading)
            AudioMeter(level: level).frame(height: 14)
        }
    }
}

struct ChannelStrip: View {
    @ObservedObject var source: Source
    var level: Float
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(source.name).font(.system(size: 10)).lineLimit(1)
                Spacer()
                Button { source.muted.toggle() } label: {
                    Text("M").font(.system(size: 9, weight: .heavy))
                        .frame(width: 18, height: 16)
                        .background(source.muted ? Color.red : Color(white: 0.2)).cornerRadius(3)
                }.buttonStyle(.plain)
            }
            AudioMeter(level: source.muted ? 0 : level).frame(height: 10)
            Slider(value: $source.gain, in: 0...1.5)
        }
        .padding(6).background(Color(white: 0.11)).cornerRadius(5)
    }
}

struct AudioMeter: View {
    var level: Float
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fill = CGFloat(min(1, max(0, level))) * w
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.6))
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [.green, .green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fill)
            }
        }
    }
}

struct OverlaysPanel: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("OVERLAY CHANNELS / LAYERS").font(.system(size: 9, weight: .heavy)).kerning(1).foregroundColor(.secondary)
                Spacer()
                Menu {
                    ForEach(Layer.Kind.allCases) { k in Button { engine.addLayer(k) } label: { Label(k.rawValue, systemImage: k.icon) } }
                } label: { Image(systemName: "plus.circle.fill").foregroundColor(cPreview) }
                .menuStyle(.borderlessButton).frame(width: 28)
            }.padding(.horizontal, 10).padding(.vertical, 6)
            List { ForEach(engine.layers) { l in LayerRow(layer: l) } }.listStyle(.plain).frame(maxHeight: 220)
            Divider()
            ScrollView {
                if let sel = engine.layers.first(where: { $0.id == engine.selectedLayerID }) { LayerInspector(layer: sel) }
                else { Text("Select a layer to edit it.").font(.system(size: 11)).foregroundColor(.secondary).padding(12) }
            }
        }
    }
}

struct LayerRow: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var layer: Layer
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: layer.kind.icon).frame(width: 18)
            Text(layer.name).font(.system(size: 12)).lineLimit(1)
            Spacer()
            VStack(spacing: 0) {
                Button { engine.moveLayer(layer.id, by: -1) } label: { Image(systemName: "chevron.up").font(.system(size: 7)) }.buttonStyle(.borderless)
                Button { engine.moveLayer(layer.id, by: 1) } label: { Image(systemName: "chevron.down").font(.system(size: 7)) }.buttonStyle(.borderless)
            }
            Toggle("", isOn: $layer.isLive).toggleStyle(.switch).tint(.red).labelsHidden()
            Button { engine.removeLayer(layer.id) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                .buttonStyle(.borderless).foregroundColor(.secondary)
        }
        .padding(.vertical, 2).contentShape(Rectangle())
        .onTapGesture { engine.selectedLayerID = layer.id }
        .background(engine.selectedLayerID == layer.id ? cPreview.opacity(0.12) : Color.clear)
    }
}

// MARK: - Status bar

struct StatusBar: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        HStack(spacing: 12) {
            Text("\(engine.height)p\(engine.fps == 60 ? "60" : "30")").font(.system(size: 10, design: .monospaced))
            Text("FPS \(engine.fps)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            Text("Render —").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
            Spacer()
            ForEach(0..<4) { i in
                Button { engine.toggleOverlay(i) } label: {
                    Text("\(i + 1)").font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 18)
                        .background(engine.layers.indices.contains(i) && engine.layers[i].isLive ? cPreview : Color(white: 0.18))
                        .cornerRadius(3)
                }.buttonStyle(.plain).help("Toggle overlay channel \(i + 1)")
            }
            SBtn("Record", color: engine.isRecording ? .red : cBtn) { engine.toggleRecording() }
            SBtn("Stream", color: cBtn).opacity(0.5)
            SBtn("Snapshot") { engine.snapshot() }
            SBtn("Multiview") { engine.openMultiviewWindow() }
            Toggle("Guides", isOn: $engine.showSafeGuides).toggleStyle(.button).font(.system(size: 10))
        }
        .padding(.horizontal, 12).frame(height: 30).background(cBar)
    }
    func SBtn(_ t: String, color: Color = cBtn, _ action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 10, weight: .semibold)).padding(.horizontal, 9).padding(.vertical, 3)
                .background(color).foregroundColor(.white).cornerRadius(3)
        }.buttonStyle(.plain)
    }
}

// MARK: - Inspector + variants

struct LayerInspector: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var layer: Layer
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(layer.kind.rawValue.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(1.5).foregroundColor(cPreview)
                Spacer()
                Circle().fill(layer.isLive ? Color.red : Color(white: 0.3)).frame(width: 9, height: 9)
            }
            TextField("Layer name", text: $layer.name)
            VariantsView(layer: layer)
            LayerTransformView(layer: layer)
            Divider()
            switch layer.kind {
            case .lowerThird:
                TextField("Name line", text: $layer.text1); TextField("Title line", text: $layer.text2)
                Picker("Style", selection: $layer.style) { Text("Accent strip").tag(0); Text("Boxed").tag(1); Text("Minimal").tag(2) }
                ColorPicker("Accent", selection: $layer.accent)
            case .ticker:
                TextField("Ticker text", text: $layer.text1)
                HStack { Text("Speed").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 20...300) }
            case .countdown:
                TextField("Label", text: $layer.text1)
                HStack { Text("Minutes").font(.system(size: 11)).foregroundColor(.secondary); TextField("", value: $layer.number1, formatter: NumberFormatter()).frame(width: 60) }
                HStack(spacing: 8) {
                    Button("Start") { if layer.remaining <= 0 { layer.remaining = layer.number1 * 60 }; layer.lastTick = 0; layer.isRunning = true }
                    Button("Pause") { layer.isRunning = false }
                    Button("Reset") { layer.isRunning = false; layer.remaining = layer.number1 * 60 }
                }
                ColorPicker("Accent", selection: $layer.accent)
            case .clock:
                Toggle("24-hour", isOn: $layer.use24h)
            case .scoreboard:
                TextField("Team A", text: $layer.text1); TextField("Team B", text: $layer.text2)
                ColorPicker("Team A color", selection: $layer.accent)
                HStack(spacing: 8) {
                    Button("A +1") { layer.scoreA += 1 }; Button("A −1") { layer.scoreA = max(0, layer.scoreA - 1) }
                    Button("B +1") { layer.scoreB += 1 }; Button("B −1") { layer.scoreB = max(0, layer.scoreB - 1) }
                }
            case .title:
                TextField("Text", text: $layer.text1)
                HStack { Text("Size").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 3...20) }
                ColorPicker("Color", selection: $layer.accent)
            case .logo:
                Button("Choose image…") {
                    pickFile(types: ["public.image"]) { url in
                        if let nsimg = NSImage(contentsOf: url) {
                            var rect = CGRect(origin: .zero, size: nsimg.size)
                            layer.logoImage = nsimg.cgImage(forProposedRect: &rect, context: nil, hints: nil)
                        }
                    }
                }
                Picker("Position", selection: $layer.position) { Text("Top left").tag(0); Text("Top right").tag(1); Text("Bottom left").tag(2); Text("Bottom right").tag(3) }
                HStack { Text("Scale").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 4...50) }
            case .qrcode:
                TextField("URL", text: $layer.text1)
                HStack { Text("Size").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 80...360) }
            case .pip:
                Picker("Source", selection: Binding(get: { layer.sourceRef ?? pipNoneTag }, set: { layer.sourceRef = ($0 == pipNoneTag ? nil : $0) })) {
                    Text("— none —").tag(pipNoneTag)
                    ForEach(engine.sources) { s in Text(s.name).tag(s.id) }
                }
                Picker("Corner", selection: $layer.position) { Text("Top left").tag(0); Text("Top right").tag(1); Text("Bottom left").tag(2); Text("Bottom right").tag(3) }
                HStack { Text("Size").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 8...50) }
                ColorPicker("Border", selection: $layer.accent)
            }
        }
        .textFieldStyle(.roundedBorder).padding(12)
    }
}

struct VariantsView: View {
    @ObservedObject var layer: Layer
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("VARIANTS").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
                Spacer()
                Button { layer.captureVariant() } label: { Image(systemName: "plus") }.buttonStyle(.borderless).help("Save current as variant")
                Button { layer.cycleVariant(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.borderless)
                Button { layer.cycleVariant(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless)
            }
            if layer.variants.isEmpty {
                Text("Save reusable states (e.g. each speaker) and switch live.").font(.system(size: 9)).foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(layer.variants.enumerated()), id: \.element.id) { idx, v in
                            Button { layer.applyVariant(idx) } label: {
                                Text(v.text1.isEmpty ? v.name : v.text1).font(.system(size: 10)).lineLimit(1)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(layer.activeVariant == idx ? cPreview.opacity(0.3) : Color(white: 0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(layer.activeVariant == idx ? cPreview : Color(white: 0.25), lineWidth: 1))
                                    .cornerRadius(5)
                            }.buttonStyle(.plain)
                            .contextMenu { Button("Delete", role: .destructive) { if layer.variants.indices.contains(idx) { layer.variants.remove(at: idx) } } }
                        }
                    }
                }
            }
        }
    }
}

struct LayerTransformView: View {
    @ObservedObject var layer: Layer
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TRANSFORM").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
                Spacer()
                Button("Reset") { layer.resetTransform() }.font(.system(size: 10))
            }
            adjSlider("Opacity", $layer.opacity, 0...1)
            adjSlider("Pos X", $layer.offsetX, -0.5...0.5)
            adjSlider("Pos Y", $layer.offsetY, -0.5...0.5)
            adjSlider("Scale", $layer.scaleAdj, 0.2...3)
            adjSlider("Rotate", $layer.rotationAdj, -180...180)
        }
    }
}

// MARK: - File picker

func pickFile(types: [String], completion: @escaping (URL) -> Void) {
    let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
    panel.allowedContentTypes = types.compactMap { UTType($0) }
    panel.begin { resp in if resp == .OK, let url = panel.url { completion(url) } }
}
