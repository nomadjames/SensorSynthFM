// PerformanceNoteSurface.swift
// SensorSynthFM
//
// UIKit touch bridge for independent contacts. Controls live outside this view,
// so the bridge cannot accidentally turn a rail tap into a note.

import SwiftUI
import UIKit

public enum NoteEntrySurfaceEvent {
    case began(id: String, normalizedX: Double, normalizedY: Double)
    case moved(id: String, normalizedX: Double, normalizedY: Double)
    case ended(id: String)
    case cancelled(id: String)
    case releaseAll(reason: String)
}

public struct PerformanceNoteSurface: UIViewRepresentable {
    public let onEvent: (NoteEntrySurfaceEvent) -> Void

    public init(onEvent: @escaping (NoteEntrySurfaceEvent) -> Void) {
        self.onEvent = onEvent
    }

    public func makeUIView(context: Context) -> NoteEntrySurfaceView {
        let view = NoteEntrySurfaceView()
        view.onEvent = onEvent
        return view
    }

    public func updateUIView(_ uiView: NoteEntrySurfaceView, context: Context) {
        uiView.onEvent = onEvent
    }
}

public final class NoteEntrySurfaceView: UIView {
    public var onEvent: ((NoteEntrySurfaceEvent) -> Void)?
    private var identifiers: [ObjectIdentifier: String] = [:]
    private var identifierAllocator = TouchIdentifierAllocator()
    private var backgroundObserver: NSObjectProtocol?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = false
        isAccessibilityElement = true
        accessibilityIdentifier = "performance.note.surface"
        accessibilityLabel = "Performance note surface"
        accessibilityHint = "Touch or drag vertically to play pitch. Use the Hold control to sustain notes."
        accessibilityTraits = [.allowsDirectInteraction]
        installBackgroundRecovery()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        isOpaque = false
        isAccessibilityElement = true
        accessibilityIdentifier = "performance.note.surface"
        accessibilityLabel = "Performance note surface"
        accessibilityHint = "Touch or drag vertically to play pitch. Use the Hold control to sustain notes."
        accessibilityTraits = [.allowsDirectInteraction]
        installBackgroundRecovery()
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil, !identifiers.isEmpty {
            flush(reason: "window lost")
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            let id = identifiers[key] ?? identifierAllocator.allocate()
            identifiers[key] = id
            onEvent?(.began(
                id: id,
                normalizedX: normalizedX(for: touch),
                normalizedY: normalizedY(for: touch)
            ))
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = identifiers[ObjectIdentifier(touch)] else { continue }
            onEvent?(.moved(
                id: id,
                normalizedX: normalizedX(for: touch),
                normalizedY: normalizedY(for: touch)
            ))
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { finish(touch, cancelled: false) }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { finish(touch, cancelled: true) }
    }

    private func finish(_ touch: UITouch, cancelled: Bool) {
        let key = ObjectIdentifier(touch)
        guard let id = identifiers.removeValue(forKey: key) else { return }
        if cancelled {
            onEvent?(.cancelled(id: id))
        } else {
            onEvent?(.ended(id: id))
        }
    }

    private func installBackgroundRecovery() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flush(reason: "application backgrounded")
        }
    }

    private func flush(reason: String) {
        identifiers.removeAll(keepingCapacity: true)
        onEvent?(.releaseAll(reason: reason))
    }

    private func normalizedX(for touch: UITouch) -> Double {
        guard bounds.width > 0 else { return 0 }
        return min(max(Double(touch.location(in: self).x / bounds.width), 0), 1)
    }

    private func normalizedY(for touch: UITouch) -> Double {
        guard bounds.height > 0 else { return 0 }
        return min(max(Double(touch.location(in: self).y / bounds.height), 0), 1)
    }
}
