import AppKit

// 主题只负责绘图；电源监听、偏好存储、动画定时器由 AppDelegate 管理。
enum BatteryTheme: IconThemeRenderer {
    static func image(_ state: BatteryState, ink: NSColor = .black, boltOpacity: CGFloat = 1, blink: Bool = false) -> NSImage {
        // [AppKit] 以原来的 38×22 坐标绘图，等比缩到 28×18 点画布并垂直居中。
        // 所有表情和缓存动画帧使用相同变换，避免切换状态时尺寸跳动。
        let image = NSImage(size: NSSize(width: 28, height: 18), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let scale: CGFloat = 28.0 / 38.0
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: (18 - 22 * scale) / 2)
            transform.scale(by: scale)
            transform.concat()
            NSGraphicsContext.current?.shouldAntialias = true
            ink.setStroke()
            ink.setFill()
            func path(_ points: [NSPoint], width: CGFloat = 1.2) {
                let p = NSBezierPath()
                p.lineWidth = width
                p.lineCapStyle = .round
                p.lineJoinStyle = .round
                p.move(to: points[0])
                for point in points.dropFirst() { p.line(to: point) }
                p.stroke()
            }
            func curve(_ start: NSPoint, _ c1: NSPoint, _ c2: NSPoint, _ end: NSPoint, width: CGFloat = 1.2) {
                let p = NSBezierPath()
                p.lineWidth = width
                p.lineCapStyle = .round
                p.move(to: start)
                p.curve(to: end, controlPoint1: c1, controlPoint2: c2)
                p.stroke()
            }
            // [AppKit] NSBezierPath：柔和圆角外壳，以及独立的小电池触点。
            let shell = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3.5, width: 30, height: 16), xRadius: 4.5, yRadius: 4.5)
            shell.lineWidth = 1.35
            shell.stroke()
            NSBezierPath(roundedRect: NSRect(x: 33, y: 8.5, width: 2.2, height: 6), xRadius: 1.1, yRadius: 1.1).fill()
            // 底部轻量电量轨道：不抢表情的视觉重点。
            if let percent = state.percent {
                ink.withAlphaComponent(0.18).setStroke()
                path([NSPoint(x: 7, y: 1), NSPoint(x: 26, y: 1)], width: 1.2)
                ink.setStroke()
                if percent > 0 {
                    path([NSPoint(x: 7, y: 1), NSPoint(x: 7 + 19 * CGFloat(percent) / 100, y: 1)], width: 1.2)
                }
            }
            switch state.mood {
            case "low":
                // 低电量：下垂的眼睑、小小的叹气嘴。
                curve(NSPoint(x: 8, y: 13), NSPoint(x: 9, y: 11.6), NSPoint(x: 11, y: 11.6), NSPoint(x: 12, y: 12.2))
                curve(NSPoint(x: 21, y: 12.2), NSPoint(x: 22, y: 11.6), NSPoint(x: 24, y: 11.6), NSPoint(x: 25, y: 13))
                let mouth = NSBezierPath(ovalIn: NSRect(x: 15, y: 7, width: 3, height: 2.5))
                mouth.lineWidth = 1
                mouth.stroke()
            case "normal":
                // 普通电量：短椭圆眼睛和含蓄微笑。
                for x: CGFloat in [10, 23] {
                    NSBezierPath(ovalIn: NSRect(x: x - 0.95, y: 11.4, width: 1.9, height: 2.8)).fill()
                }
                curve(NSPoint(x: 13.5, y: 9.5), NSPoint(x: 15, y: 7.3), NSPoint(x: 18, y: 7.3), NSPoint(x: 19.5, y: 9.5))
            case "high":
                // 高电量：弯弯笑眼、张开的笑嘴和淡淡脸颊。
                for x: CGFloat in [10, 23] {
                    curve(NSPoint(x: x - 2, y: 12), NSPoint(x: x - 1, y: 15), NSPoint(x: x + 1, y: 15), NSPoint(x: x + 2, y: 12))
                }
                let mouth = NSBezierPath()
                mouth.move(to: NSPoint(x: 13.3, y: 10))
                mouth.line(to: NSPoint(x: 19.7, y: 10))
                mouth.curve(to: NSPoint(x: 13.3, y: 10), controlPoint1: NSPoint(x: 19, y: 5.4), controlPoint2: NSPoint(x: 14, y: 5.4))
                mouth.close()
                mouth.fill()
                ink.withAlphaComponent(0.3).setStroke()
                for x: CGFloat in [7.5, 24] { path([NSPoint(x: x, y: 9), NSPoint(x: x + 1.5, y: 9)], width: 1) }
            case "charging":
                // 充电：左眼眨眼，右眼是小闪电；和 high 明确区分。
                if blink {
                    path([NSPoint(x: 8, y: 12), NSPoint(x: 12, y: 12)])
                } else {
                    curve(NSPoint(x: 8, y: 12), NSPoint(x: 9, y: 14), NSPoint(x: 11, y: 14), NSPoint(x: 12, y: 12))
                }
                let bolt = NSBezierPath()
                bolt.move(to: NSPoint(x: 24, y: 16.2))
                for point in [NSPoint(x: 20.5, y: 12.2), NSPoint(x: 23, y: 12.2), NSPoint(x: 21.5, y: 8.9), NSPoint(x: 26, y: 13.5), NSPoint(x: 23.5, y: 13.5)] { bolt.line(to: point) }
                bolt.close()
                ink.withAlphaComponent(boltOpacity).setFill()
                bolt.fill()
                ink.setFill()
                curve(NSPoint(x: 13.5, y: 9.5), NSPoint(x: 14.5, y: 6.5), NSPoint(x: 17.5, y: 6.5), NSPoint(x: 18.5, y: 9.5))
            default:
                // [Foundation + AppKit] NSString 的绘制扩展显示无电池状态。
                ("?" as NSString).draw(at: NSPoint(x: 13, y: 5), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: ink])
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
