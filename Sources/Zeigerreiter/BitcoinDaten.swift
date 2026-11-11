import Foundation

/// Blockhöhe, Gebühren und Kurs von mempool.space (öffentliche API, ohne Schlüssel).
/// Dieselben Endpunkte wie in der Bitcoin-Uhr. Ohne Bitcoin-Modus kein Netzverkehr.
@MainActor
final class BitcoinDaten {
    private(set) var hoehe: Int?
    private(set) var gebuehren: (schnell: Int, halbeStunde: Int, stunde: Int)?
    private(set) var usd: Int?

    /// Wird nach jeder Abfrage gerufen.
    var beiAenderung: (() -> Void)?

    private var takt: Timer?
    private static let basis = "https://mempool.space/api/"
    private static let abstand: TimeInterval = 300

    func schalte(_ an: Bool) {
        if !an {
            takt?.invalidate()
            takt = nil
            return
        }
        guard takt == nil else { return }
        let t = Timer(timeInterval: Self.abstand, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.hole() }
        }
        t.tolerance = 10
        RunLoop.main.add(t, forMode: .common)
        takt = t
        Task { await hole() }
    }

    func hole() async {
        if let s = await Self.daten("blocks/tip/height").flatMap({ String(data: $0, encoding: .utf8) }),
           let h = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            hoehe = h
        }
        if let j = await Self.json("v1/fees/recommended"),
           let f = j["fastestFee"] as? Int, let h = j["halfHourFee"] as? Int, let o = j["hourFee"] as? Int {
            gebuehren = (f, h, o)
        }
        if let j = await Self.json("v1/prices"), let u = j["USD"] as? Int { usd = u }
        beiAenderung?()
    }

    /// Die drei Texte der Komplikationen: Block, sat/vB, Kurs.
    func werte(_ sprache: Sprache) -> BitcoinWerte {
        func gruppiert(_ n: Int) -> String { n.formatted(.number.grouping(.automatic).locale(sprache.locale)) }
        return BitcoinWerte(block: hoehe.map(gruppiert) ?? "–",
                            gebuehren: gebuehren.map { "\($0.schnell) · \($0.halbeStunde) · \($0.stunde)" } ?? "–",
                            kurs: usd.map { "$ " + gruppiert($0) } ?? "–")
    }

    private static func daten(_ pfad: String) async -> Data? {
        guard let url = URL(string: basis + pfad) else { return nil }
        var anfrage = URLRequest(url: url, timeoutInterval: 15)
        anfrage.setValue("Zeigerreiter/2.0", forHTTPHeaderField: "User-Agent")
        guard let (d, r) = try? await URLSession.shared.data(for: anfrage),
              (r as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return d
    }

    private static func json(_ pfad: String) async -> [String: Any]? {
        await daten(pfad).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}

struct BitcoinWerte: Equatable {
    var block = "–", gebuehren = "–", kurs = "–"
}
