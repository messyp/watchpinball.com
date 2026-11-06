import CoreGraphics
import SwiftUI
import Foundation
import ImageIO

// LOGOS=dir: each table's own lettering on a transparent canvas, far larger than the table art.
// Copy into the game repo's tools/headless, add it to the swiftc line in build.sh, and add this
// near the top of main.swift:
//   if let dir = ProcessInfo.processInfo.environment["LOGOS"] { runLogos(dir: dir); exit(0) }
// Then: LOGOS=dir ./pinsim x 0
// The calls and colours are copied from the tables' paintApronTitle and paintWords.
func runLogos(dir: String) {
    Bitmap.realScale = 14
    func save(_ name: String, _ w: Int, _ h: Int, _ draw: (Bitmap) -> Void) {
        let b = Bitmap(w, h)
        draw(b)
        let img = b.cgImage(), iw = img.width, ih = img.height
        var px = [UInt8](repeating: 0, count: iw * ih * 4)
        let c = CGContext(data: &px, width: iw, height: ih, bitsPerComponent: 8, bytesPerRow: iw * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(img, in: CGRect(x: 0, y: 0, width: iw, height: ih))
        var x0 = iw, x1 = 0, y0 = ih, y1 = 0
        for y in 0..<ih { for x in 0..<iw where px[(y * iw + x) * 4 + 3] > 6 { x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y) } }
        let box = CGRect(x: x0, y: ih - 1 - y1, width: x1 - x0 + 1, height: y1 - y0 + 1)
        let cut = img.cropping(to: box) ?? img
        let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(dir)/\(name).png") as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(d, cut, nil); CGImageDestinationFinalize(d)
        print(name, cut.width, cut.height)
    }
    let mid = CGPoint(x: 100, y: 20)
    save("cosmic", 200, 40) { b in
        b.styledText("COSMIC", centre: mid, size: 10, design: .plain, black: false, tracking: 3, fill: RGBA(hex: 0x2fe0ff), glow: RGBA(hex: 0x2fe0ff), glowBlur: 3.5, tubesOnly: true)
    }
    save("clockwork", 200, 40) { b in
        b.styledText("CLOCKWORK", centre: mid, size: 9.5, design: .serif, tracking: 4.5, fill: RGBA(hex: 0xf0d9a0), regular: true)
    }
    save("haunted", 200, 40) { b in
        b.styledText("HAUNTED", centre: mid, size: 9.5, design: .serif, tracking: 4.5, fill: RGBA(hex: 0xf4f0e4), glow: RGBA(hex: 0xffc070, 0.9), glowBlur: 3, regular: true)
    }
    save("sugar", 200, 60) { b in
        b.display("SUGAR", centre: CGPoint(x: 100, y: 22), size: 15, fill: RGBA(hex: 0xf01c78), outline: .white)
        b.display("RUSH!", centre: CGPoint(x: 104, y: 34.5), size: 15, fill: RGBA(hex: 0xf49400), outline: .white, angle: -0.08)
    }
    save("treasure", 200, 40) { b in
        let centre = mid
        let plate = CGRect(x: centre.x - 40, y: centre.y - 7.5, width: 80, height: 15)
        b.gradient(Path(roundedRect: plate, cornerRadius: 1.6), [RGBA(hex: 0xf4d488), RGBA(hex: 0xb88428), RGBA(hex: 0x704a12)], from: Board.pt(0, plate.minY), to: Board.pt(0, plate.maxY))
        b.stroke(Path(roundedRect: plate.insetBy(dx: 1.2, dy: 1.2), cornerRadius: 1), RGBA(hex: 0x5a3a08), width: 0.45)
        for x in [plate.minX + 3.4, plate.maxX - 3.4] {
            b.circle(Board.pt(x, centre.y), 1, RGBA(hex: 0x5a3a08))
            b.circle(Board.pt(x - 0.3, centre.y - 0.3), 0.5, RGBA(hex: 0xfff0b0))
        }
        b.incised("TREASURE", centre: centre, size: 8, tracking: 3, ink: RGBA(hex: 0x2c1a04), lip: RGBA(hex: 0xfff0b0, 0.7))
    }
}
