import AppKit
import CoreGraphics

// Renders the Cool Notch app icon at 1024x1024 following the macOS icon grid
// (824pt rounded square centered on a 1024 canvas).
let size: CGFloat = 1024
let out = CommandLine.arguments[1]

let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Flip to top-left origin for easier reasoning.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r / 255, g / 255, b / 255, a])!
}

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: c(0, 0, 0, 0.45))
ctx.addPath(tilePath)
ctx.setFillColor(c(10, 8, 24))
ctx.fillPath()
ctx.restoreGState()

// Background gradient (deep indigo -> near black)
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let bg = CGGradient(colorsSpace: cs, colors: [c(38, 22, 86), c(14, 10, 34), c(6, 6, 14)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

// Neon glow spilling down from the notch
let glowColors: [(CGFloat, CGFloat, CGFloat)] = [(255, 64, 160), (255, 140, 60), (60, 200, 255)]
let glowCenters: [CGFloat] = [400, 512, 624]
for (i, col) in glowColors.enumerated() {
    let g = CGGradient(colorsSpace: cs,
                       colors: [c(col.0, col.1, col.2, 0.75), c(col.0, col.1, col.2, 0)] as CFArray,
                       locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: glowCenters[i], y: 250), startRadius: 0,
                           endCenter: CGPoint(x: glowCenters[i], y: 300), endRadius: 330, options: [])
}
// Soft light cone
let cone = CGMutablePath()
cone.move(to: CGPoint(x: 360, y: 260))
cone.addLine(to: CGPoint(x: 664, y: 260))
cone.addLine(to: CGPoint(x: 900, y: 924))
cone.addLine(to: CGPoint(x: 124, y: 924))
cone.closeSubpath()
ctx.saveGState()
ctx.addPath(cone)
ctx.clip()
let coneG = CGGradient(colorsSpace: cs, colors: [c(255, 255, 255, 0.16), c(255, 255, 255, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(coneG, start: CGPoint(x: 512, y: 260), end: CGPoint(x: 512, y: 800), options: [])
ctx.restoreGState()

// The notch: black shape hanging from the top edge
let notch = CGMutablePath()
let nL: CGFloat = 300, nR: CGFloat = 724, nTop: CGFloat = 100, nBottom: CGFloat = 290, r: CGFloat = 70
notch.move(to: CGPoint(x: nL - 40, y: nTop))
notch.addQuadCurve(to: CGPoint(x: nL, y: nTop + 40), control: CGPoint(x: nL, y: nTop))
notch.addLine(to: CGPoint(x: nL, y: nBottom - r))
notch.addQuadCurve(to: CGPoint(x: nL + r, y: nBottom), control: CGPoint(x: nL, y: nBottom))
notch.addLine(to: CGPoint(x: nR - r, y: nBottom))
notch.addQuadCurve(to: CGPoint(x: nR, y: nBottom - r), control: CGPoint(x: nR, y: nBottom))
notch.addLine(to: CGPoint(x: nR, y: nTop + 40))
notch.addQuadCurve(to: CGPoint(x: nR + 40, y: nTop), control: CGPoint(x: nR, y: nTop))
notch.closeSubpath()
ctx.addPath(notch)
ctx.setFillColor(c(0, 0, 0))
ctx.fillPath()

// Equalizer bars inside the notch, with a horizontal neon gradient
let heights: [CGFloat] = [48, 88, 120, 72, 104, 56]
let barW: CGFloat = 30, gap: CGFloat = 22
let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = 512 - totalW / 2
let baseY: CGFloat = 250
let bars = CGMutablePath()
for h in heights {
    bars.addPath(CGPath(roundedRect: CGRect(x: x, y: baseY - h, width: barW, height: h),
                        cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil))
    x += barW + gap
}
ctx.saveGState()
ctx.addPath(bars)
ctx.clip()
let barG = CGGradient(colorsSpace: cs, colors: [c(255, 64, 160), c(255, 150, 60), c(60, 210, 255)] as CFArray,
                      locations: [0, 0.5, 1])!
ctx.drawLinearGradient(barG, start: CGPoint(x: 512 - totalW / 2, y: 0), end: CGPoint(x: 512 + totalW / 2, y: 0), options: [])
ctx.restoreGState()

// Subtle top highlight on the tile edge
ctx.addPath(tilePath)
ctx.setStrokeColor(c(255, 255, 255, 0.10))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
