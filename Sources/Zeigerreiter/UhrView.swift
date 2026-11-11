import AppKit
import QuartzCore

/// Die ganze Uhr als Ebenen: Karte, Zifferblatt, Komplikationen, Zeiger, Figur, zwei Textzeilen.
/// Die Dauerbewegung der Figur läuft als Core-Animation im Render-Server,
/// die App selbst rechnet nur alle zehn Sekunden.
@MainActor
final class UhrView: NSView {
    static let seitenverhaeltnis: CGFloat = 1.5

    /// Farbe, Zifferblatt, Figur, Sprache, Komplikationen.
    var aussehen = Aussehen() {
        didSet { if aussehen != oldValue { aufbauen() } }
    }

    private let karte = CAGradientLayer()
    private let rand = CAShapeLayer()
    private let blattEbene = CAShapeLayer()
    private let zier = CALayer()
    private let kompl = CALayer()
    private let stundenzeiger = CAShapeLayer()
    private let minutenzeiger = CAShapeLayer()
    private let glieder = CAShapeLayer()
    private let kopf = CAShapeLayer()
    private let punkt = CAShapeLayer()
    private let zeile1 = CATextLayer()
    private let zeile2 = CATextLayer()

    // Bewegliche Teile der Komplikationen.
    private let datumText = CATextLayer()
    private let tagText = CATextLayer()
    private let mond = CAShapeLayer()
    private let sekunde = CAShapeLayer()

    // Werte des Bitcoin-Modus.
    private let btcBlock = CATextLayer()
    private let btcGebuehren = CATextLayer()
    private let btcKurs = CATextLayer()
    var bitcoinWerte = BitcoinWerte() {
        didSet { if bitcoinWerte != oldValue { stelleBitcoinWerte() } }
    }

    /// Plätze der drei Werte: links Block, rechts Gebühren, unten Kurs.
    private static func btcPlatz(_ i: Int, d: CGFloat, m: CGPoint) -> CGPoint {
        [m + CGPoint(x: -d * 0.205, y: 0), m + CGPoint(x: d * 0.205, y: 0), m + CGPoint(x: 0, y: -d * 0.15)][i]
    }

    private func stelleBitcoinWerte() {
        guard aussehen.bitcoin else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let d = blatt.d
        let f = schrift(d * 0.046, .medium, .serif)
        let werte = [bitcoinWerte.block, bitcoinWerte.gebuehren, bitcoinWerte.kurs]
        for (i, e) in [btcBlock, btcGebuehren, btcKurs].enumerated() {
            beschrifte(e, werte[i], f, Ton(0xF7931A).ns(),
                       mitte: Self.btcPlatz(i, d: d, m: blatt.mitte) - CGPoint(x: 0, y: d * 0.016))
        }
        CATransaction.commit()
    }

    private var textSchluessel = ""
    private var komplSchluessel = ""
    private var blatt = Zifferblatt(mitte: .zero, d: 1)

    override init(frame: NSRect) {
        super.init(frame: frame)
        let wurzel = CALayer()
        layer = wurzel
        wantsLayer = true
        for e in [karte, rand, blattEbene, zier, kompl, stundenzeiger, minutenzeiger, glieder, kopf, punkt, zeile1, zeile2] as [CALayer] {
            wurzel.addSublayer(e)
        }
        karte.startPoint = CGPoint(x: 0.5, y: 1)
        karte.endPoint = CGPoint(x: 0.5, y: 0)
        glieder.fillColor = nil
        glieder.lineCap = .round
        glieder.lineJoin = .round
        for z in [zeile1, zeile2, datumText, tagText, btcBlock, btcGebuehren, btcKurs] {
            z.alignmentMode = .center
            z.isWrapped = false
            z.contentsScale = 2
        }
        aufbauen()
    }

    required init?(coder: NSCoder) { fatalError("nicht benutzt") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        aufbauen()
    }

    // MARK: Aufbau

    private func schrift(_ groesse: CGFloat, _ gewicht: NSFont.Weight, _ design: NSFontDescriptor.SystemDesign) -> NSFont {
        let grund = NSFont.systemFont(ofSize: groesse, weight: gewicht)
        guard let d = grund.fontDescriptor.withDesign(design) else { return grund }
        return NSFont(descriptor: d, size: groesse) ?? grund
    }

    /// Setzt einen Text mittig auf einen Punkt.
    private func beschrifte(_ ebene: CATextLayer, _ text: String, _ schrift: NSFont, _ farbe: NSColor,
                            mitte: CGPoint, drehung: CGFloat = 0, sperrung: CGFloat = 0) {
        let s = NSAttributedString(string: text, attributes: [.font: schrift, .foregroundColor: farbe, .kern: sperrung])
        let g = s.size()
        ebene.string = s
        ebene.bounds = CGRect(x: 0, y: 0, width: ceil(g.width) + 2, height: ceil(g.height))
        ebene.position = mitte
        ebene.setAffineTransform(CGAffineTransform(rotationAngle: drehung))
    }

    /// Alles, was nur von Größe und Aussehen abhängt.
    private func aufbauen() {
        let w = bounds.width, h = bounds.height
        guard w > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let p = aussehen.farbe.palette
        let d = w * 0.80
        blatt = Zifferblatt(mitte: CGPoint(x: w / 2, y: h * 0.40), d: d)
        let m = blatt.mitte

        karte.frame = bounds
        karte.cornerRadius = w * 0.07
        karte.masksToBounds = true
        karte.colors = p.hell.map(\.cg)

        func kreis(_ r: CGFloat, um z: CGPoint? = nil) -> CGPath {
            let c = z ?? m
            return CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
        }
        func richtung(_ a: CGFloat) -> CGPoint { CGPoint(x: sin(a), y: cos(a)) }
        @discardableResult
        func form(_ eltern: CALayer, _ pfad: CGPath, fuellung: CGColor? = nil, strich: CGColor? = nil,
                  breite: CGFloat = 0, rund: Bool = false) -> CAShapeLayer {
            let e = CAShapeLayer()
            e.path = pfad
            e.fillColor = fuellung
            e.strokeColor = strich
            e.lineWidth = breite
            e.lineCap = rund ? .round : .butt
            eltern.addSublayer(e)
            return e
        }
        /// Striche von Radius `aussen` nach `innen`, für die Stellen `stellen` von `teile`.
        func strahlen(_ teile: Int, _ aussen: CGFloat, _ innen: CGFloat, nur: (Int) -> Bool = { _ in true }) -> CGPath {
            let s = CGMutablePath()
            for i in 0..<teile where nur(i) {
                let r = richtung(CGFloat(i) * 2 * .pi / CGFloat(teile))
                s.move(to: m + r * (d * aussen))
                s.addLine(to: m + r * (d * innen))
            }
            return s
        }
        func text(_ eltern: CALayer, _ t: String, _ f: NSFont, _ farbe: NSColor, mitte: CGPoint,
                  drehung: CGFloat = 0, sperrung: CGFloat = 0) {
            let e = CATextLayer()
            e.alignmentMode = .center
            e.contentsScale = 2
            beschrifte(e, t, f, farbe, mitte: mitte, drehung: drehung, sperrung: sperrung)
            eltern.addSublayer(e)
        }

        rand.path = kreis(d * 0.5)
        rand.fillColor = p.rand.cg
        blattEbene.path = kreis(blatt.blattRadius)
        blattEbene.fillColor = p.blatt.cg
        punkt.path = kreis(d * 0.016)
        punkt.fillColor = p.akzent.cg

        // Zifferblatt
        zier.frame = bounds
        zier.sublayers?.forEach { $0.removeFromSuperlayer() }
        if aussehen.bitcoin {
            // Blatt der Bitcoin-Uhr: dunkel, Lünette in Orange, ₿ als Wasserzeichen, Werte als Text.
            let orange = Ton(0xF7931A), gold = Ton(0xFFCC7A), elfenbein = Ton(0xF0E6D4)
            rand.fillColor = Ton(0x0B0B0C).cg
            blattEbene.fillColor = Ton(0x151517).cg
            form(zier, kreis(d * 0.491), strich: orange.cg, breite: d * 0.018)
            form(zier, kreis(d * 0.4985), strich: gold.alpha(0.7), breite: d * 0.003)
            form(zier, kreis(d * 0.481), strich: Ton(0x000000).alpha(0.7), breite: d * 0.004)
            form(zier, kreis(d * 0.422), strich: orange.alpha(0.28), breite: max(0.7, d * 0.002))
            text(zier, "₿", NSFont.systemFont(ofSize: d * 0.46, weight: .heavy), orange.ns(0.075),
                 mitte: m, drehung: -14 * .pi / 180)
            form(zier, strahlen(60, 0.445, 0.431, nur: { $0 % 5 != 0 }), strich: elfenbein.alpha(0.2), breite: d * 0.0028, rund: true)
            form(zier, strahlen(12, 0.440, 0.416), strich: elfenbein.alpha(0.5), breite: d * 0.005, rund: true)
            form(zier, strahlen(12, 0.410, 0.380, nur: { $0 % 3 != 0 }), strich: orange.alpha(0.85), breite: d * 0.006)
            form(zier, strahlen(12, 0.4175, 0.3725, nur: { $0 % 3 == 0 }), strich: orange.cg, breite: d * 0.009)
            text(zier, "BITCOIN", schrift(d * 0.042, .medium, .serif), orange.ns(0.85),
                 mitte: m + CGPoint(x: 0, y: d * 0.20), sperrung: d * 0.014)
            text(zier, "21 000 000", schrift(d * 0.024, .regular, .serif), elfenbein.ns(0.45),
                 mitte: m + CGPoint(x: 0, y: d * 0.155), sperrung: d * 0.005)
            let titel = schrift(d * 0.024, .medium, .serif)
            for (i, t) in ["BLOCK", "SAT/VB", "BTC · USD"].enumerated() {
                text(zier, t, titel, orange.ns(0.65), mitte: Self.btcPlatz(i, d: d, m: m) + CGPoint(x: 0, y: d * 0.028),
                     sperrung: d * 0.004)
            }
            for e in [btcBlock, btcGebuehren, btcKurs] { zier.addSublayer(e) }
        }
        switch aussehen.blatt {
        case _ where aussehen.bitcoin:
            break
        case .schlicht:
            form(zier, strahlen(12, 0.44, 0.395, nur: { $0 % 3 == 0 }), strich: p.strich.cg, breite: d * 0.006, rund: true)
            form(zier, strahlen(12, 0.44, 0.412, nur: { $0 % 3 != 0 }), strich: p.strich.cg, breite: d * 0.006, rund: true)
        case .punkte:
            for i in 0..<12 {
                let viertel = i % 3 == 0
                form(zier, kreis(d * (viertel ? 0.017 : 0.010), um: m + richtung(CGFloat(i) * .pi / 6) * (d * 0.42)),
                     fuellung: viertel ? p.akzent.cg : p.strich.cg)
            }
        case .ziffern:
            form(zier, strahlen(60, 0.447, 0.440, nur: { $0 % 5 != 0 }), strich: p.strich.alpha(0.55), breite: d * 0.005, rund: true)
            form(zier, strahlen(12, 0.450, 0.435), strich: p.strich.cg, breite: d * 0.007, rund: true)
            let f = schrift(d * 0.072, .semibold, .rounded)
            for i in 1...12 {
                text(zier, "\(i)", f, p.strich.ns(), mitte: m + richtung(CGFloat(i) * .pi / 6) * (d * 0.372))
            }
        case .balken:
            form(zier, strahlen(60, 0.445, 0.425, nur: { $0 % 5 != 0 }), strich: p.strich.alpha(0.6), breite: d * 0.004)
            form(zier, strahlen(12, 0.445, 0.355, nur: { $0 % 3 != 0 }), strich: p.strich.cg, breite: d * 0.020)
            form(zier, strahlen(12, 0.445, 0.335, nur: { $0 % 3 == 0 }), strich: p.akzent.cg, breite: d * 0.030)
        case .bigBen:
            // Goldring auf dem Rand, Minutenring, römische Ziffern nach außen gerichtet, Rosette in der Mitte.
            form(zier, kreis(d * 0.4825), strich: p.akzent.cg, breite: d * 0.010)
            form(zier, kreis(d * 0.455), strich: p.strich.cg, breite: d * 0.004)
            form(zier, kreis(d * 0.432), strich: p.strich.cg, breite: d * 0.004)
            form(zier, strahlen(60, 0.455, 0.432, nur: { $0 % 5 != 0 }), strich: p.strich.cg, breite: d * 0.003)
            form(zier, strahlen(12, 0.455, 0.432), strich: p.strich.cg, breite: d * 0.012)
            form(zier, kreis(d * 0.305), strich: p.strich.cg, breite: d * 0.004)
            form(zier, kreis(d * 0.292), strich: p.akzent.cg, breite: d * 0.004)
            form(zier, strahlen(24, 0.292, 0.150), strich: p.strich.alpha(0.28), breite: d * 0.003)
            form(zier, kreis(d * 0.150), strich: p.strich.alpha(0.45), breite: d * 0.003)
            form(zier, kreis(d * 0.075), strich: p.akzent.alpha(0.8), breite: d * 0.003)
            let f = schrift(d * 0.074, .semibold, .serif)
            let roemisch = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
            for i in 1...12 {
                let a = CGFloat(i) * .pi / 6
                text(zier, roemisch[i - 1], f, p.strich.ns(), mitte: m + richtung(a) * (d * 0.368), drehung: -a)
            }
        }

        // Komplikationen: Datum bei 3, Wochentag bei 9, Mondphase bei 12, kleine Sekunde bei 6.
        kompl.frame = bounds
        kompl.sublayers?.forEach { $0.removeFromSuperlayer() }
        kompl.isHidden = !aussehen.komplikationen
        if aussehen.komplikationen {
            func fenster(_ mitte: CGPoint, _ breite: CGFloat) {
                let r = CGRect(x: mitte.x - breite / 2, y: mitte.y - d * 0.036, width: breite, height: d * 0.072)
                let pfad = CGPath(roundedRect: r, cornerWidth: d * 0.012, cornerHeight: d * 0.012, transform: nil)
                form(kompl, pfad, fuellung: p.blatt.cg)
                form(kompl, pfad, fuellung: p.strich.alpha(0.07), strich: p.strich.alpha(0.6), breite: d * 0.004)
            }
            fenster(m + CGPoint(x: d * 0.235, y: 0), d * 0.095)
            fenster(m + CGPoint(x: -d * 0.235, y: 0), d * 0.105)
            kompl.addSublayer(datumText)
            kompl.addSublayer(tagText)

            let mondMitte = m + CGPoint(x: 0, y: d * 0.225)
            form(kompl, kreis(d * 0.052, um: mondMitte), fuellung: Ton(0x1B2340).cg, strich: p.strich.alpha(0.6), breite: d * 0.004)
            mond.position = mondMitte
            mond.fillColor = Ton(0xF5E9B8).cg
            kompl.addSublayer(mond)

            let sekMitte = m + CGPoint(x: 0, y: -d * 0.225)
            form(kompl, kreis(d * 0.062, um: sekMitte), fuellung: p.blatt.cg)
            form(kompl, kreis(d * 0.062, um: sekMitte), fuellung: p.strich.alpha(0.07), strich: p.strich.alpha(0.6), breite: d * 0.004)
            let teilung = CGMutablePath()
            for i in 0..<12 {
                let r = richtung(CGFloat(i) * .pi / 6)
                teilung.move(to: sekMitte + r * (d * 0.055))
                teilung.addLine(to: sekMitte + r * (d * (i % 3 == 0 ? 0.042 : 0.048)))
            }
            form(kompl, teilung, strich: p.strich.alpha(0.8), breite: d * 0.003)
            let nadel = CGMutablePath()
            nadel.move(to: CGPoint(x: 0, y: -d * 0.014))
            nadel.addLine(to: CGPoint(x: 0, y: d * 0.050))
            sekunde.path = nadel
            sekunde.position = sekMitte
            sekunde.strokeColor = p.akzent.cg
            sekunde.lineWidth = d * 0.005
            sekunde.lineCap = .round
            kompl.addSublayer(sekunde)
            form(kompl, kreis(d * 0.007, um: sekMitte), fuellung: p.akzent.cg)
        }

        func zeiger(_ laenge: CGFloat, _ breiteUnten: CGFloat, _ breiteOben: CGFloat) -> CGPath {
            let z = CGMutablePath()
            z.move(to: CGPoint(x: -breiteUnten / 2, y: -d * 0.03))
            z.addLine(to: CGPoint(x: breiteUnten / 2, y: -d * 0.03))
            z.addLine(to: CGPoint(x: breiteOben / 2, y: laenge))
            z.addLine(to: CGPoint(x: -breiteOben / 2, y: laenge))
            z.closeSubpath()
            return z
        }
        stundenzeiger.position = m
        stundenzeiger.path = zeiger(d * 0.21, d * 0.020, d * 0.012)
        stundenzeiger.fillColor = aussehen.bitcoin ? Ton(0xF7931A).cg : p.zeiger.cg
        minutenzeiger.position = m
        minutenzeiger.path = zeiger(blatt.zeigerLaenge, d * 0.014, d * 0.006)
        minutenzeiger.fillColor = p.zeiger.cg

        glieder.lineWidth = d * 0.0125
        glieder.strokeColor = p.tinte.cg
        kopf.fillColor = p.tinte.cg
        zeile1.frame = CGRect(x: 0, y: h * 0.855, width: w, height: w * 0.075)
        zeile2.frame = CGRect(x: 0, y: h * 0.790, width: w, height: w * 0.085)
        textSchluessel = ""
        komplSchluessel = ""
        CATransaction.commit()
        stelleBitcoinWerte()
    }

    // MARK: Stellen

    /// Stellt die Uhr.
    /// - blend: fester Stand der Dauerbewegung (Vorführung, Standbild). `nil` startet die Animation.
    func stelle(datum: Date, stunde: Int, minute: Double, stundenNummer: Int, blend: CGFloat?) {
        let bewegung = Bewegung.bei(minute: minute)
        let spruch = Texte.spruch(aussehen.sprache, bewegung: bewegung, stundenNummer: stundenNummer,
                                  bitcoin: aussehen.bitcoin)
        let p = aussehen.farbe.palette
        let g = aussehen.gestalt

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        minutenzeiger.setAffineTransform(CGAffineTransform(rotationAngle: -CGFloat(minute) * .pi / 30))
        let stundenWinkel = (CGFloat(stunde % 12) + CGFloat(minute) / 60) * .pi / 6
        stundenzeiger.setAffineTransform(CGAffineTransform(rotationAngle: -stundenWinkel))

        let r = blatt.d * 0.021
        if let blend {
            let s = Figur.skelett(bewegung: bewegung, minute: minute, b: blend, blatt: blatt)
            glieder.removeAnimation(forKey: "takt")
            kopf.removeAnimation(forKey: "takt")
            glieder.path = s.glieder(g, r: r)
            kopf.path = s.kopfPfad(g, radius: r)
        } else {
            let a = Figur.skelett(bewegung: bewegung, minute: minute, b: 0, blatt: blatt)
            let b = Figur.skelett(bewegung: bewegung, minute: minute, b: 1, blatt: blatt)
            pendle(glieder, von: a.glieder(g, r: r), nach: b.glieder(g, r: r), takt: bewegung.takt)
            pendle(kopf, von: a.kopfPfad(g, radius: r), nach: b.kopfPfad(g, radius: r), takt: bewegung.takt)
        }
        if aussehen.komplikationen { stelleKomplikationen(datum, laufend: blend == nil) }
        CATransaction.commit()

        // Farbwechsel und Text blenden weich.
        CATransaction.begin()
        CATransaction.setAnimationDuration(blend == nil ? 1.2 : 0.3)
        karte.colors = (bewegung.dunkel ? p.dunkel : p.hell).map(\.cg)
        let schluessel = "\(bewegung.rawValue)-\(stundenNummer)-\(bounds.width)"
        if schluessel != textSchluessel {
            textSchluessel = schluessel
            setze(zeile1, spruch.oben, fett: false, dunkel: bewegung.dunkel)
            setze(zeile2, spruch.unten, fett: true, dunkel: bewegung.dunkel)
        }
        zeile2.opacity = minute - bewegung.start >= 1 ? 1 : 0
        CATransaction.commit()
    }

    private func stelleKomplikationen(_ datum: Date, laufend: Bool) {
        let p = aussehen.farbe.palette
        let d = blatt.d, m = blatt.mitte
        let kal = Calendar.current
        let tag = kal.component(.day, from: datum)
        let schluessel = "\(tag)-\(Int(datum.timeIntervalSince1970 / 3600))"
        if schluessel != komplSchluessel {
            komplSchluessel = schluessel
            let f = DateFormatter()
            f.locale = aussehen.sprache.locale
            f.dateFormat = "EEE"
            let wochentag = f.string(from: datum).replacingOccurrences(of: ".", with: "")
                .uppercased(with: f.locale).prefix(3)
            beschrifte(datumText, "\(tag)", schrift(d * 0.050, .bold, .rounded), p.strich.ns(),
                       mitte: m + CGPoint(x: d * 0.235, y: 0))
            beschrifte(tagText, String(wochentag), schrift(d * 0.036, .bold, .rounded), p.akzent.ns(),
                       mitte: m + CGPoint(x: -d * 0.235, y: 0))
            mond.path = Self.mondPfad(phase: Self.mondphase(datum), radius: d * 0.046)
        }

        let k = kal.dateComponents([.second, .nanosecond], from: datum)
        let sek = Double(k.second ?? 0) + Double(k.nanosecond ?? 0) / 1e9
        if laufend {
            sekunde.setAffineTransform(.identity)
            let anim = CABasicAnimation(keyPath: "transform.rotation.z")
            anim.fromValue = 0
            anim.toValue = -2 * Double.pi
            anim.duration = 60
            anim.repeatCount = .infinity
            anim.beginTime = sekunde.convertTime(CACurrentMediaTime(), from: nil) - sek
            sekunde.add(anim, forKey: "lauf")
        } else {
            sekunde.removeAnimation(forKey: "lauf")
            sekunde.setAffineTransform(CGAffineTransform(rotationAngle: -CGFloat(sek) * .pi / 30))
        }
    }

    /// Mondphase: 0 Neumond, 0,5 Vollmond. Bezug: Neumond am 6. Januar 2000, 18:14 UTC.
    static func mondphase(_ datum: Date) -> Double {
        let tage = (datum.timeIntervalSince1970 - 947_182_440) / 86_400
        let p = (tage / 29.530588853).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    /// Beleuchtete Fläche um den Nullpunkt. Zunehmend ist rechts hell (Nordhalbkugel).
    static func mondPfad(phase: Double, radius r: CGFloat) -> CGPath {
        let pfad = CGMutablePath()
        let k = CGFloat(cos(2 * Double.pi * phase))
        let spiegel: CGFloat = phase <= 0.5 ? 1 : -1
        let schritte = 24
        for i in 0...schritte {
            let t = CGFloat(i) * .pi / CGFloat(schritte)
            let q = CGPoint(x: spiegel * r * sin(t), y: r * cos(t))
            if i == 0 { pfad.move(to: q) } else { pfad.addLine(to: q) }
        }
        for i in stride(from: schritte, through: 0, by: -1) {
            let t = CGFloat(i) * .pi / CGFloat(schritte)
            pfad.addLine(to: CGPoint(x: spiegel * r * k * sin(t), y: r * cos(t)))
        }
        pfad.closeSubpath()
        return pfad
    }

    /// Dauerbewegung zwischen zwei Haltungen. Der Beginn hängt an der absoluten Zeit,
    /// damit die Bewegung beim Nachstellen nicht springt.
    private func pendle(_ ebene: CAShapeLayer, von a: CGPath, nach b: CGPath, takt: Double) {
        ebene.path = a
        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = a
        anim.toValue = b
        anim.duration = takt
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        let jetzt = ebene.convertTime(CACurrentMediaTime(), from: nil)
        anim.beginTime = jetzt - jetzt.truncatingRemainder(dividingBy: 2 * takt)
        ebene.add(anim, forKey: "takt")
    }

    private func setze(_ ebene: CATextLayer, _ text: String, fett: Bool, dunkel: Bool) {
        let w = bounds.width
        let p = aussehen.farbe.palette
        let grundfarbe = dunkel ? p.textDunkel.ns(fett ? 1 : 0.85) : p.textHell.ns(fett ? 1 : 0.75)
        let akzent = (dunkel ? p.akzentDunkel : p.akzent).ns()
        func baue(_ groesse: CGFloat) -> NSAttributedString {
            let f = schrift(groesse, fett ? .bold : .regular, .rounded)
            let ergebnis = NSMutableAttributedString()
            for (i, teil) in text.components(separatedBy: "*").enumerated() {
                ergebnis.append(NSAttributedString(string: teil, attributes: [
                    .font: f,
                    .foregroundColor: i % 2 == 1 ? akzent : grundfarbe,
                ]))
            }
            return ergebnis
        }
        var groesse = w * (fett ? 0.058 : 0.050)
        var s = baue(groesse)
        let platz = w * 0.90
        if s.size().width > platz {
            groesse *= platz / s.size().width
            s = baue(groesse)
        }
        ebene.string = s
    }

    /// Standbild der Ebenen, ohne Bildschirmaufnahme.
    func bild(skala: CGFloat) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: Int(bounds.width * skala), height: Int(bounds.height * skala),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: skala, y: skala)
        layer?.render(in: ctx)
        return ctx.makeImage()
    }
}
