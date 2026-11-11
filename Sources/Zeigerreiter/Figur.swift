import CoreGraphics
import Foundation

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var laenge: CGFloat { (x * x + y * y).squareRoot() }
    var einheit: CGPoint { laenge < 1e-9 ? CGPoint(x: 0, y: -1) : self * (1 / laenge) }
    /// Drehung gegen den Uhrzeigersinn (y zeigt nach oben).
    func gedreht(_ w: CGFloat) -> CGPoint {
        CGPoint(x: x * cos(w) - y * sin(w), y: x * sin(w) + y * cos(w))
    }
}

/// Lage und Größe des Zifferblatts. Alle Maße der Figur hängen am Durchmesser.
struct Zifferblatt {
    let mitte: CGPoint
    let d: CGFloat
    var zeigerLaenge: CGFloat { d * 0.36 }
    var blattRadius: CGFloat { d * 0.465 }
}

/// Die Gelenkpunkte des Strichmännchens.
struct Skelett {
    var kopf, hals, huefte: CGPoint
    var ellL, handL, ellR, handR: CGPoint
    var knieL, fussL, knieR, fussR: CGPoint

    /// Rumpf, Arme und Beine als ein Pfad. Die Reihenfolge ist fest,
    /// damit Core Animation zwischen zwei Haltungen überblenden kann.
    /// `g` und `r` (Kopfradius) ergänzen die gezeichneten Teile des Kostüms: Schwanz, Antenne.
    func glieder(_ g: Gestalt = .mensch, r: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        p.move(to: hals); p.addLine(to: huefte)
        p.move(to: hals); p.addLine(to: ellL); p.addLine(to: handL)
        p.move(to: hals); p.addLine(to: ellR); p.addLine(to: handR)
        p.move(to: huefte); p.addLine(to: knieL); p.addLine(to: fussL)
        p.move(to: huefte); p.addLine(to: knieR); p.addLine(to: fussR)
        switch g {
        case .katze:
            p.move(to: huefte)
            p.addQuadCurve(to: huefte + seite * (3.0 * r) - ab * (1.8 * r),
                           control: huefte + seite * (2.4 * r) + ab * (1.0 * r))
        case .affe:
            p.move(to: huefte)
            p.addQuadCurve(to: huefte + seite * (3.2 * r) + ab * (0.6 * r),
                           control: huefte + seite * (1.6 * r) + ab * (1.8 * r))
            p.addQuadCurve(to: huefte + seite * (2.6 * r) - ab * (1.2 * r),
                           control: huefte + seite * (4.0 * r) - ab * (1.0 * r))
        case .roboter:
            p.move(to: kopf + auf * (0.95 * r)); p.addLine(to: kopf + auf * (1.9 * r))
        case .mensch, .hase:
            break
        }
        return p
    }

    /// Kopf und gefüllte Teile des Kostüms: Ohren, Bommel, Antennenkugel.
    /// Alle Teilflächen laufen gegen den Uhrzeigersinn, damit Überlappungen gefüllt bleiben.
    func kopfPfad(_ g: Gestalt = .mensch, radius r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        func oval(_ mitte: CGPoint, _ achse: CGPoint, _ lang: CGFloat, _ breit: CGFloat) {
            let quer = achse.gedreht(.pi / 2)
            for i in 0..<32 {
                let t = CGFloat(i) * .pi / 16
                let q = mitte + achse * (cos(t) * lang) + quer * (sin(t) * breit)
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
        }
        func rund(_ mitte: CGPoint, _ radius: CGFloat) { oval(mitte, CGPoint(x: 1, y: 0), radius, radius) }
        let rechts = auf.gedreht(-.pi / 2)
        switch g {
        case .mensch:
            rund(kopf, r)
        case .katze:
            rund(kopf, r)
            for s in [CGFloat(1), -1] {
                let innen = kopf + auf.gedreht(s * 0.25) * (0.9 * r)
                let aussen = kopf + auf.gedreht(s * 1.05) * (0.9 * r)
                let spitze = kopf + auf.gedreht(s * 0.65) * (1.75 * r)
                p.move(to: s > 0 ? innen : aussen)
                p.addLine(to: spitze)
                p.addLine(to: s > 0 ? aussen : innen)
                p.closeSubpath()
            }
        case .affe:
            rund(kopf, r)
            rund(kopf + rechts * (1.05 * r), 0.5 * r)
            rund(kopf - rechts * (1.05 * r), 0.5 * r)
        case .hase:
            rund(kopf, r)
            for s in [CGFloat(1), -1] {
                let achse = auf.gedreht(s * 0.28)
                oval(kopf + achse * (2.1 * r), achse, 1.25 * r, 0.42 * r)
            }
            rund(huefte + seite * (0.9 * r), 0.55 * r)
        case .roboter:
            p.move(to: kopf - auf * r + rechts * (1.05 * r))
            p.addLine(to: kopf + auf * r + rechts * (1.05 * r))
            p.addLine(to: kopf + auf * r - rechts * (1.05 * r))
            p.addLine(to: kopf - auf * r - rechts * (1.05 * r))
            p.closeSubpath()
            rund(kopf + auf * (2.1 * r), 0.34 * r)
        }
        return p
    }

    private var auf: CGPoint { (kopf - hals).einheit }
    private var ab: CGPoint { (huefte - hals).einheit }
    /// Rückenseite für Schwanz und Bommel.
    private var seite: CGPoint { ab.gedreht(-.pi / 2) }
}

enum Figur {
    /// Haltung der Figur.
    /// - minute: Minute der Stunde mit Bruchteil, bestimmt den Zeigerwinkel.
    /// - b: Stand der Dauerbewegung, 0 und 1 sind die beiden Endhaltungen.
    static func skelett(bewegung: Bewegung, minute: Double, b: CGFloat, blatt: Zifferblatt) -> Skelett {
        let d = blatt.d * 1.22                                   // Figur etwas größer als das Raster
        let theta = CGFloat(minute) * .pi / 30
        let u = CGPoint(x: sin(theta), y: cos(theta))            // Richtung des Minutenzeigers
        var n = CGPoint(x: -cos(theta), y: sin(theta))           // Seite des Zeigers, die nach oben zeigt
        if n.y < 0 { n = n * -1 }
        let L = blatt.zeigerLaenge
        func aufZeiger(_ s: CGFloat) -> CGPoint { blatt.mitte + u * (min(s, 1) * L) }
        /// Pendelrichtung: 0 hängt gerade nach unten, positiv schwingt nach rechts.
        func pendel(_ phi: CGFloat) -> CGPoint { CGPoint(x: sin(phi), y: -cos(phi)) }

        let kopfAbstand = d * 0.023
        let rumpf = d * 0.052
        let arm = d * 0.028, bein = d * 0.034
        let fortschritt = CGFloat((minute - bewegung.start) / dauer(bewegung))

        var hals = CGPoint.zero, huefte = CGPoint.zero, kopf = CGPoint.zero
        var zielHandL = CGPoint.zero, zielHandR = CGPoint.zero
        var zielFussL = CGPoint.zero, zielFussR = CGPoint.zero
        var armSeite: (CGFloat, CGFloat) = (1, -1)
        var beinSeite: (CGFloat, CGFloat) = (1, 1)

        switch bewegung {
        case .balancieren:
            // Steht auf einem Bein auf der Zeigerspitze und rudert mit den Armen.
            let spitze = aufZeiger(1)
            let schwank = b - 0.5
            huefte = spitze + CGPoint(x: schwank * d * 0.02, y: 2 * bein * 0.97)
            let richtung = CGPoint(x: -schwank * 0.3, y: 1).einheit
            hals = huefte + richtung * rumpf
            kopf = hals + richtung * kopfAbstand
            zielFussL = spitze
            zielFussR = huefte + pendel(0.55 + 0.5 * b) * (2 * bein * 0.9)
            zielHandL = hals + CGPoint(x: -d * 0.052, y: d * (0.012 + schwank * 0.05))
            zielHandR = hals + CGPoint(x: d * 0.052, y: d * (0.012 - schwank * 0.05))
            beinSeite = (-1, 1)

        case .schwingen:
            // Hängt mit beiden Händen am Zeiger und schwingt.
            let griff = aufZeiger(0.80)
            let phi = (b - 0.5) * 0.9
            hals = griff + pendel(phi) * (2 * arm * 0.96)
            huefte = hals + pendel(phi) * rumpf
            kopf = hals - pendel(phi) * kopfAbstand
            zielHandL = griff - u * (d * 0.012)
            zielHandR = griff + u * (d * 0.012)
            zielFussL = huefte + pendel(phi * 1.6 + 0.18) * (2 * bein * 0.93)
            zielFussR = huefte + pendel(phi * 1.6 - 0.18) * (2 * bein * 0.93)

        case .rutschen:
            // Hängt an einer Hand, rutscht den Zeiger hinab und zappelt.
            let griff = aufZeiger(0.80 - 0.28 * fortschritt)
            let phi = (b - 0.5) * 0.5
            hals = griff + pendel(phi) * (2 * arm * 0.96)
            huefte = hals + pendel(phi) * rumpf
            kopf = hals - pendel(phi + 0.5) * kopfAbstand
            zielHandL = griff
            zielHandR = hals + pendel(1.9 + 1.0 * b) * (2 * arm * 0.92)
            zielFussL = huefte + pendel(phi + 0.7 * b - 0.2) * (2 * bein * 0.85)
            zielFussR = huefte + pendel(phi - 0.7 * b + 0.3) * (2 * bein * 0.85)

        case .stemmen:
            // Steht am Rand des Blatts vor dem Zeiger und drückt dagegen.
            let rg = blatt.blattRadius - d * 0.008
            func amRand(_ a: CGFloat) -> CGPoint { blatt.mitte + CGPoint(x: sin(a), y: cos(a)) * rg }
            let aVorn = theta + 0.17, aHinten = theta + 0.31, aMitte = theta + 0.24
            zielFussL = amRand(aVorn)
            zielFussR = amRand(aHinten)
            let nachInnen = CGPoint(x: -sin(aMitte), y: -cos(aMitte))
            let zumZeiger = CGPoint(x: -cos(aMitte), y: sin(aMitte))
            huefte = amRand(aMitte) + nachInnen * (2 * bein * 0.80) + zumZeiger * (d * (0.004 + 0.012 * b))
            zielHandL = aufZeiger(0.99)
            zielHandR = aufZeiger(0.91)
            let richtung = ((zielHandL - huefte).einheit * 0.75 + nachInnen * 0.65).einheit
            hals = huefte + richtung * rumpf
            kopf = hals + (richtung * 0.6 + nachInnen * 0.6).einheit * kopfAbstand
            armSeite = (-1, -1)
            beinSeite = (-1, -1)

        case .mitfahren:
            // Sitzt auf dem Zeiger, lässt die Beine baumeln und winkt.
            let s: CGFloat = 0.60
            huefte = aufZeiger(s) + n * (d * 0.012)
            let richtung = (n * 0.6 + CGPoint(x: 0, y: 0.6) - u * (0.10 + 0.12 * b)).einheit
            hals = huefte + richtung * rumpf
            kopf = hals + richtung * kopfAbstand
            let knie = huefte + (u * 0.9 - n * 0.25).einheit * bein
            zielFussL = knie + pendel((b - 0.5) * 0.9) * bein
            zielFussR = knie + pendel(-(b - 0.5) * 0.9 + 0.1) * bein
            zielHandL = aufZeiger(s - d * 0.05 / L) + n * (d * 0.004)
            zielHandR = hals + richtung.gedreht(0.7 + 0.6 * b) * (2 * arm * 0.95)
            armSeite = (1, -1)
            beinSeite = (-1, -1)

        case .klettern:
            // Klettert Hand über Hand zur Spitze.
            let s = 0.42 + 0.36 * fortschritt
            huefte = aufZeiger(s) - u * (d * 0.03) + n * (d * 0.024)
            hals = huefte + (u * 0.95 + n * 0.05).einheit * rumpf
            kopf = hals + (u * 0.75 + n * 0.65).einheit * kopfAbstand
            zielHandL = aufZeiger(s + d * (0.045 + 0.025 * b) / L)
            zielHandR = aufZeiger(s + d * (0.070 - 0.025 * b) / L)
            zielFussL = aufZeiger(s - d * (0.075 - 0.03 * b) / L)
            zielFussR = aufZeiger(s - d * (0.045 + 0.03 * b) / L)
            // Knie und Ellbogen knicken vom Zeiger weg.
            let weg: CGFloat = (u.x * n.y - u.y * n.x) > 0 ? 1 : -1
            armSeite = (weg, weg)
            beinSeite = (weg, weg)
        }

        let (ellL, handL) = knick(hals, zielHandL, arm, arm, armSeite.0)
        let (ellR, handR) = knick(hals, zielHandR, arm, arm, armSeite.1)
        let (knieL, fussL) = knick(huefte, zielFussL, bein, bein, beinSeite.0)
        let (knieR, fussR) = knick(huefte, zielFussR, bein, bein, beinSeite.1)
        return Skelett(kopf: kopf, hals: hals, huefte: huefte,
                       ellL: ellL, handL: handL, ellR: ellR, handR: handR,
                       knieL: knieL, fussL: fussL, knieR: knieR, fussR: fussR)
    }

    static func dauer(_ b: Bewegung) -> Double {
        let alle = Bewegung.allCases
        let ende = b.rawValue + 1 < alle.count ? alle[b.rawValue + 1].start : 60
        return ende - b.start
    }

    /// Zwei Glieder zwischen `a` und `ziel`: liefert das Gelenk und das erreichte Ende.
    /// `seite` (+1 oder −1) bestimmt, nach welcher Seite das Gelenk knickt.
    static func knick(_ a: CGPoint, _ ziel: CGPoint, _ l1: CGFloat, _ l2: CGFloat, _ seite: CGFloat) -> (CGPoint, CGPoint) {
        let r = (ziel - a).einheit
        let dist = min(max((ziel - a).laenge, abs(l1 - l2) + 0.001), (l1 + l2) * 0.999)
        let cosA = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
        let w = acos(max(-1, min(1, cosA))) * seite
        return (a + r.gedreht(w) * l1, a + r * dist)
    }
}
