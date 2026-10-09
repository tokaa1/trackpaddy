import AppKit
import Cocoa
import SwiftUI

private enum Metrics {
    static let width: CGFloat = 320
    static let gutter: CGFloat = 14
    static let rowSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 10
    static let cardRadius: CGFloat = 10
}

enum Corner {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

struct GridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 1..<3 {
            let x = rect.width * CGFloat(i) / 3
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
            let y = rect.height * CGFloat(i) / 3
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return p
    }
}

struct Section<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.sectionSpacing)
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    var symbol: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            Text(title)
                .font(.system(size: 13))
            Spacer(minLength: 8)
            control
        }
    }
}

struct NumberField<V: BinaryFloatingPoint, F: Hashable>: View {
    @Binding var value: V
    var format: String = "%g"
    var focusedField: FocusState<F?>.Binding
    var fieldId: F
    var range: ClosedRange<V>? = nil
    var width: CGFloat = 64

    @State private var text: String = ""

    private var isFocused: Bool { focusedField.wrappedValue == fieldId }

    private func clamp(_ v: V) -> V {
        guard let range = range else { return v }
        return min(max(v, range.lowerBound), range.upperBound)
    }

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .controlSize(.small)
            .frame(width: width)
            .focused(focusedField, equals: fieldId)
            .onAppear { text = String(format: format, Double(value)) }
            .onChange(of: text) { _, newValue in
                if let d = Double(newValue) {
                    value = clamp(V(d))
                }
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    text = String(format: format, Double(newValue))
                }
            }
            .onSubmit { text = String(format: format, Double(value)) }
    }
}

struct SliderRow<F: Hashable>: View {
    let title: String
    var symbol: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.2f"
    var focusedField: FocusState<F?>.Binding
    var fieldId: F

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingRow(title: title, symbol: symbol) {
                NumberField(
                    value: $value, format: format, focusedField: focusedField,
                    fieldId: fieldId, range: range)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}

struct TPRegionEditor: View {
    @Binding var rect: CGRect
    @Binding var lockAspectRatio: Bool
    let aspect: CGFloat

    enum FocusedField: Hashable {
        case x, y, width, height
    }
    @FocusState private var focusedField: FocusedField?

    @State private var startRect: CGRect? = nil
    @State private var previewBox = CGSize(width: 1, height: 1)
    private let minSize: CGFloat = 0.1
    private let handle: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let pad: CGFloat = handle / 2 + 1
                let inner = CGSize(
                    width: max(0, geo.size.width - pad * 2),
                    height: max(0, geo.size.height - pad * 2))
                let box = fitted(inner, aspect)
                let offX = pad + (inner.width - box.width) / 2
                let offY = pad + (inner.height - box.height) / 2
                let r = CGRect(
                    x: offX + rect.minX * box.width,
                    y: offY + rect.minY * box.height,
                    width: rect.width * box.width,
                    height: rect.height * box.height)

                ZStack(alignment: .topLeading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.background.secondary)
                        GridShape().stroke(.separator, lineWidth: 0.5)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 1)
                    }
                    .frame(width: box.width, height: box.height)
                    .position(x: offX + box.width / 2, y: offY + box.height / 2)

                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.accentColor.opacity(0.22))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
                    .gesture(dragGesture(box: box))

                    handleCircle(.topLeading, r: r, box: box)
                    handleCircle(.topTrailing, r: r, box: box)
                    handleCircle(.bottomLeading, r: r, box: box)
                    handleCircle(.bottomTrailing, r: r, box: box)
                }
            }
            .frame(height: 140)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { previewBox = fittedBox(in: geo.size) }
                        .onChange(of: geo.size) { _, size in
                            previewBox = fittedBox(in: size)
                        }
                }
            }

            Grid(horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    axisLabel("X")
                    NumberField(
                        value: $rect.origin.x, focusedField: $focusedField, fieldId: .x,
                        range: 0...1)
                    axisLabel("Y")
                    NumberField(
                        value: $rect.origin.y, focusedField: $focusedField, fieldId: .y,
                        range: 0...1)
                }
                GridRow {
                    axisLabel("W")
                    NumberField(
                        value: widthBinding, focusedField: $focusedField, fieldId: .width,
                        range: 0...1)
                    axisLabel("H")
                    NumberField(
                        value: heightBinding, focusedField: $focusedField, fieldId: .height,
                        range: 0...1)
                }
            }

            Toggle("Lock aspect ratio", isOn: $lockAspectRatio)
                .toggleStyle(.checkbox)
            .onChange(of: lockAspectRatio) { _, locked in
                if locked {
                    rect = enableAspectLock(rect, box: previewBox)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: Metrics.cardRadius))
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .onAppear {
            DispatchQueue.main.async {
                focusedField = nil
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private func axisLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.leading)
    }

    private func handleCircle(_ corner: Corner, r: CGRect, box: CGSize) -> some View {
        let p = handlePoint(corner, r)
        return Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
            .frame(width: handle, height: handle)
            .shadow(color: .black.opacity(0.28), radius: 1.5, y: 0.5)
            .position(x: p.x, y: p.y)
            .gesture(resizeGesture(corner: corner, box: box))
    }

    private func dragGesture(box: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let s = startRect ?? rect
                if startRect == nil { startRect = rect }
                let dx = v.translation.width / box.width
                let dy = v.translation.height / box.height
                let nx = min(max(0, s.minX + dx), 1 - s.width)
                let ny = min(max(0, s.minY + dy), 1 - s.height)
                rect = CGRect(x: nx, y: ny, width: s.width, height: s.height)
            }
            .onEnded { _ in startRect = nil }
    }

    private func resizeGesture(corner: Corner, box: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let s = startRect ?? rect
                if startRect == nil { startRect = rect }
                let dx = v.translation.width / box.width
                let dy = v.translation.height / box.height
                if lockAspectRatio {
                    rect = resizeWithAspectLock(
                        start: s, corner: corner, dx: dx, dy: dy, box: box)
                } else {
                    var minX = s.minX
                    var minY = s.minY
                    var maxX = s.maxX
                    var maxY = s.maxY
                    switch corner {
                    case .topLeading:
                        minX += dx
                        minY += dy
                    case .topTrailing:
                        maxX += dx
                        minY += dy
                    case .bottomLeading:
                        minX += dx
                        maxY += dy
                    case .bottomTrailing:
                        maxX += dx
                        maxY += dy
                    }
                    minX = min(max(0, minX), maxX - minSize)
                    minY = min(max(0, minY), maxY - minSize)
                    maxX = max(min(1, maxX), minX + minSize)
                    maxY = max(min(1, maxY), minY + minSize)
                    rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                }
            }
            .onEnded { _ in startRect = nil }
    }

    private var widthBinding: Binding<CGFloat> {
        Binding(
            get: { rect.width },
            set: { newWidth in
                var r = rect
                r.size.width = newWidth
                if lockAspectRatio {
                    r.size.height = newWidth / normAspect(in: previewBox)
                }
                rect = clampRect(r)
            }
        )
    }

    private var heightBinding: Binding<CGFloat> {
        Binding(
            get: { rect.height },
            set: { newHeight in
                var r = rect
                r.size.height = newHeight
                if lockAspectRatio {
                    r.size.width = newHeight * normAspect(in: previewBox)
                }
                rect = clampRect(r)
            }
        )
    }

    private func fittedBox(in size: CGSize) -> CGSize {
        let pad = handle / 2 + 1
        let inner = CGSize(
            width: max(0, size.width - pad * 2),
            height: max(0, size.height - pad * 2))
        return fitted(inner, aspect)
    }

    private func normAspect(in box: CGSize) -> CGFloat {
        guard box.width > 0, box.height > 0 else { return 1 }
        return aspect * box.height / box.width
    }

    private func clampRect(_ r: CGRect) -> CGRect {
        let w = max(minSize, min(r.width, 1))
        let h = max(minSize, min(r.height, 1))
        let x = min(max(0, r.origin.x), 1 - w)
        let y = min(max(0, r.origin.y), 1 - h)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func enableAspectLock(_ r: CGRect, box: CGSize) -> CGRect {
        let ratio = normAspect(in: box)
        let targetH = r.width / ratio
        var w = r.width
        var h = r.height
        if h > targetH {
            h = targetH
        } else {
            w = h * ratio
        }
        return clampRect(CGRect(x: r.origin.x, y: r.origin.y, width: w, height: h))
    }

    private func resizeWithAspectLock(
        start s: CGRect, corner: Corner, dx: CGFloat, dy: CGFloat, box: CGSize
    ) -> CGRect {
        let ratio = normAspect(in: box)
        let useWidth = abs(dx) >= abs(dy)
        var w: CGFloat
        var h: CGFloat
        var origin: CGPoint
        switch corner {
        case .topLeading:
            w = s.maxX - (s.minX + dx)
            h = s.maxY - (s.minY + dy)
            (w, h) = aspectSize(width: w, height: h, ratio: ratio, useWidth: useWidth)
            origin = CGPoint(x: s.maxX - w, y: s.maxY - h)
        case .topTrailing:
            w = (s.maxX + dx) - s.minX
            h = s.maxY - (s.minY + dy)
            (w, h) = aspectSize(width: w, height: h, ratio: ratio, useWidth: useWidth)
            origin = CGPoint(x: s.minX, y: s.maxY - h)
        case .bottomLeading:
            w = s.maxX - (s.minX + dx)
            h = (s.maxY + dy) - s.minY
            (w, h) = aspectSize(width: w, height: h, ratio: ratio, useWidth: useWidth)
            origin = CGPoint(x: s.maxX - w, y: s.minY)
        case .bottomTrailing:
            w = (s.maxX + dx) - s.minX
            h = (s.maxY + dy) - s.minY
            (w, h) = aspectSize(width: w, height: h, ratio: ratio, useWidth: useWidth)
            origin = CGPoint(x: s.minX, y: s.minY)
        }
        return clampRect(CGRect(x: origin.x, y: origin.y, width: w, height: h))
    }

    private func aspectSize(
        width w: CGFloat, height h: CGFloat, ratio: CGFloat, useWidth: Bool
    ) -> (CGFloat, CGFloat) {
        if useWidth {
            return (max(w, minSize), max(w / ratio, minSize))
        }
        return (max(h * ratio, minSize), max(h, minSize))
    }

    private func handlePoint(_ c: Corner, _ r: CGRect) -> CGPoint {
        switch c {
        case .topLeading: return CGPoint(x: r.minX, y: r.minY)
        case .topTrailing: return CGPoint(x: r.maxX, y: r.minY)
        case .bottomLeading: return CGPoint(x: r.minX, y: r.maxY)
        case .bottomTrailing: return CGPoint(x: r.maxX, y: r.maxY)
        }
    }

    private func fitted(_ avail: CGSize, _ aspect: CGFloat) -> CGSize {
        if avail.width <= 0 || avail.height <= 0 { return .zero }
        var w = avail.width
        var h = w / aspect
        if h > avail.height {
            h = avail.height
            w = h * aspect
        }
        return CGSize(width: w, height: h)
    }
}

struct PreferenceView: View {
    var statusMenu: StatusMenu

    @Bindable var settings = driverSettings

    @State private var displays: [String] = []
    @State private var applied = false

    private var trackpadRect: Binding<CGRect> {
        Binding(
            get: {
                settings.trackpadArea.map(rectFrom) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            },
            set: { settings.trackpadArea = rangeFrom($0) }
        )
    }

    private var display: Binding<String> {
        Binding(
            get: {
                NSScreen.screens.first(where: {
                    Int($0.cgDirectDisplayID ?? 0) == settings.displayId
                })?.localizedName ?? (displays.first ?? "Unknown")
            },
            set: { name in
                settings.displayId = Int(
                    NSScreen.screens.first(where: { $0.localizedName == name })?
                        .cgDirectDisplayID ?? 0)
            }
        )
    }

    enum FocusedField: Hashable {
        case smoothingFactor
        case jitterThreshold
        case trackingSensitivity
    }
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            Section(title: "Mapping") {
                SettingRow(title: "Mode", symbol: "cursorarrow.motionlines") {
                    Picker("", selection: $settings.trackingMode) {
                        Text("Absolute").tag(DriverSettings.TrackingMode.absolute)
                        Text("Relative").tag(DriverSettings.TrackingMode.relative)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                }

                if settings.trackingMode == .absolute {
                    SettingRow(title: "Display", symbol: "display") {
                        Picker("", selection: display) {
                            ForEach(displays, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .frame(maxWidth: 170)
                    }

                    TPRegionEditor(
                        rect: trackpadRect,
                        lockAspectRatio: $settings.lockAspectRatio,
                        aspect: 1.6
                    )
                } else {
                    SliderRow(
                        title: "Sensitivity",
                        symbol: "speedometer",
                        value: $settings.trackingSensitivity,
                        range: 0.05...10,
                        focusedField: $focusedField,
                        fieldId: .trackingSensitivity
                    )
                }
            }

            Divider()

            Section(title: "Filtering") {
                SliderRow(
                    title: "Smoothing",
                    symbol: "scribble.variable",
                    value: $settings.smoothingFactor,
                    range: 0.1...1,
                    focusedField: $focusedField,
                    fieldId: .smoothingFactor
                )
                SliderRow(
                    title: "Jitter threshold",
                    symbol: "waveform.path",
                    value: $settings.jitterThreshold,
                    range: 0...10,
                    format: "%.0f",
                    focusedField: $focusedField,
                    fieldId: .jitterThreshold
                )
            }

            Divider()

            footer
        }
        .frame(width: Metrics.width, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .onAppear {
            load()
            DispatchQueue.main.async {
                focusedField = nil
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Trackpaddy")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Toggle("", isOn: $settings.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: settings.enabled) { _, _ in
                    updateDriverState()
                }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Quit") {
                NSApp.terminate(nil)
            }

            Spacer()

            Button(applied ? "Applied" : "Apply") {
                updateDriverState()
                withAnimation { applied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation { applied = false }
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
    }

    private func load() {
        displays = NSScreen.screens.map { "\($0.localizedName)" }
    }

    private func updateDriverState() {
        settings.save()

        if settings.enabled {
            restartDriver()
        } else {
            stopDriver()
        }
    }

    private func rectFrom(_ r: DriverSettings.Rectangle) -> CGRect {
        CGRect(
            x: r.low.x, y: r.low.y,
            width: r.up.x - r.low.x, height: r.up.y - r.low.y)
    }

    private func rangeFrom(_ c: CGRect) -> DriverSettings.Rectangle {
        DriverSettings.Rectangle(
            low: NSPoint(x: c.minX, y: c.minY),
            up: NSPoint(x: c.maxX, y: c.maxY))
    }
}

class StatusMenu: NSObject {
    let popover = NSPopover()
    let statusItem: NSStatusItem
    private var hosting: NSHostingController<PreferenceView>!

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        super.init()

        hosting = NSHostingController(rootView: PreferenceView(statusMenu: self))
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            hosting.view.layoutSubtreeIfNeeded()
            popover.contentSize = hosting.view.fittingSize
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            let window = popover.contentViewController?.view.window
            window?.makeKey()
            DispatchQueue.main.async {
                window?.makeFirstResponder(nil)
            }
        }
    }
}
