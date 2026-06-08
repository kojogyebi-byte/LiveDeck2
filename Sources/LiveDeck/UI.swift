import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Main layout

struct MainView: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        HSplitView {
            SourcesPanel()
                .frame(minWidth: 240, idealWidth: 270, maxWidth: 340)
            CenterPanel()
                .frame(minWidth: 480)
            LayersPanel()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
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
            Text("SOURCES")
                .font(.system(size: 12, weight: .heavy))
                .kerning(2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)

            HStack(spacing: 6) {
                Menu {
                    ForEach(cameras, id: \.uniqueID) { dev in
                        Button(dev.localizedName) { engine.addCamera(dev) }
                    }
                    if cameras.isEmpty { Text("No cameras found") }
                } label: {
                    Label("Camera", systemImage: "video")
                }
                .menuStyle(.borderlessButton)
                .onAppear { refreshCameras() }

                Button { engine.addScreen() } label: { Label("Screen", systemImage: "rectangle.on.rectangle") }
            }
            .padding(.horizontal, 12).padding(.bottom, 4)

            HStack(spacing: 6) {
                Button { pickFile(types: ["public.movie"]) { engine.addFile(url: $0) } } label: {
                    Label("Video", systemImage: "film")
                }
                Button { pickFile(types: ["public.image"]) { engine.addImage(url: $0) } } label: {
                    Label("Image", systemImage: "photo")
                }
                Button { engine.addColor() } label: { Label("Color", systemImage: "paintpalette") }
            }
            .padding(.horizontal, 12).padding(.bottom, 10)

            Divider()

            List {
                ForEach(engine.sources) { src in
                    SourceRow(source: src)
                }
            }
            .listStyle(.plain)

            Text("TAKE switches the Program output. Recording audio comes from the default microphone (set it in System Settings → Sound).")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(10)
        }
    }

    private func refreshCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video, position: .unspecified)
        cameras = discovery.devices
    }
}

struct SourceRow: View {
    @EnvironmentObject var engine: Engine
    @ObservedObject var source: Source

    var onAir: Bool { engine.programID == source.id }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.kindLabel)
                    .font(.system(size: 8, weight: .bold))
                    .kerning(1)
                    .foregroundColor(onAir ? .red : .orange)
                Text(source.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            Spacer()
            if onAir {
                Text("ON AIR")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.red).cornerRadius(3)
            } else {
                Button("TAKE") { engine.take(source.id) }
                    .font(.system(size: 10, weight: .bold))
            }
            Button { engine.removeSource(source.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Center: preview + transport

struct CenterPanel: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ProgramPreview()
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .padding(16)
                Text("PROGRAM")
                    .font(.system(size: 10, weight: .bold)).kerning(2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20).padding(.top, 4)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack(spacing: 14) {
                Button {
                    engine.toggleRecording()
                } label: {
                    Label(engine.isRecording ? "STOP" : "REC",
                          systemImage: engine.isRecording ? "stop.fill" : "record.circle")
                        .foregroundColor(engine.isRecording ? .white : .red)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .tint(engine.isRecording ? .red : Color(white: 0.18))

                if engine.isRecording {
                    Text(String(format: "%02d:%02d", engine.recordSeconds / 60, engine.recordSeconds % 60))
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundColor(.red)
                }

                Button { engine.snapshot() } label: { Label("Snapshot", systemImage: "camera") }

                Button { engine.openOutputWindow() } label: {
                    Label("Output Window", systemImage: "rectangle.expand.vertical")
                }

                Spacer()

                Toggle("Crossfade", isOn: $engine.useFade)
                    .toggleStyle(.switch)
                    .font(.system(size: 11))
            }
            .padding(12)
        }
    }
}

struct ProgramPreview: NSViewRepresentable {
    @EnvironmentObject var engine: Engine

    func makeNSView(context: Context) -> FrameNSView {
        let v = FrameNSView(frame: .zero)
        engine.addConsumer(v)
        return v
    }

    func updateNSView(_ nsView: FrameNSView, context: Context) {}
}

// MARK: - Layers panel

struct LayersPanel: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("LAYERS")
                    .font(.system(size: 12, weight: .heavy)).kerning(2)
                    .foregroundColor(.secondary)
                Spacer()
                Menu {
                    ForEach(Layer.Kind.allCases) { kind in
                        Button { engine.addLayer(kind) } label: {
                            Label(kind.rawValue, systemImage: kind.icon)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.orange)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)

            if engine.layers.isEmpty {
                Text("Add lower thirds, tickers, countdowns, scoreboards, QR codes and more with ＋. Top of the list renders in front.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(12)
            }

            List {
                ForEach(engine.layers) { layer in
                    LayerRow(layer: layer)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 260)

            Divider()

            ScrollView {
                if let sel = engine.layers.first(where: { $0.id == engine.selectedLayerID }) {
                    LayerInspector(layer: sel)
                } else {
                    Text("Select a layer to edit it.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .padding(12)
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
                Button { engine.moveLayer(layer.id, by: -1) } label: {
                    Image(systemName: "chevron.up").font(.system(size: 7))
                }.buttonStyle(.borderless)
                Button { engine.moveLayer(layer.id, by: 1) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 7))
                }.buttonStyle(.borderless)
            }
            Toggle("", isOn: $layer.isLive)
                .toggleStyle(.switch)
                .tint(.red)
                .labelsHidden()
            Button { engine.removeLayer(layer.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9))
            }
            .buttonStyle(.borderless).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { engine.selectedLayerID = layer.id }
        .background(engine.selectedLayerID == layer.id ? Color.orange.opacity(0.12) : Color.clear)
    }
}

// MARK: - Inspector

struct LayerInspector: View {
    @ObservedObject var layer: Layer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(layer.kind.rawValue.uppercased())
                .font(.system(size: 11, weight: .heavy)).kerning(1.5)
                .foregroundColor(.orange)

            TextField("Layer name", text: $layer.name)

            switch layer.kind {
            case .lowerThird:
                TextField("Name line", text: $layer.text1)
                TextField("Title line", text: $layer.text2)
                ColorPicker("Accent", selection: $layer.accent)

            case .ticker:
                TextField("Ticker text", text: $layer.text1)
                HStack {
                    Text("Speed").font(.system(size: 11)).foregroundColor(.secondary)
                    Slider(value: $layer.number1, in: 20...300)
                }

            case .countdown:
                TextField("Label", text: $layer.text1)
                HStack {
                    Text("Minutes").font(.system(size: 11)).foregroundColor(.secondary)
                    TextField("", value: $layer.number1, formatter: NumberFormatter())
                        .frame(width: 60)
                }
                HStack(spacing: 8) {
                    Button("Start") {
                        if layer.remaining <= 0 { layer.remaining = layer.number1 * 60 }
                        layer.lastTick = 0
                        layer.isRunning = true
                    }
                    Button("Pause") { layer.isRunning = false }
                    Button("Reset") {
                        layer.isRunning = false
                        layer.remaining = layer.number1 * 60
                    }
                }
                ColorPicker("Accent", selection: $layer.accent)

            case .clock:
                Toggle("24-hour", isOn: $layer.use24h)

            case .scoreboard:
                TextField("Team A", text: $layer.text1)
                TextField("Team B", text: $layer.text2)
                ColorPicker("Team A color", selection: $layer.accent)
                HStack(spacing: 8) {
                    Button("A +1") { layer.scoreA += 1 }
                    Button("A −1") { layer.scoreA = max(0, layer.scoreA - 1) }
                    Button("B +1") { layer.scoreB += 1 }
                    Button("B −1") { layer.scoreB = max(0, layer.scoreB - 1) }
                }
                Text("\(layer.text1) \(layer.scoreA) : \(layer.scoreB) \(layer.text2)")
                    .font(.system(size: 11)).foregroundColor(.secondary)

            case .title:
                TextField("Text", text: $layer.text1)
                HStack {
                    Text("Size").font(.system(size: 11)).foregroundColor(.secondary)
                    Slider(value: $layer.number1, in: 3...20)
                }
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
                    Text("Top left").tag(0)
                    Text("Top right").tag(1)
                    Text("Bottom left").tag(2)
                    Text("Bottom right").tag(3)
                }
                HStack {
                    Text("Scale").font(.system(size: 11)).foregroundColor(.secondary)
                    Slider(value: $layer.number1, in: 4...50)
                }

            case .qrcode:
                TextField("URL", text: $layer.text1)
                HStack {
                    Text("Size").font(.system(size: 11)).foregroundColor(.secondary)
                    Slider(value: $layer.number1, in: 80...360)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(12)
    }
}

// MARK: - File picker helper

func pickFile(types: [String], completion: @escaping (URL) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = types.compactMap { UTType($0) }
    panel.begin { resp in
        if resp == .OK, let url = panel.url { completion(url) }
    }
}
