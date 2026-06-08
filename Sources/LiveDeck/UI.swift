import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

private let pipNoneTag = UUID()

struct MainView: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        HSplitView {
            SourcesPanel().frame(minWidth: 240, idealWidth: 270, maxWidth: 340)
            CenterPanel().frame(minWidth: 480)
            LayersPanel().frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
        .background(Color(red: 0.05, green: 0.055, blue: 0.07))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sources

struct SourcesPanel: View {
    @EnvironmentObject var engine: Engine
    @State private var cameras: [AVCaptureDevice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SOURCES").font(.system(size: 12, weight: .heavy)).kerning(2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)

            HStack(spacing: 6) {
                Menu {
                    ForEach(cameras, id: \.uniqueID) { dev in
                        Button(dev.localizedName) { engine.addCamera(dev) }
                    }
                    if cameras.isEmpty { Text("No cameras found") }
                } label: { Label("Camera", systemImage: "video") }
                .menuStyle(.borderlessButton)
                .onAppear { refreshCameras() }
                Button { engine.addScreen() } label: { Label("Screen", systemImage: "rectangle.on.rectangle") }
            }
            .padding(.horizontal, 12).padding(.bottom, 4)

            HStack(spacing: 6) {
                Button { pickFile(types: ["public.movie"]) { engine.addFile(url: $0) } } label: { Label("Video", systemImage: "film") }
                Button { pickFile(types: ["public.image"]) { engine.addImage(url: $0) } } label: { Label("Image", systemImage: "photo") }
                Button { engine.addColor() } label: { Label("Color", systemImage: "paintpalette") }
            }
            .padding(.horizontal, 12).padding(.bottom, 10)

            Divider()
            List { ForEach(engine.sources) { src in SourceRow(source: src) } }
                .listStyle(.plain)

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("SHOW").font(.system(size: 10, weight: .heavy)).kerning(2).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Button { engine.saveShow() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    Button { engine.loadShow() } label: { Label("Load", systemImage: "square.and.arrow.up") }
                }
            }
            .padding(10)
        }
    }

    private func refreshCameras() {
        cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video, position: .unspecified).devices
    }
}

struct SourceRow: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var source: Source
    var onAir: Bool { engine.programID == source.id }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.kindLabel).font(.system(size: 8, weight: .bold)).kerning(1)
                    .foregroundColor(onAir ? .red : .orange)
                Text(source.name).font(.system(size: 12)).lineLimit(1)
            }
            Spacer()
            if onAir {
                Text("ON AIR").font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.red).cornerRadius(3)
            } else {
                Button("TAKE") { engine.take(source.id) }.font(.system(size: 10, weight: .bold))
            }
            Button { engine.removeSource(source.id) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                .buttonStyle(.borderless).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Center

struct CenterPanel: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ProgramPreview().aspectRatio(16.0 / 9.0, contentMode: .fit).padding(16)

                // Safe-area guides
                if engine.showSafeGuides {
                    GeometryReader { geo in
                        let w = geo.size.width, h = geo.size.height
                        Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .frame(width: w * 0.9, height: h * 0.9)
                            .position(x: w / 2, y: h / 2)
                        Rectangle().stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            .frame(width: w * 0.8, height: h * 0.8)
                            .position(x: w / 2, y: h / 2)
                    }
                    .padding(16).allowsHitTesting(false)
                }

                // Program bar (top): resolution + fps + activity dot
                VStack {
                    HStack(spacing: 8) {
                        Circle().fill(engine.isRecording ? Color.red : Color.green)
                            .frame(width: 9, height: 9)
                        Text(engine.isRecording ? "LIVE • REC" : "PROGRAM")
                            .font(.system(size: 10, weight: .bold)).kerning(1.5)
                        Spacer()
                        Text("\(engine.width)×\(engine.height)  •  \(engine.fps) fps")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 26).padding(.top, 22)
                    Spacer()
                }

                // Audio level meter (right edge)
                HStack {
                    Spacer()
                    AudioMeter(level: engine.audioLevel)
                        .frame(width: 8).padding(.trailing, 24).padding(.vertical, 40)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack(spacing: 14) {
                Button { engine.toggleRecording() } label: {
                    Label(engine.isRecording ? "STOP" : "REC",
                          systemImage: engine.isRecording ? "stop.fill" : "record.circle")
                        .foregroundColor(engine.isRecording ? .white : .red)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .tint(engine.isRecording ? .red : Color(white: 0.18))

                if engine.isRecording {
                    Text(String(format: "%02d:%02d", engine.recordSeconds / 60, engine.recordSeconds % 60))
                        .font(.system(.body, design: .monospaced).weight(.bold)).foregroundColor(.red)
                }

                Button { engine.openMultiviewWindow() } label: { Label("Multiview", systemImage: "rectangle.grid.2x2") }
                Toggle("Guides", isOn: $engine.showSafeGuides).toggleStyle(.button).font(.system(size: 11))

                Spacer()

                Picker("", selection: Binding(
                    get: { engine.height >= 1080 ? "1080p" : "720p" },
                    set: { engine.setResolution(width: $0 == "1080p" ? 1920 : 1280,
                                                height: $0 == "1080p" ? 1080 : 720) })) {
                    Text("720p").tag("720p"); Text("1080p").tag("1080p")
                }
                .pickerStyle(.segmented).frame(width: 130).disabled(engine.isRecording)

                Picker("", selection: Binding(
                    get: { engine.selectedAudioDeviceID ?? "" },
                    set: { engine.setAudioDevice($0.isEmpty ? nil : $0) })) {
                    Text("Default mic").tag("")
                    ForEach(engine.audioDevices) { d in Text(d.name).tag(d.id) }
                }
                .frame(maxWidth: 160).help("Recording / metering audio input")

                Toggle("Crossfade", isOn: $engine.useFade).toggleStyle(.switch).font(.system(size: 11))
            }
            .padding(12)

            Divider()
            OutputDestinations()
        }
    }
}

struct ProgramPreview: NSViewRepresentable {
    @EnvironmentObject var engine: Engine
    func makeNSView(context: Context) -> FrameNSView { let v = FrameNSView(frame: .zero); engine.addConsumer(v); return v }
    func updateNSView(_ nsView: FrameNSView, context: Context) {}
}

struct AudioMeter: View {
    var level: Float   // 0...1
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let fill = CGFloat(min(1, max(0, level))) * h
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.5))
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [.green, .green, .yellow, .red],
                                         startPoint: .bottom, endPoint: .top))
                    .frame(height: fill)
            }
        }
    }
}

struct OutputDestinations: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OUTPUT DESTINATIONS").font(.system(size: 10, weight: .heavy)).kerning(2)
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                DestChip(title: "Record (MP4)", system: "record.circle",
                         active: engine.fileOutputActive, enabled: true) { engine.toggleRecording() }
                DestChip(title: "Program Window", system: "rectangle.expand.vertical",
                         active: engine.programWindowActive, enabled: true) { engine.openOutputWindow() }
                DestChip(title: "Still Image", system: "camera",
                         active: false, enabled: true) { engine.snapshot() }
                DestChip(title: "Live Stream", system: "dot.radiowaves.left.and.right",
                         active: false, enabled: false) {}
                DestChip(title: "NDI / Syphon", system: "antenna.radiowaves.left.and.right",
                         active: false, enabled: false) {}
                DestChip(title: "Virtual Camera", system: "camera.metering.center.weighted",
                         active: false, enabled: false) {}
            }
            Text("Greyed destinations require licensed SDKs (NDI/Syphon/virtual camera) or a streaming relay — planned for a later version.")
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

struct DestChip: View {
    var title: String; var system: String; var active: Bool; var enabled: Bool; var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system).font(.system(size: 14))
                Text(title).font(.system(size: 9)).lineLimit(1)
            }
            .frame(width: 86, height: 46)
            .background(active ? Color.red.opacity(0.25) : Color(white: 0.12))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(active ? Color.red : Color(white: 0.22), lineWidth: 1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Layers

struct LayersPanel: View {
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("LAYERS").font(.system(size: 12, weight: .heavy)).kerning(2).foregroundColor(.secondary)
                Spacer()
                Menu {
                    ForEach(Layer.Kind.allCases) { kind in
                        Button { engine.addLayer(kind) } label: { Label(kind.rawValue, systemImage: kind.icon) }
                    }
                } label: { Image(systemName: "plus.circle.fill").foregroundColor(.orange) }
                .menuStyle(.borderlessButton).frame(width: 30)
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)

            if engine.layers.isEmpty {
                Text("Add graphics with ＋. Top of the list renders in front.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(12)
            }

            List { ForEach(engine.layers) { layer in LayerRow(layer: layer) } }
                .listStyle(.plain).frame(maxHeight: 260)

            Divider()
            ScrollView {
                if let sel = engine.layers.first(where: { $0.id == engine.selectedLayerID }) {
                    LayerInspector(layer: sel)
                } else {
                    Text("Select a layer to edit it.").font(.system(size: 11)).foregroundColor(.secondary).padding(12)
                }
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
        .background(engine.selectedLayerID == layer.id ? Color.orange.opacity(0.12) : Color.clear)
    }
}

struct LayerInspector: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var layer: Layer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(layer.kind.rawValue.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(1.5).foregroundColor(.orange)
                Spacer()
                Circle().fill(layer.isLive ? Color.red : Color(white: 0.3)).frame(width: 9, height: 9)
            }
            TextField("Layer name", text: $layer.name)

            VariantsView(layer: layer)
            Divider()
            switch layer.kind {
            case .lowerThird:
                TextField("Name line", text: $layer.text1)
                TextField("Title line", text: $layer.text2)
                Picker("Style", selection: $layer.style) {
                    Text("Accent strip").tag(0); Text("Boxed").tag(1); Text("Minimal").tag(2)
                }
                ColorPicker("Accent", selection: $layer.accent)

            case .ticker:
                TextField("Ticker text", text: $layer.text1)
                HStack { Text("Speed").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 20...300) }

            case .countdown:
                TextField("Label", text: $layer.text1)
                HStack {
                    Text("Minutes").font(.system(size: 11)).foregroundColor(.secondary)
                    TextField("", value: $layer.number1, formatter: NumberFormatter()).frame(width: 60)
                }
                HStack(spacing: 8) {
                    Button("Start") { if layer.remaining <= 0 { layer.remaining = layer.number1 * 60 }; layer.lastTick = 0; layer.isRunning = true }
                    Button("Pause") { layer.isRunning = false }
                    Button("Reset") { layer.isRunning = false; layer.remaining = layer.number1 * 60 }
                }
                ColorPicker("Accent", selection: $layer.accent)

            case .clock:
                Toggle("24-hour", isOn: $layer.use24h)

            case .scoreboard:
                TextField("Team A", text: $layer.text1)
                TextField("Team B", text: $layer.text2)
                ColorPicker("Team A color", selection: $layer.accent)
                HStack(spacing: 8) {
                    Button("A +1") { layer.scoreA += 1 }; Button("A −1") { layer.scoreA = max(0, layer.scoreA - 1) }
                    Button("B +1") { layer.scoreB += 1 }; Button("B −1") { layer.scoreB = max(0, layer.scoreB - 1) }
                }
                Text("\(layer.text1) \(layer.scoreA) : \(layer.scoreB) \(layer.text2)").font(.system(size: 11)).foregroundColor(.secondary)

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
                Picker("Position", selection: $layer.position) {
                    Text("Top left").tag(0); Text("Top right").tag(1); Text("Bottom left").tag(2); Text("Bottom right").tag(3)
                }
                HStack { Text("Scale").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 4...50) }

            case .qrcode:
                TextField("URL", text: $layer.text1)
                HStack { Text("Size").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 80...360) }

            case .pip:
                Picker("Source", selection: Binding(
                    get: { layer.sourceRef ?? pipNoneTag },
                    set: { layer.sourceRef = ($0 == pipNoneTag ? nil : $0) })) {
                    Text("— none —").tag(pipNoneTag)
                    ForEach(engine.sources) { s in Text(s.name).tag(s.id) }
                }
                Picker("Corner", selection: $layer.position) {
                    Text("Top left").tag(0); Text("Top right").tag(1); Text("Bottom left").tag(2); Text("Bottom right").tag(3)
                }
                HStack { Text("Size").font(.system(size: 11)).foregroundColor(.secondary); Slider(value: $layer.number1, in: 8...50) }
                ColorPicker("Border", selection: $layer.accent)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(12)
    }
}

// MARK: - Variants (mimoLive-style)

struct VariantsView: View {
    @ObservedObject var layer: Layer
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("VARIANTS").font(.system(size: 9, weight: .heavy)).kerning(1.5).foregroundColor(.secondary)
                Spacer()
                Button { layer.captureVariant() } label: { Image(systemName: "plus") }.buttonStyle(.borderless)
                    .help("Save current settings as a variant")
                Button { layer.cycleVariant(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.borderless)
                Button { layer.cycleVariant(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless)
            }
            if layer.variants.isEmpty {
                Text("Save reusable states (e.g. each speaker's name) and switch them live.")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(layer.variants.enumerated()), id: \.element.id) { idx, v in
                            Button { layer.applyVariant(idx) } label: {
                                Text(v.text1.isEmpty ? v.name : v.text1)
                                    .font(.system(size: 10)).lineLimit(1)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(layer.activeVariant == idx ? Color.orange.opacity(0.3) : Color(white: 0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(layer.activeVariant == idx ? Color.orange : Color(white: 0.25), lineWidth: 1))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    if layer.variants.indices.contains(idx) { layer.variants.remove(at: idx) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - File picker

func pickFile(types: [String], completion: @escaping (URL) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = types.compactMap { UTType($0) }
    panel.begin { resp in if resp == .OK, let url = panel.url { completion(url) } }
}
