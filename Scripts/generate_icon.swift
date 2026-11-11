// Erzeugt build/AppIcon.icns: helle Karte, Uhr in Salbei, Strichmännchen auf der Spitze des Minutenzeigers.
// Muster: Bitcoin-Uhr, Scripts/generate_icon.swift.
import AppKit

func farbe(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Karte im macOS-Raster (824 von 1024).
    let rand = s * 100 / 1024
    let karte = CGRect(x: rand, y: rand, width: s - 2 * rand, height: s - 2 * rand)
    ctx.addPath(CGPath(roundedRect: karte, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil))
    ctx.setFillColor(farbe(0xEDECE2))
    ctx.fillPath()

    // Uhr
    let m = CGPoint(x: s / 2, y: s * 0.46)
    let r = s * 0.3
    ctx.setFillColor(farbe(0xB3BFB5))
    ctx.fillEllipse(in: CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r))
    let ri = r * 0.9
    ctx.setFillColor(farbe(0xF8F6EC))
    ctx.fillEllipse(in: CGRect(x: m.x - ri, y: m.y - ri, width: 2 * ri, height: 2 * ri))

    // Striche bei 12, 3, 6, 9
    ctx.setStrokeColor(farbe(0x3A4A44))
    ctx.setLineCap(.round)
    ctx.setLineWidth(max(1, s * 0.012))
    for i in 0..<4 {
        let w = CGFloat(i) * .pi / 2
        ctx.move(to: CGPoint(x: m.x + cos(w) * ri * 0.78, y: m.y + sin(w) * ri * 0.78))
        ctx.addLine(to: CGPoint(x: m.x + cos(w) * ri * 0.9, y: m.y + sin(w) * ri * 0.9))
    }
    ctx.strokePath()

    // Zeiger: Stunde auf 10, Minute auf 2 (10:10). Winkel ab 12 im Uhrzeigersinn.
    func punkt(_ grad: CGFloat, _ laenge: CGFloat) -> CGPoint {
        let w = (90 - grad) * .pi / 180
        return CGPoint(x: m.x + cos(w) * laenge, y: m.y + sin(w) * laenge)
    }
    ctx.setStrokeColor(farbe(0x2F4A43))
    ctx.setLineWidth(max(1.5, s * 0.03))
    ctx.move(to: m); ctx.addLine(to: punkt(300, ri * 0.5)); ctx.strokePath()
    let spitze = punkt(40, ri * 0.8)
    ctx.setLineWidth(max(1, s * 0.018))
    ctx.move(to: m); ctx.addLine(to: spitze); ctx.strokePath()
    let nabe = s * 0.028
    ctx.setFillColor(farbe(0x5A8F6E))
    ctx.fillEllipse(in: CGRect(x: m.x - nabe, y: m.y - nabe, width: 2 * nabe, height: 2 * nabe))

    // Strichmännchen balanciert auf der Spitze, Arme ausgebreitet.
    let e = s * 0.085
    let fuss = spitze
    let huefte = CGPoint(x: fuss.x, y: fuss.y + e * 0.9)
    let hals = CGPoint(x: huefte.x, y: huefte.y + e * 0.95)
    ctx.setStrokeColor(farbe(0x1C2422))
    ctx.setLineWidth(max(1.2, s * 0.024))
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: fuss.x - e * 0.3, y: fuss.y)); ctx.addLine(to: huefte)
    ctx.addLine(to: CGPoint(x: fuss.x + e * 0.3, y: fuss.y))
    ctx.move(to: huefte); ctx.addLine(to: hals)
    ctx.move(to: CGPoint(x: hals.x - e * 0.8, y: hals.y + e * 0.3)); ctx.addLine(to: CGPoint(x: hals.x, y: hals.y - e * 0.1))
    ctx.addLine(to: CGPoint(x: hals.x + e * 0.8, y: hals.y + e * 0.3))
    ctx.strokePath()
    let kopf = e * 0.36
    ctx.setFillColor(farbe(0x1C2422))
    ctx.fillEllipse(in: CGRect(x: hals.x - kopf, y: hals.y + e * 0.05, width: 2 * kopf, height: 2 * kopf))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "build/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "build/AppIcon.icns" : "iconutil fehlgeschlagen")
