import AppKit

let args = CommandLine.arguments

// `Zeigerreiter --selbsttest` prüft Sprüche und Reihenfolge. Ausgabe `ok`, sonst die Fehler.
if args.contains("--selbsttest") {
    let fehler = Texte.selbsttest()
    if fehler.isEmpty {
        print("ok")
        exit(0)
    }
    fehler.forEach { print($0) }
    exit(1)
}

// `Zeigerreiter --folge <stunden>` zeigt je Stunde die Nummern der sechs Sprüche.
if let i = args.firstIndex(of: "--folge"), i + 1 < args.count, let stunden = Int(args[i + 1]) {
    let start = Texte.stundenNummer(Date())
    for n in start..<(start + stunden) {
        let zeile = Bewegung.allCases.map { String(format: "%2d", Texte.index(bewegung: $0, stundenNummer: n)) }
        print("Stunde +\(n - start): \(zeile.joined(separator: " "))")
    }
    exit(0)
}

// `Zeigerreiter --bogen <datei.png> HH:mm[:blend] …` malt Standbilder nebeneinander, ohne Bildschirmaufnahme.
if let i = args.firstIndex(of: "--bogen"), i + 2 < args.count {
    let ziel = URL(fileURLWithPath: args[i + 1])
    let zeiten = Array(args[(i + 2)...])
    MainActor.assumeIsolated {
        let breite: CGFloat = 400, hoehe = breite * UhrView.seitenverhaeltnis
        let spalten = min(zeiten.count, 4)
        let zeilen = (zeiten.count + spalten - 1) / spalten
        let ctx = CGContext(data: nil, width: Int(breite) * spalten, height: Int(hoehe) * zeilen,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let stundenNummer = Texte.stundenNummer(Date())
        for (k, zeit) in zeiten.enumerated() {
            // Zelle: HH:mm[:blend[:farbe[:blatt[:figur[:sprache[:k]]]]]]
            let t = zeit.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            let p = t.prefix(3).map { Double($0) ?? 0 }
            func teil(_ i: Int) -> String { i < t.count ? t[i] : "" }
            var a = Aussehen()
            a.farbe = Farbwelt(rawValue: teil(3)) ?? .salbei
            a.blatt = Blattart(rawValue: teil(4)) ?? .schlicht
            a.gestalt = Gestalt(rawValue: teil(5)) ?? .mensch
            a.sprache = Sprache(rawValue: teil(6)) ?? .de
            a.komplikationen = teil(7) == "k"
            a.bitcoin = teil(7) == "btc"
            let uhr = UhrView(frame: NSRect(x: 0, y: 0, width: breite, height: hoehe))
            uhr.aussehen = a.fuerStunde(0)
            // Standbild ohne Netz: feste Beispielwerte.
            if a.bitcoin { uhr.bitcoinWerte = BitcoinWerte(block: "921.000", gebuehren: "3 · 2 · 1", kurs: "$ 100.000") }
            uhr.stelle(datum: Date(), stunde: Int(p[0]), minute: p.count > 1 ? p[1] : 0,
                       stundenNummer: stundenNummer + Int(p[0]), blend: CGFloat(p.count > 2 ? p[2] : 0))
            guard let bild = uhr.bild(skala: 1) else { continue }
            let x = CGFloat(k % spalten) * breite
            let y = CGFloat(zeilen - 1 - k / spalten) * hoehe
            ctx.draw(bild, in: CGRect(x: x, y: y, width: breite, height: hoehe))
        }
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try! rep.representation(using: .png, properties: [:])!.write(to: ziel)
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
