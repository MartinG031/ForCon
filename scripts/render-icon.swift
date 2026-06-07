import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

image.lockFocus()
let canvas = CGRect(origin: .zero, size: size)
NSColor.clear.setFill()
canvas.fill()

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
shadow.shadowBlurRadius = 36
shadow.shadowOffset = CGSize(width: 0, height: -18)
shadow.set()

let bodyRect = canvas.insetBy(dx: 72, dy: 72)
let bodyPath = roundedRect(bodyRect, radius: 210)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.62, blue: 0.94, alpha: 1.0),
    NSColor(calibratedRed: 0.09, green: 0.78, blue: 0.58, alpha: 1.0)
])!
gradient.draw(in: bodyPath, angle: 315)

NSGraphicsContext.current?.cgContext.setBlendMode(.softLight)
let highlight = roundedRect(bodyRect.insetBy(dx: 34, dy: 34), radius: 178)
NSColor.white.withAlphaComponent(0.28).setStroke()
highlight.lineWidth = 18
highlight.stroke()
NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

let cardRect = CGRect(x: 244, y: 250, width: 536, height: 524)
let cardPath = roundedRect(cardRect, radius: 86)
NSColor.white.withAlphaComponent(0.92).setFill()
cardPath.fill()

let topArrow = NSBezierPath()
topArrow.move(to: CGPoint(x: 318, y: 612))
topArrow.line(to: CGPoint(x: 626, y: 612))
topArrow.line(to: CGPoint(x: 594, y: 676))
topArrow.move(to: CGPoint(x: 626, y: 612))
topArrow.line(to: CGPoint(x: 594, y: 548))
NSColor(calibratedRed: 0.05, green: 0.42, blue: 0.78, alpha: 1.0).setStroke()
topArrow.lineWidth = 48
topArrow.lineCapStyle = .round
topArrow.lineJoinStyle = .round
topArrow.stroke()

let bottomArrow = NSBezierPath()
bottomArrow.move(to: CGPoint(x: 706, y: 412))
bottomArrow.line(to: CGPoint(x: 398, y: 412))
bottomArrow.line(to: CGPoint(x: 430, y: 476))
bottomArrow.move(to: CGPoint(x: 398, y: 412))
bottomArrow.line(to: CGPoint(x: 430, y: 348))
NSColor(calibratedRed: 0.0, green: 0.58, blue: 0.43, alpha: 1.0).setStroke()
bottomArrow.lineWidth = 48
bottomArrow.lineCapStyle = .round
bottomArrow.lineJoinStyle = .round
bottomArrow.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}

let outputURL = URL(fileURLWithPath: outputPath)
try png.write(to: outputURL)
