import AppKit

/// Farbe aus einer Hex-Zahl, z. B. 0xF7931A.
struct Ton: Equatable {
    let hex: UInt32
    init(_ hex: UInt32) { self.hex = hex }
    private var teile: (CGFloat, CGFloat, CGFloat) {
        (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
    }
    var cg: CGColor { alpha(1) }
    func alpha(_ a: CGFloat) -> CGColor { CGColor(srgbRed: teile.0, green: teile.1, blue: teile.2, alpha: a) }
    func ns(_ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: teile.0, green: teile.1, blue: teile.2, alpha: a) }
}

/// Alle Farben einer Farbwelt. „hell“ und „dunkel“ sind die beiden Stimmungen der Karte.
struct Palette {
    let hell: [Ton], dunkel: [Ton]
    let rand, blatt, strich, zeiger: Ton
    let akzent, akzentDunkel: Ton
    let tinte: Ton
    let textHell, textDunkel: Ton
}

enum Farbwelt: String, CaseIterable {
    case salbei, bitcoin, nacht, sand, westminster, schiefer

    var titel: String {
        switch self {
        case .salbei: return "Salbei"
        case .bitcoin: return "Bitcoin"
        case .nacht: return "Nacht"
        case .sand: return "Sand"
        case .westminster: return "Westminster"
        case .schiefer: return "Schiefer"
        }
    }

    var palette: Palette {
        switch self {
        case .salbei:
            return Palette(hell: [Ton(0xF7F5EB), Ton(0xE3E6D9)], dunkel: [Ton(0x3D6357), Ton(0x264238)],
                           rand: Ton(0xB3BFB5), blatt: Ton(0xFAF7ED), strich: Ton(0x45544D), zeiger: Ton(0x334540),
                           akzent: Ton(0x548C70), akzentDunkel: Ton(0xCCDE9E), tinte: Ton(0x1C1F1F),
                           textHell: Ton(0x2B3530), textDunkel: Ton(0xEDEDE0))
        case .bitcoin:
            // Karte in beiden Stimmungen dunkel: die helle Figur ragt oben über das Blatt hinaus.
            return Palette(hell: [Ton(0x2E2E31), Ton(0x1A1A1C)], dunkel: [Ton(0x4A2A05), Ton(0x1F1203)],
                           rand: Ton(0xF7931A), blatt: Ton(0x141416), strich: Ton(0xF7931A), zeiger: Ton(0xEDE8DB),
                           akzent: Ton(0xF7931A), akzentDunkel: Ton(0xFFB347), tinte: Ton(0xF7F2E6),
                           textHell: Ton(0xF2EDE0), textDunkel: Ton(0xF2EDE0))
        case .nacht:
            return Palette(hell: [Ton(0xE6EBF7), Ton(0xCCD6ED)], dunkel: [Ton(0x1A2447), Ton(0x0A0F26)],
                           rand: Ton(0xC7A861), blatt: Ton(0xF5F2E6), strich: Ton(0x1F294D), zeiger: Ton(0x1F294D),
                           akzent: Ton(0xB38F33), akzentDunkel: Ton(0xEDCC73), tinte: Ton(0x141726),
                           textHell: Ton(0x1F294D), textDunkel: Ton(0xEBEDF5))
        case .sand:
            return Palette(hell: [Ton(0xFAF2E3), Ton(0xEDDBC2)], dunkel: [Ton(0x8C4D38), Ton(0x5C2E21)],
                           rand: Ton(0xCC9E7A), blatt: Ton(0xFCF7ED), strich: Ton(0x593D33), zeiger: Ton(0x593D33),
                           akzent: Ton(0xC75C3D), akzentDunkel: Ton(0xFAD19E), tinte: Ton(0x261A17),
                           textHell: Ton(0x40302B), textDunkel: Ton(0xFAF0E0))
        case .westminster:
            return Palette(hell: [Ton(0xEDE8D6), Ton(0xD6CFB8)], dunkel: [Ton(0x292926), Ton(0x121212)],
                           rand: Ton(0x1F1F1F), blatt: Ton(0xF7F2E0), strich: Ton(0x1A1A1A), zeiger: Ton(0x1A1A1A),
                           akzent: Ton(0xB88F33), akzentDunkel: Ton(0xE6C261), tinte: Ton(0x9E1A1A),
                           textHell: Ton(0x262420), textDunkel: Ton(0xF0EBD9))
        case .schiefer:
            return Palette(hell: [Ton(0xF2F2F2), Ton(0xDBDBDE)], dunkel: [Ton(0x383B40), Ton(0x1C1F21)],
                           rand: Ton(0x8C8F94), blatt: Ton(0xFFFFFF), strich: Ton(0x33363B), zeiger: Ton(0x33363B),
                           akzent: Ton(0xD94D40), akzentDunkel: Ton(0xFF8C73), tinte: Ton(0x1A1A1A),
                           textHell: Ton(0x2E3033), textDunkel: Ton(0xF0F0F2))
        }
    }
}

enum Blattart: String, CaseIterable {
    case schlicht, punkte, ziffern, balken, bigBen

    var titel: String {
        switch self {
        case .schlicht: return "Schlicht"
        case .punkte: return "Punkte"
        case .ziffern: return "Ziffern"
        case .balken: return "Balken"
        case .bigBen: return "Big Ben"
        }
    }
}

enum Gestalt: String, CaseIterable {
    case mensch, katze, affe, hase, roboter

    var titel: String {
        switch self {
        case .mensch: return "Strichmännchen"
        case .katze: return "Katze"
        case .affe: return "Affe"
        case .hase: return "Hase"
        case .roboter: return "Roboter"
        }
    }
}

enum Sprache: String, CaseIterable {
    case de, en, fr, es, it, pt, nl, tr, zh, ja, ko, hi

    /// Für Wochentag und Zahlenformat.
    var locale: Locale { Locale(identifier: self == .zh ? "zh_Hans" : rawValue) }

    var titel: String {
        switch self {
        case .zh: return "中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .hi: return "हिन्दी"
        case .de: return "Deutsch"
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .nl: return "Nederlands"
        case .tr: return "Türkçe"
        }
    }

    /// Sprache des Systems, sonst Deutsch.
    static var system: Sprache {
        Sprache(rawValue: String((Locale.preferredLanguages.first ?? "de").prefix(2))) ?? .de
    }
}

/// Alles, was der Nutzer am Aussehen wählen kann.
struct Aussehen: Equatable {
    var farbe: Farbwelt = .salbei
    var blatt: Blattart = .schlicht
    var gestalt: Gestalt = .mensch
    var sprache: Sprache = .de
    var komplikationen = false
    /// Bitcoin-Modus: Blatt der Bitcoin-Uhr, Block, sat/vB und Kurs, Bitcoin-Sprüche.
    var bitcoin = false
    /// Stündlicher Wechsel statt fester Wahl.
    var wechselFarbe = false, wechselBlatt = false, wechselGestalt = false

    static func laden() -> Aussehen {
        let ud = UserDefaults.standard
        var a = Aussehen()
        a.farbe = Farbwelt(rawValue: ud.string(forKey: "farbe") ?? "") ?? .salbei
        a.blatt = Blattart(rawValue: ud.string(forKey: "blatt") ?? "") ?? .schlicht
        a.gestalt = Gestalt(rawValue: ud.string(forKey: "gestalt") ?? "") ?? .mensch
        a.sprache = Sprache(rawValue: ud.string(forKey: "sprache") ?? "") ?? .system
        a.komplikationen = ud.bool(forKey: "komplikationen")
        a.bitcoin = ud.bool(forKey: "bitcoin")
        a.wechselFarbe = ud.bool(forKey: "wechselFarbe")
        a.wechselBlatt = ud.bool(forKey: "wechselBlatt")
        a.wechselGestalt = ud.bool(forKey: "wechselGestalt")
        return a
    }

    func speichern() {
        let ud = UserDefaults.standard
        ud.set(farbe.rawValue, forKey: "farbe")
        ud.set(blatt.rawValue, forKey: "blatt")
        ud.set(gestalt.rawValue, forKey: "gestalt")
        ud.set(sprache.rawValue, forKey: "sprache")
        ud.set(komplikationen, forKey: "komplikationen")
        ud.set(bitcoin, forKey: "bitcoin")
        ud.set(wechselFarbe, forKey: "wechselFarbe")
        ud.set(wechselBlatt, forKey: "wechselBlatt")
        ud.set(wechselGestalt, forKey: "wechselGestalt")
    }

    /// Das Aussehen für eine bestimmte Stunde: wo „Wechsel“ an ist, entscheidet die Zufallsfolge.
    func fuerStunde(_ n: Int) -> Aussehen {
        var a = self
        if wechselFarbe { a.farbe = Farbwelt.allCases[Zufallsfolge.index(nummer: n, anzahl: Farbwelt.allCases.count, salz: 101)] }
        if wechselBlatt { a.blatt = Blattart.allCases[Zufallsfolge.index(nummer: n, anzahl: Blattart.allCases.count, salz: 102)] }
        if wechselGestalt { a.gestalt = Gestalt.allCases[Zufallsfolge.index(nummer: n, anzahl: Gestalt.allCases.count, salz: 103)] }
        // Der Bitcoin-Modus legt Farbe und Blatt fest; die Figur bleibt frei.
        if bitcoin { a.farbe = .bitcoin; a.komplikationen = false }
        return a
    }
}

/// Zufällige Reihenfolge ohne direkte Wiederholung.
///
/// Je `anzahl` Stunden bilden einen Block. In einem Block kommt jeder Eintrag genau einmal,
/// in zufälliger Reihenfolge. Beginnt ein Block mit dem letzten Eintrag des Blocks davor,
/// tauschen Platz 0 und Platz 1. Der letzte Platz bleibt dabei unberührt,
/// die Regel greift also für jeden Block gleich.
enum Zufallsfolge {
    static func index(nummer n: Int, anzahl: Int, salz: Int) -> Int {
        let block = Int((Double(n) / Double(anzahl)).rounded(.down))
        var folge = mischung(block: block, anzahl: anzahl, salz: salz)
        if anzahl > 1, folge[0] == mischung(block: block - 1, anzahl: anzahl, salz: salz)[anzahl - 1] {
            folge.swapAt(0, 1)
        }
        return folge[n - block * anzahl]
    }

    /// Feste Folge je Block (Fisher-Yates mit SplitMix64). Fest, damit die Uhr
    /// nach einem Neustart dasselbe zeigt.
    private static func mischung(block: Int, anzahl: Int, salz: Int) -> [Int] {
        var zustand = UInt64(bitPattern: Int64(block &* 1009 &+ salz)) ^ 0x5A17_C0DE_2026_1110
        func naechste() -> UInt64 {
            zustand &+= 0x9E37_79B9_7F4A_7C15
            var z = zustand
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        var folge = Array(0..<anzahl)
        for i in stride(from: anzahl - 1, to: 0, by: -1) {
            folge.swapAt(i, Int(naechste() % UInt64(i + 1)))
        }
        return folge
    }
}
