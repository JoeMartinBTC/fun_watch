import Foundation

/// Die sechs Bewegungen der Figur. Jede gehört zu einem Abschnitt der Stunde,
/// also zu einer Stellung des Minutenzeigers.
enum Bewegung: Int, CaseIterable {
    case balancieren, schwingen, rutschen, stemmen, mitfahren, klettern

    /// Erste Minute des Abschnitts.
    var start: Double {
        switch self {
        case .balancieren: return 0
        case .schwingen: return 7
        case .rutschen: return 18
        case .stemmen: return 27
        case .mitfahren: return 34
        case .klettern: return 49
        }
    }

    /// Dunkler Hintergrund, wenn es der Figur schlecht geht.
    var dunkel: Bool { self == .rutschen || self == .stemmen }

    /// Dauer einer halben Schwingung der Dauerbewegung in Sekunden.
    var takt: Double {
        switch self {
        case .balancieren: return 1.1
        case .schwingen: return 1.3
        case .rutschen: return 0.45
        case .stemmen: return 0.9
        case .mitfahren: return 1.2
        case .klettern: return 0.7
        }
    }

    static func bei(minute: Double) -> Bewegung {
        let m = minute.truncatingRemainder(dividingBy: 60)
        return allCases.last { m >= $0.start } ?? .balancieren
    }
}

/// Zwei Zeilen: oben ruhig, unten fett. `*…*` markiert das farbige Wort.
struct Spruch: Equatable {
    let oben: String
    let unten: String
}

enum Texte {
    static let proBewegung = 12

    /// Die zwölf Sprüche einer Bewegung in einer Sprache. Quelle: `Sprueche.roh`,
    /// je Sprache 72 Zeilen „oben|unten“ in der Reihenfolge der Bewegungen.
    static func liste(_ sprache: Sprache, _ bewegung: Bewegung, bitcoin: Bool = false) -> [Spruch] {
        let roh = (bitcoin ? Sprueche.bitcoin : Sprueche.roh)[sprache] ?? []
        let ab = bewegung.rawValue * proBewegung
        guard roh.count >= ab + proBewegung else { return [] }
        return roh[ab..<(ab + proBewegung)].map { zeile in
            let teile = zeile.components(separatedBy: "|")
            return Spruch(oben: teile[0], unten: teile.count > 1 ? teile[1] : "")
        }
    }

    /// Fortlaufende Nummer der Stunde seit 1970. Unabhängig von Zeitzone und Sommerzeit,
    /// deshalb gibt es keine doppelte Stunde.
    static func stundenNummer(_ datum: Date) -> Int {
        Int((datum.timeIntervalSince1970 / 3600).rounded(.down))
    }

    /// Welcher der zwölf Sprüche in dieser Stunde für diese Bewegung gilt.
    static func index(bewegung: Bewegung, stundenNummer n: Int) -> Int {
        Zufallsfolge.index(nummer: n, anzahl: proBewegung, salz: bewegung.rawValue)
    }

    static func spruch(_ sprache: Sprache, bewegung: Bewegung, stundenNummer n: Int, bitcoin: Bool = false) -> Spruch {
        let l = liste(sprache, bewegung, bitcoin: bitcoin)
        return l.isEmpty ? Spruch(oben: "", unten: "") : l[index(bewegung: bewegung, stundenNummer: n)]
    }

    /// Prüft Bestand und Reihenfolge. Gibt die Liste der Fehler zurück; leer heißt in Ordnung.
    static func selbsttest(stunden: Int = 24 * 800) -> [String] {
        var fehler: [String] = []
        for sprache in Sprache.allCases {
            for bitcoin in [false, true] {
                let name = "\(sprache)\(bitcoin ? " bitcoin" : "")"
                var gesehen = Set<String>()
                let roh = (bitcoin ? Sprueche.bitcoin : Sprueche.roh)[sprache] ?? []
                if roh.count != proBewegung * Bewegung.allCases.count { fehler.append("\(name): \(roh.count) Zeilen statt 72") }
                for z in roh where z.filter({ $0 == "|" }).count != 1 { fehler.append("\(name): Trenner falsch: \(z)") }
                for b in Bewegung.allCases {
                    let l = liste(sprache, b, bitcoin: bitcoin)
                    if l.count != proBewegung { fehler.append("\(name) \(b): \(l.count) Sprüche statt \(proBewegung)") }
                    for s in l {
                        if s.oben.isEmpty || s.unten.filter({ $0 == "*" }).count != 2 || s.oben.contains("*") {
                            fehler.append("\(name): Markierung falsch: \(s.oben) / \(s.unten)")
                        }
                        if !gesehen.insert(s.oben + "|" + s.unten).inserted { fehler.append("\(name): doppelt: \(s.oben)") }
                    }
                }
            }
            let menue = MenueTexte.alle[sprache] ?? []
            if menue.count != M.allCases.count || menue.contains(where: \.isEmpty) {
                fehler.append("\(sprache): Menü hat \(menue.count) Einträge statt \(M.allCases.count)")
            }
        }
        guard fehler.isEmpty else { return fehler }

        // Reihenfolge: Sprüche je Bewegung, dazu Farbe, Zifferblatt und Figur im Stundenwechsel.
        var folgen: [(name: String, anzahl: Int, salz: Int)] =
            Bewegung.allCases.map { ("\($0)", proBewegung, $0.rawValue) }
        folgen.append(("Farbe", Farbwelt.allCases.count, 101))
        folgen.append(("Zifferblatt", Blattart.allCases.count, 102))
        folgen.append(("Figur", Gestalt.allCases.count, 103))
        let jetzt = stundenNummer(Date())
        for f in folgen {
            // Start auf einer Blockgrenze, dann muss jeder Eintrag exakt gleich oft kommen.
            let start = (jetzt / f.anzahl - 60) * f.anzahl
            let laenge = stunden / f.anzahl * f.anzahl
            var direktNacheinander = 0
            var haeufigkeit = [Int](repeating: 0, count: f.anzahl)
            var vorher = Zufallsfolge.index(nummer: start - 1, anzahl: f.anzahl, salz: f.salz)
            for n in start..<(start + laenge) {
                let i = Zufallsfolge.index(nummer: n, anzahl: f.anzahl, salz: f.salz)
                if i == vorher { direktNacheinander += 1 }
                haeufigkeit[i] += 1
                vorher = i
            }
            if direktNacheinander != 0 { fehler.append("\(f.name): \(direktNacheinander)-mal dasselbe direkt nacheinander") }
            if haeufigkeit.max()! != haeufigkeit.min()! { fehler.append("\(f.name): ungleich verteilt \(haeufigkeit)") }
        }
        return fehler
    }
}
