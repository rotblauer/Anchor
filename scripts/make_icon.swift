// Renders the Apostle Anchor app icon: an anchor over Superior water with
// wind streaks. Run: swift scripts/make_icon.swift <output.png>
import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no graphics context") }

// Water gradient, deep navy at the top to teal at the waterline.
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(calibratedRed: 0.02, green: 0.11, blue: 0.24, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.03, green: 0.30, blue: 0.42, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.54, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 0.55, 1]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

// Waves along the bottom.
for (index, baseY) in [CGFloat(150), 220, 290].enumerated() {
    let wave = NSBezierPath()
    wave.lineWidth = 30
    wave.lineCapStyle = .round
    wave.move(to: NSPoint(x: -40, y: baseY))
    var x: CGFloat = -40
    var up = index % 2 == 0
    while x < size + 40 {
        let next = x + 180
        wave.curve(
            to: NSPoint(x: next, y: baseY),
            controlPoint1: NSPoint(x: x + 60, y: baseY + (up ? 46 : -46)),
            controlPoint2: NSPoint(x: next - 60, y: baseY + (up ? 46 : -46))
        )
        x = next
        up.toggle()
    }
    NSColor(calibratedWhite: 1, alpha: 0.10 + 0.04 * CGFloat(index)).setStroke()
    wave.stroke()
}

// Wind streaks, upper right.
for (offset, width) in [(CGFloat(0), CGFloat(280)), (70, 360), (140, 240)] {
    let streak = NSBezierPath()
    streak.lineWidth = 26
    streak.lineCapStyle = .round
    let y = 880 - offset
    streak.move(to: NSPoint(x: 560, y: y))
    streak.curve(
        to: NSPoint(x: 560 + width, y: y + 30),
        controlPoint1: NSPoint(x: 560 + width * 0.4, y: y + 6),
        controlPoint2: NSPoint(x: 560 + width * 0.75, y: y + 24)
    )
    NSColor(calibratedWhite: 1, alpha: 0.30).setStroke()
    streak.stroke()
}

// The anchor.
NSColor.white.setStroke()
let stroke: CGFloat = 42

let ring = NSBezierPath(ovalIn: NSRect(x: 512 - 52, y: 742, width: 104, height: 104))
ring.lineWidth = stroke * 0.8
ring.stroke()

let shaft = NSBezierPath()
shaft.lineWidth = stroke
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 512, y: 742))
shaft.line(to: NSPoint(x: 512, y: 300))
shaft.stroke()

let bar = NSBezierPath()
bar.lineWidth = stroke * 0.85
bar.lineCapStyle = .round
bar.move(to: NSPoint(x: 402, y: 660))
bar.line(to: NSPoint(x: 622, y: 660))
bar.stroke()

for direction in [CGFloat(-1), 1] {
    let arm = NSBezierPath()
    arm.lineWidth = stroke
    arm.lineCapStyle = .round
    arm.move(to: NSPoint(x: 512 + direction * 190, y: 470))
    arm.curve(
        to: NSPoint(x: 512, y: 292),
        controlPoint1: NSPoint(x: 512 + direction * 195, y: 350),
        controlPoint2: NSPoint(x: 512 + direction * 90, y: 296)
    )
    arm.stroke()

    // Fluke tips
    let fluke = NSBezierPath()
    fluke.lineWidth = stroke * 0.8
    fluke.lineCapStyle = .round
    fluke.move(to: NSPoint(x: 512 + direction * 190, y: 470))
    fluke.line(to: NSPoint(x: 512 + direction * 252, y: 520))
    fluke.stroke()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode png")
}
try! png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
