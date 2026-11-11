/// Die Wörter des Menüs. Die Reihenfolge ist die Reihenfolge in `MenueTexte.<sprache>`.
enum M: Int, CaseIterable {
    case groesse, klein, mittel, gross, sehrGross
    case figur, farbe, zifferblatt, sprache, komplikationen
    case bitcoin, jedeStunde, vorfuehrung, schwebend, autostart, beenden
    case mensch, katze, affe, hase, roboter
    case salbei, bitcoinFarbe, nacht, sand, westminster, schiefer
    case schlicht, punkte, ziffern, balken, bigBen
}

enum MenueTexte {
    static let alle: [Sprache: [String]] = [
        .de: de, .en: en, .fr: fr, .es: es, .it: it, .pt: pt, .nl: nl, .tr: tr,
        .zh: zh, .ja: ja, .ko: ko, .hi: hi,
    ]

    static func t(_ m: M, _ s: Sprache) -> String {
        let l = alle[s] ?? de
        return m.rawValue < l.count ? l[m.rawValue] : de[m.rawValue]
    }

    static let de: [String] = [
        "Größe", "Klein", "Mittel", "Groß", "Sehr groß",
        "Figur", "Farbe", "Zifferblatt", "Sprache", "Komplikationen: Datum, Wochentag, Mond, Sekunde",
        "Bitcoin-Modus: Block, sat/vB, Kurs", "Jede Stunde wechseln", "Vorführung: eine Stunde in 40 Sekunden",
        "Über allen Fenstern", "Beim Anmelden starten", "Beenden",
        "Strichmännchen", "Katze", "Affe", "Hase", "Roboter",
        "Salbei", "Bitcoin", "Nacht", "Sand", "Westminster", "Schiefer",
        "Schlicht", "Punkte", "Ziffern", "Balken", "Big Ben",
    ]
}
