import AppKit

// OpenDesign 方案 A：28×18 SVG 转为原生矢量。计时器与缓存由 AppDelegate 管理。
enum PineappleTheme: IconThemeRenderer {
    static func image(_ state: BatteryState, ink: NSColor = .black, boltOpacity: CGFloat = 1, blink: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 28, height: 18), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            // 将 SVG 左上原点整体翻转到 AppKit 坐标，保持设计的原始尺寸。
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: 18)
            transform.scaleX(by: 1, yBy: -1)
            transform.concat()
            NSGraphicsContext.current?.shouldAntialias = true
            ink.setStroke()
            ink.setFill()
            func stroke(_ path: NSBezierPath) {
                path.lineWidth = 1
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            stroke(body())
            stroke(crown())
            stroke(texture())
            switch state.mood {
            case "low":
                stroke(lowEyes())
                stroke(lowMouth())
            case "normal":
                stroke(normalEyes())
                stroke(normalMouth())
            case "high":
                stroke(highEyes())
                highMouth().fill()
            case "charging":
                stroke(blink ? closedEyes() : normalEyes())
                stroke(normalMouth())
                ink.withAlphaComponent(ink.alphaComponent * min(1, max(0, boltOpacity))).setFill()
                bolt().fill()
                ink.setFill()
            default:
                stroke(unknownEyes())
            }
            let rail = NSBezierPath()
            rail.move(to: NSPoint(x: 6, y: 16.5))
            rail.line(to: NSPoint(x: 22, y: 16.5))
            ink.withAlphaComponent(ink.alphaComponent * 0.22).setStroke()
            stroke(rail)
            if let percent = state.percent, percent > 0 {
                ink.setStroke()
                let level = NSBezierPath()
                level.move(to: NSPoint(x: 6, y: 16.5))
                level.line(to: NSPoint(x: 6 + 16 * CGFloat(min(100, percent)) / 100, y: 16.5))
                stroke(level)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func body() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 10, y: 5.75))
        p.curve(to: NSPoint(x: 5.5, y: 10), controlPoint1: NSPoint(x: 6.75, y: 5.75), controlPoint2: NSPoint(x: 5.5, y: 7.25))
        p.curve(to: NSPoint(x: 10.5, y: 14.25), controlPoint1: NSPoint(x: 5.5, y: 12.75), controlPoint2: NSPoint(x: 7.5, y: 14.25))
        p.line(to: NSPoint(x: 17.5, y: 14.25))
        p.curve(to: NSPoint(x: 22.5, y: 10), controlPoint1: NSPoint(x: 20.5, y: 14.25), controlPoint2: NSPoint(x: 22.5, y: 12.75))
        p.curve(to: NSPoint(x: 18, y: 5.75), controlPoint1: NSPoint(x: 22.5, y: 7.25), controlPoint2: NSPoint(x: 21.25, y: 5.75))
        p.close()
        return p
    }

    private static func crown() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 11.5, y: 5.5))
        p.curve(to: NSPoint(x: 9, y: 2.5), controlPoint1: NSPoint(x: 9.666666666666666, y: 4.833333333333333), controlPoint2: NSPoint(x: 8.833333333333334, y: 3.833333333333333))
        p.curve(to: NSPoint(x: 13, y: 4.5), controlPoint1: NSPoint(x: 10.666666666666666, y: 2.5), controlPoint2: NSPoint(x: 12, y: 3.166666666666667))
        p.curve(to: NSPoint(x: 14, y: 1), controlPoint1: NSPoint(x: 12.333333333333334, y: 2.833333333333333), controlPoint2: NSPoint(x: 12.666666666666666, y: 1.6666666666666665))
        p.curve(to: NSPoint(x: 15, y: 4.5), controlPoint1: NSPoint(x: 15.333333333333334, y: 1.6666666666666665), controlPoint2: NSPoint(x: 15.666666666666666, y: 2.833333333333333))
        p.curve(to: NSPoint(x: 19, y: 2.5), controlPoint1: NSPoint(x: 16, y: 3.166666666666667), controlPoint2: NSPoint(x: 17.333333333333332, y: 2.5))
        p.curve(to: NSPoint(x: 16.5, y: 5.5), controlPoint1: NSPoint(x: 19.166666666666668, y: 3.833333333333333), controlPoint2: NSPoint(x: 18.333333333333332, y: 4.833333333333333))
        return p
    }

    private static func texture() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 7.75, y: 8.25))
        p.line(to: NSPoint(x: 8.25, y: 8.75))
        p.move(to: NSPoint(x: 7.75, y: 11.25))
        p.line(to: NSPoint(x: 8.25, y: 11.75))
        p.move(to: NSPoint(x: 20.25, y: 8.25))
        p.line(to: NSPoint(x: 19.75, y: 8.75))
        p.move(to: NSPoint(x: 20.25, y: 11.25))
        p.line(to: NSPoint(x: 19.75, y: 11.75))
        return p
    }

    private static func lowEyes() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 10.75, y: 9))
        p.line(to: NSPoint(x: 12, y: 9.5))
        p.move(to: NSPoint(x: 16, y: 9.5))
        p.line(to: NSPoint(x: 17.25, y: 9))
        return p
    }

    private static func lowMouth() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 12.75, y: 12))
        p.curve(to: NSPoint(x: 15.25, y: 12), controlPoint1: NSPoint(x: 13.583333333333334, y: 11.166666666666666), controlPoint2: NSPoint(x: 14.416666666666666, y: 11.166666666666666))
        return p
    }

    private static func normalEyes() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 11.25, y: 8.5))
        p.line(to: NSPoint(x: 11.25, y: 9.5))
        p.move(to: NSPoint(x: 16.75, y: 8.5))
        p.line(to: NSPoint(x: 16.75, y: 9.5))
        return p
    }

    private static func normalMouth() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 12.5, y: 11))
        p.curve(to: NSPoint(x: 15.5, y: 11), controlPoint1: NSPoint(x: 13.5, y: 12.166666666666666), controlPoint2: NSPoint(x: 14.5, y: 12.166666666666666))
        return p
    }

    private static func highEyes() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 10.75, y: 9.25))
        p.curve(to: NSPoint(x: 12.25, y: 9.25), controlPoint1: NSPoint(x: 11.25, y: 8.25), controlPoint2: NSPoint(x: 11.75, y: 8.25))
        p.move(to: NSPoint(x: 15.75, y: 9.25))
        p.curve(to: NSPoint(x: 17.25, y: 9.25), controlPoint1: NSPoint(x: 16.25, y: 8.25), controlPoint2: NSPoint(x: 16.75, y: 8.25))
        return p
    }

    private static func highMouth() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 12.25, y: 10.75))
        p.line(to: NSPoint(x: 15.75, y: 10.75))
        p.curve(to: NSPoint(x: 14, y: 13), controlPoint1: NSPoint(x: 15.583333333333334, y: 12.25), controlPoint2: NSPoint(x: 15, y: 13))
        p.curve(to: NSPoint(x: 12.25, y: 10.75), controlPoint1: NSPoint(x: 13, y: 13), controlPoint2: NSPoint(x: 12.416666666666666, y: 12.25))
        p.close()
        return p
    }

    private static func closedEyes() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 10.75, y: 9))
        p.line(to: NSPoint(x: 12, y: 9))
        p.move(to: NSPoint(x: 16, y: 9))
        p.line(to: NSPoint(x: 17.25, y: 9))
        return p
    }

    private static func bolt() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 25.25, y: 5.5))
        p.line(to: NSPoint(x: 23.5, y: 9.5))
        p.line(to: NSPoint(x: 24.5, y: 9.5))
        p.line(to: NSPoint(x: 23.75, y: 13))
        p.line(to: NSPoint(x: 27, y: 8.5))
        p.line(to: NSPoint(x: 25, y: 8.5))
        p.close()
        return p
    }

    private static func unknownEyes() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 12.5, y: 8.75))
        p.curve(to: NSPoint(x: 15.5, y: 8.75), controlPoint1: NSPoint(x: 12.5, y: 7), controlPoint2: NSPoint(x: 15.5, y: 7))
        p.curve(to: NSPoint(x: 14, y: 10.25), controlPoint1: NSPoint(x: 15.5, y: 9.25), controlPoint2: NSPoint(x: 15, y: 9.75))
        p.line(to: NSPoint(x: 14, y: 10.5))
        p.move(to: NSPoint(x: 14, y: 12))
        p.line(to: NSPoint(x: 14, y: 12.1))
        return p
    }
}
