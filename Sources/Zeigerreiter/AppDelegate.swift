import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let groessen: [(titel: M, breite: CGFloat)] = [
        (.klein, 220), (.mittel, 300), (.gross, 400), (.sehrGross, 540),
    ]
    private let bitcoinDaten = BitcoinDaten()
    /// Eine Stunde läuft in der Vorführung in so vielen Sekunden ab.
    private static let vorfuehrDauer: Double = 40

    private var window: NSWindow!
    private var uhr: UhrView!
    private var takt: Timer?
    private var vorfuehrung: Timer?
    private var vorfuehrStart = Date()
    private var monitor: Any?
    private var aussehen = Aussehen.laden()

    private var breite: CGFloat {
        get {
            let w = UserDefaults.standard.double(forKey: "breite")
            return w > 0 ? CGFloat(w) : 300
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "breite") }
    }
    private var schwebend: Bool {
        get { UserDefaults.standard.bool(forKey: "schwebend") }
        set { UserDefaults.standard.set(newValue, forKey: "schwebend") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let groesse = NSSize(width: breite, height: breite * UhrView.seitenverhaeltnis)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: groesse),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        uhr = UhrView(frame: NSRect(origin: .zero, size: groesse))
        window.contentView = uhr

        if !window.setFrameUsingName("Zeigerreiter"), let schirm = NSScreen.main {
            let vf = schirm.visibleFrame
            window.setFrameOrigin(NSPoint(x: vf.maxX - groesse.width - 40, y: vf.maxY - groesse.height - 40))
        }
        window.setFrameAutosaveName("Zeigerreiter")
        wendeFensterAn()
        window.orderFrontRegardless()

        // Links ziehen, rechts Menü. Auf Schreibtisch-Ebene kommen Klicks nur so sicher an.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] ereignis in
            guard let self, ereignis.window === self.window else { return ereignis }
            if ereignis.type == .rightMouseDown {
                NSMenu.popUpContextMenu(self.menue(), with: ereignis, for: self.uhr)
            } else {
                self.window.performDrag(with: ereignis)
            }
            return nil
        }

        stelleNach()
        let t = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stelleNach() }
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        takt = t

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(aufgewacht), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(aufgewacht),
                                               name: .NSSystemClockDidChange, object: nil)
    }

    @objc private func aufgewacht() { stelleNach() }

    /// Echte Zeit anzeigen. Während der Vorführung ruht die echte Zeit.
    private func stelleNach() {
        guard vorfuehrung == nil else { return }
        let jetzt = Date()
        let k = Calendar.current.dateComponents([.hour, .minute, .second], from: jetzt)
        let minute = Double(k.minute ?? 0) + Double(k.second ?? 0) / 60
        let n = Texte.stundenNummer(jetzt)
        uhr.aussehen = aussehen.fuerStunde(n)
        bitcoinDaten.beiAenderung = { [weak self] in
            guard let self else { return }
            self.uhr.bitcoinWerte = self.bitcoinDaten.werte(self.aussehen.sprache)
        }
        bitcoinDaten.schalte(aussehen.bitcoin)
        uhr.bitcoinWerte = bitcoinDaten.werte(aussehen.sprache)
        uhr.stelle(datum: jetzt, stunde: k.hour ?? 0, minute: minute, stundenNummer: n, blend: nil)
    }

    // MARK: Vorführung

    @objc private func starteVorfuehrung() {
        vorfuehrung?.invalidate()
        vorfuehrStart = Date()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.vorfuehrSchritt() }
        }
        RunLoop.main.add(t, forMode: .common)
        vorfuehrung = t
    }

    private func vorfuehrSchritt() {
        let vergangen = Date().timeIntervalSince(vorfuehrStart)
        guard vergangen < Self.vorfuehrDauer else {
            vorfuehrung?.invalidate()
            vorfuehrung = nil
            stelleNach()
            return
        }
        let minute = vergangen / Self.vorfuehrDauer * 60
        let bewegung = Bewegung.bei(minute: minute)
        let blend = CGFloat(0.5 - 0.5 * cos(.pi * vergangen / bewegung.takt))
        let jetzt = Date()
        uhr.stelle(datum: jetzt, stunde: Calendar.current.component(.hour, from: jetzt), minute: minute,
                   stundenNummer: Texte.stundenNummer(jetzt), blend: blend)
    }

    // MARK: Menü

    private func menue() -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let a = aussehen
        func t(_ wort: M) -> String { MenueTexte.t(wort, a.sprache) }
        /// Titel einer Auswahl: die Wörter stehen in `M` in der Reihenfolge der Fälle.
        func titel(_ erstes: M, _ index: Int) -> String { M(rawValue: erstes.rawValue + index).map(t) ?? "" }

        let btc = NSMenuItem(title: "₿  " + t(.bitcoin), action: #selector(schalteBitcoin), keyEquivalent: "")
        btc.target = self
        btc.state = a.bitcoin ? .on : .off
        m.addItem(btc)
        m.addItem(.separator())

        let groesse = NSMenuItem(title: t(.groesse), action: nil, keyEquivalent: "")
        let unter = NSMenu()
        for (i, g) in Self.groessen.enumerated() {
            let p = NSMenuItem(title: t(g.titel), action: #selector(waehleGroesse(_:)), keyEquivalent: "")
            p.target = self
            p.tag = i
            p.state = g.breite == breite ? .on : .off
            unter.addItem(p)
        }
        groesse.submenu = unter
        m.addItem(groesse)

        /// Untermenü mit fester Wahl und optional „Jede Stunde …“.
        func wahl(_ titel: String, _ eintraege: [(titel: String, wert: String)], aktiv: String?,
                  _ aktion: Selector, wechsel: (titel: String, an: Bool, aktion: Selector)? = nil, gesperrt: Bool = false) {
            let kopf = NSMenuItem(title: titel, action: nil, keyEquivalent: "")
            kopf.isEnabled = !gesperrt
            let u = NSMenu()
            for e in eintraege {
                let p = NSMenuItem(title: e.titel, action: aktion, keyEquivalent: "")
                p.target = self
                p.representedObject = e.wert
                p.state = e.wert == aktiv ? .on : .off
                u.addItem(p)
            }
            if let wechsel {
                u.addItem(.separator())
                let p = NSMenuItem(title: wechsel.titel, action: wechsel.aktion, keyEquivalent: "")
                p.target = self
                p.state = wechsel.an ? .on : .off
                u.addItem(p)
            }
            kopf.submenu = u
            m.addItem(kopf)
        }
        wahl(t(.figur), Gestalt.allCases.enumerated().map { (titel(.mensch, $0.offset), $0.element.rawValue) },
             aktiv: a.wechselGestalt ? nil : a.gestalt.rawValue, #selector(waehleFigur(_:)),
             wechsel: (t(.jedeStunde), a.wechselGestalt, #selector(schalteWechselFigur)))
        // Im Bitcoin-Modus stehen Farbe, Zifferblatt und Komplikationen fest.
        wahl(t(.farbe), Farbwelt.allCases.enumerated().map { (titel(.salbei, $0.offset), $0.element.rawValue) },
             aktiv: a.wechselFarbe ? nil : a.farbe.rawValue, #selector(waehleFarbe(_:)),
             wechsel: (t(.jedeStunde), a.wechselFarbe, #selector(schalteWechselFarbe)), gesperrt: a.bitcoin)
        wahl(t(.zifferblatt), Blattart.allCases.enumerated().map { (titel(.schlicht, $0.offset), $0.element.rawValue) },
             aktiv: a.wechselBlatt ? nil : a.blatt.rawValue, #selector(waehleBlatt(_:)),
             wechsel: (t(.jedeStunde), a.wechselBlatt, #selector(schalteWechselBlatt)), gesperrt: a.bitcoin)
        let k = NSMenuItem(title: t(.komplikationen), action: #selector(schalteKomplikationen), keyEquivalent: "")
        k.target = self
        k.state = a.komplikationen ? .on : .off
        k.isEnabled = !a.bitcoin
        m.addItem(k)
        wahl(t(.sprache), Sprache.allCases.map { ($0.titel, $0.rawValue) },
             aktiv: a.sprache.rawValue, #selector(waehleSprache(_:)))
        m.addItem(.separator())

        func punkt(_ titel: String, _ aktion: Selector, an: Bool = false) {
            let p = NSMenuItem(title: titel, action: aktion, keyEquivalent: "")
            p.target = self
            p.state = an ? .on : .off
            m.addItem(p)
        }
        punkt(t(.vorfuehrung), #selector(starteVorfuehrung))
        m.addItem(.separator())
        punkt(t(.schwebend), #selector(schalteSchwebend), an: schwebend)
        punkt(t(.autostart), #selector(schalteAutostart), an: SMAppService.mainApp.status == .enabled)
        m.addItem(.separator())
        punkt(t(.beenden), #selector(beenden))
        return m
    }

    @objc private func waehleGroesse(_ p: NSMenuItem) {
        breite = Self.groessen[p.tag].breite
        wendeFensterAn()
        stelleNach()
    }

    private func uebernimm() {
        aussehen.speichern()
        stelleNach()
    }

    private func wert(_ p: NSMenuItem) -> String { p.representedObject as? String ?? "" }

    @objc private func waehleFigur(_ p: NSMenuItem) {
        guard let g = Gestalt(rawValue: wert(p)) else { return }
        aussehen.gestalt = g
        aussehen.wechselGestalt = false
        uebernimm()
    }

    @objc private func waehleFarbe(_ p: NSMenuItem) {
        guard let f = Farbwelt(rawValue: wert(p)) else { return }
        aussehen.farbe = f
        aussehen.wechselFarbe = false
        uebernimm()
    }

    @objc private func waehleBlatt(_ p: NSMenuItem) {
        guard let b = Blattart(rawValue: wert(p)) else { return }
        aussehen.blatt = b
        aussehen.wechselBlatt = false
        uebernimm()
    }

    @objc private func waehleSprache(_ p: NSMenuItem) {
        guard let s = Sprache(rawValue: wert(p)) else { return }
        aussehen.sprache = s
        uebernimm()
    }

    @objc private func schalteWechselFigur() { aussehen.wechselGestalt.toggle(); uebernimm() }
    @objc private func schalteWechselFarbe() { aussehen.wechselFarbe.toggle(); uebernimm() }
    @objc private func schalteWechselBlatt() { aussehen.wechselBlatt.toggle(); uebernimm() }
    @objc private func schalteBitcoin() { aussehen.bitcoin.toggle(); uebernimm() }
    @objc private func schalteKomplikationen() { aussehen.komplikationen.toggle(); uebernimm() }

    @objc private func schalteSchwebend() {
        schwebend.toggle()
        wendeFensterAn()
    }

    @objc private func schalteAutostart() {
        let dienst = SMAppService.mainApp
        do {
            if dienst.status == .enabled { try dienst.unregister() } else { try dienst.register() }
        } catch {
            NSLog("Zeigerreiter: Anmeldeobjekt fehlgeschlagen: \(error)")
        }
    }

    @objc private func beenden() { NSApp.terminate(nil) }

    private func wendeFensterAn() {
        window.level = schwebend
            ? .floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        let neu = NSSize(width: breite, height: breite * UhrView.seitenverhaeltnis)
        let alt = window.frame
        guard alt.size != neu else { return }
        window.setFrame(NSRect(x: alt.midX - neu.width / 2, y: alt.midY - neu.height / 2,
                               width: neu.width, height: neu.height), display: true)
    }
}
