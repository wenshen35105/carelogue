import AppKit

// Carelogue app icon: the app's own mark (heart.text.square, as the paywall
// header uses) on the warm background the whole UI is built on.
let side = 1024.0
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    FileHandle.standardError.write("context failed\n".data(using: .utf8)!); exit(1)
}

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Background: the accent, deepening towards the foot so the mark stays legible.
let grad = CGGradient(colorsSpace: space,
                      colors: [rgb(0xE08A63), rgb(0xCC6A3F)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])

// The mark, in the app's cream, optically centred.
let accent = NSColor(red: 0xFB/255.0, green: 0xF6/255.0, blue: 0xF1/255.0, alpha: 1)
let config = NSImage.SymbolConfiguration(pointSize: 620, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [accent]))
guard let symbol = NSImage(systemSymbolName: "heart.text.square", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
    FileHandle.standardError.write("symbol failed\n".data(using: .utf8)!); exit(2)
}

let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gc
let s = symbol.size
symbol.draw(in: NSRect(x: (side - s.width) / 2, y: (side - s.height) / 2,
                       width: s.width, height: s.height))
NSGraphicsContext.restoreGraphicsState()

guard let image = ctx.makeImage() else { exit(3) }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(4) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1]) \(Int(side))x\(Int(side))")

