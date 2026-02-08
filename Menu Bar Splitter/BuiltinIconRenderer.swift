//
//  BuiltinIconRenderer.swift
//  Menu Bar Splitter
//
//  Programmatic rendering for built-in line & dot icons
//  with configurable thickness and color.
//

import Cocoa

// MARK: - Comparable Clamping

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - UserDefaults Color Helpers

extension UserDefaults {
    func setColor(_ color: NSColor?, forKey key: String) {
        guard let color = color else {
            removeObject(forKey: key)
            return
        }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            set(data, forKey: key)
        }
    }

    func color(forKey key: String) -> NSColor? {
        guard let data = data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }
}

// MARK: - BuiltinIconRenderer

struct BuiltinIconRenderer {

    /// Draws a vertical line icon (rounded rect) centered in the image.
    /// - Parameters:
    ///   - thickness: Width of the line in points (default 1.0)
    ///   - lineHeight: Height of the drawn line in points, or nil for auto (height - 6)
    ///   - color: Custom color, or nil for system label color (template mode)
    ///   - height: Total image height (menu bar height)
    static func lineIcon(thickness: CGFloat = 1.0, lineHeight: CGFloat? = nil, color: NSColor? = nil, height: CGFloat = 22) -> NSImage {
        let imageWidth = max(thickness + 2, 4)
        let drawColor = color ?? NSColor.labelColor

        let image = NSImage(size: NSSize(width: imageWidth, height: height), flipped: false) { rect in
            let lineHeight = min(lineHeight ?? (height - 6), height)
            let lineRect = NSRect(
                x: (rect.width - thickness) / 2,
                y: (rect.height - lineHeight) / 2,
                width: thickness,
                height: lineHeight
            )
            let cornerRadius = min(thickness / 2, 1.0)
            let path = NSBezierPath(roundedRect: lineRect, xRadius: cornerRadius, yRadius: cornerRadius)
            drawColor.setFill()
            path.fill()
            return true
        }

        image.isTemplate = (color == nil)
        return image
    }

    /// Draws a filled circle (dot) icon centered in the image.
    /// - Parameters:
    ///   - diameter: Diameter of the dot in points (default 4.0)
    ///   - color: Custom color, or nil for system label color (template mode)
    ///   - height: Total image height (menu bar height)
    static func dotIcon(diameter: CGFloat = 4.0, color: NSColor? = nil, height: CGFloat = 22) -> NSImage {
        let imageWidth = max(diameter + 2, 6)
        let drawColor = color ?? NSColor.labelColor

        let image = NSImage(size: NSSize(width: imageWidth, height: height), flipped: false) { rect in
            let dotRect = NSRect(
                x: (rect.width - diameter) / 2,
                y: (rect.height - diameter) / 2,
                width: diameter,
                height: diameter
            )
            let path = NSBezierPath(ovalIn: dotRect)
            drawColor.setFill()
            path.fill()
            return true
        }

        image.isTemplate = (color == nil)
        return image
    }
}
