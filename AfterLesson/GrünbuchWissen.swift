// GrünbuchWissen – festverdrahtete Wissenskarten (GW-001 … GW-010).
// Golfwissen, das jede Grünbuch-Installation mitbringt — für Pro und
// Schüler gleichermaßen, nicht löschbar, nicht editierbar.
// Vorlage: Hans' Kartenbogen vom 22.07.2026.

import SwiftUI

// MARK: - Modell

struct WissensKarte: Identifiable {
    let id: String              // "GW-001"
    let titel: String
    let untertitel: String
    let symbol: String          // SF-Symbol für die Listenzeile
    let bausteine: [Baustein]

    enum Baustein {
        case wert(gross: String, beschriftung: String)         // z.B. "3 : 1"
        case tabelle(spalten: [String], zeilen: [[String]])
        case checkliste(titel: String, punkte: [String])
        case fehler(punkte: [String])
        case schritte([(String, String)])                      // Titel + Erklärung
        case tipp(String)
        case uebung(String)
        case merksatz(String)
        case nachteil(String)
    }
}

// MARK: - Die 10 Karten

enum GrünbuchWissen {
    static let karten: [WissensKarte] = [
        WissensKarte(
            id: "GW-001",
            titel: "Das perfekte Schwungtempo",
            untertitel: "Ein konstanter Rhythmus sorgt für wiederholbare Schläge.",
            symbol: "metronome.fill",
            bausteine: [
                .wert(gross: "3 : 1", beschriftung: "Rückschwung 1–2–3 · Durchschwung: Schlag"),
                .tipp("Geschwindigkeit entsteht durch Rhythmus — nicht durch Kraft."),
                .fehler(punkte: ["Hektischer Rückschwung", "Zu schneller Übergang", "Mit den Armen schlagen"]),
                .uebung("20 Bälle — Rhythmus laut zählen: 1 – 2 – 3 – Schlag."),
                .merksatz("Ruhig zurück. Dynamisch durch.")
            ]
        ),
        WissensKarte(
            id: "GW-002",
            titel: "Ballposition",
            untertitel: "Die Ballposition bestimmt Deinen Treffpunkt.",
            symbol: "circle.dotted.and.circle",
            bausteine: [
                .tabelle(spalten: ["Schläger", "Ballposition"], zeilen: [
                    ["Driver", "Innenseite linke Ferse"],
                    ["Fairwayholz", "Etwas hinter der Ferse"],
                    ["Hybrid", "Vor der Mitte"],
                    ["Lange Eisen", "Vor der Mitte"],
                    ["Kurze Eisen", "Mitte"],
                    ["Wedges", "Mitte"]
                ]),
                .tipp("Der Ball bestimmt den Tiefpunkt Deines Schwungs."),
                .uebung("Lege drei Tees auf den Boden und teste verschiedene Ballpositionen.")
            ]
        ),
        WissensKarte(
            id: "GW-003",
            titel: "Driver Setup",
            untertitel: "Ein sauberer Abschlag beginnt vor dem Schwung.",
            symbol: "figure.golf",
            bausteine: [
                .checkliste(titel: "Checkliste", punkte: [
                    "Ball gegenüber linker Ferse",
                    "Ball halb über der Schlagfläche",
                    "Schulter leicht nach rechts geneigt",
                    "Griffdruck 4 von 10",
                    "Gewicht 55 % rechts"
                ]),
                .fehler(punkte: ["Tee zu tief", "Zu nah am Ball", "Schultern offen"])
            ]
        ),
        WissensKarte(
            id: "GW-004",
            titel: "Die richtige Teehöhe",
            untertitel: "Je länger der Schläger, desto höher darf der Ball stehen.",
            symbol: "arrow.up.to.line",
            bausteine: [
                .tabelle(spalten: ["Schläger", "Teehöhe"], zeilen: [
                    ["Driver", "Ball 50 % über dem Schlägerkopf"],
                    ["Fairwayholz", "Ball knapp über Gras"],
                    ["Hybrid", "Sehr niedrig"],
                    ["Lange Eisen", "Fast Bodenhöhe"],
                    ["Kurze Eisen", "Kein Tee"]
                ]),
                .merksatz("Je länger der Schläger, desto höher darf der Ball stehen.")
            ]
        ),
        WissensKarte(
            id: "GW-005",
            titel: "Bounce",
            untertitel: "Bounce verhindert, dass sich das Wedge in den Boden eingräbt.",
            symbol: "angle",
            bausteine: [
                .tabelle(spalten: ["Bounce", "Einsatz"], zeilen: [
                    ["4–6°", "Harte Fairways, kurzes Gras"],
                    ["7–10°", "Für die meisten Bedingungen"],
                    ["10–14°", "Weicher Boden, Bunker"]
                ]),
                .tipp("Die meisten Hobbygolfer profitieren von mehr Bounce.")
            ]
        ),
        WissensKarte(
            id: "GW-006",
            titel: "Wedges verstehen",
            untertitel: "Die richtige Loft-Abstufung schafft konstante Distanzen.",
            symbol: "chart.bar.fill",
            bausteine: [
                .tabelle(spalten: ["Wedge", "Loft", "Einsatz"], zeilen: [
                    ["Pitching Wedge", "44–46°", "Volle Schläge, lange Annäherungen"],
                    ["Gap Wedge", "50–52°", "Distanz schließen"],
                    ["Sand Wedge", "54–56°", "Bunker und Chips"],
                    ["Lob Wedge", "58–60°", "Hohe Annäherungen, kurze Fahnen"]
                ]),
                .merksatz("Zwischen den Wedges idealerweise 4–6° Loft-Unterschied.")
            ]
        ),
        WissensKarte(
            id: "GW-007",
            titel: "Zero-Torque Putter",
            untertitel: "Stabilere Ausrichtung. Konstantere Putts.",
            symbol: "scope",
            bausteine: [
                .checkliste(titel: "Vorteile", punkte: [
                    "Ball startet leichter auf der Ziellinie",
                    "Konstantere Richtung",
                    "Weniger Handrotation"
                ]),
                .nachteil("Erfordert eine kurze Eingewöhnung.")
            ]
        ),
        WissensKarte(
            id: "GW-008",
            titel: "4 häufige Schwungfehler",
            untertitel: "Erkenne die Ursache. Korrigiere gezielt.",
            symbol: "exclamationmark.triangle.fill",
            bausteine: [
                .schritte([
                    ("Over the Top", "Schläger kommt von außen"),
                    ("Early Release", "Handgelenke lösen zu früh"),
                    ("Seitliches Verschieben", "Körper bewegt sich seitlich"),
                    ("Offene Schlagfläche", "Schlagfläche zeigt nach rechts")
                ])
            ]
        ),
        WissensKarte(
            id: "GW-009",
            titel: "Griffdruck",
            untertitel: "Der richtige Druck für mehr Kontrolle und Weite.",
            symbol: "hand.raised.fill",
            bausteine: [
                .wert(gross: "4 / 10", beschriftung: "Idealer Druck: mittel — sicher, aber entspannt"),
                .merksatz("Halte Deinen Schläger sicher — nicht krampfhaft.")
            ]
        ),
        WissensKarte(
            id: "GW-010",
            titel: "Finish",
            untertitel: "Ein stabiles Finish zeigt einen ausgewogenen Schwung.",
            symbol: "figure.golf",
            bausteine: [
                .checkliste(titel: "Checkliste", punkte: [
                    "Gleichgewicht auf dem linken Fuß",
                    "Brust zeigt zum Ziel",
                    "Gürtel zum Ziel",
                    "Rechter Fuß auf der Spitze"
                ]),
                .tipp("Halte dein Finish drei Sekunden. So erkennst du Balancefehler sofort.")
            ]
        ),
    ]
}

// MARK: - Liste

struct WissensListeView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(GrünbuchWissen.karten) { karte in
                    NavigationLink {
                        WissensKarteView(karte: karte)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: karte.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ALColor.goldHell)
                                .frame(width: 40, height: 40)
                                .background(ALColor.goldHell.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(karte.id)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(ALColor.goldHell.opacity(0.8))
                                Text(karte.titel)
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(.primary)
                                Text(karte.untertitel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .nachtKarte(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .gruenbuchSeite()
        .navigationTitle("Grünbuch-Wissen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Karten-Ansicht

struct WissensKarteView: View {
    let karte: WissensKarte

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Kopf
                VStack(alignment: .center, spacing: 8) {
                    Text(karte.id)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ALColor.goldHell)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(ALColor.goldHell.opacity(0.6), lineWidth: 1))
                    Text(karte.titel)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(karte.untertitel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                ForEach(Array(karte.bausteine.enumerated()), id: \.offset) { _, baustein in
                    bausteinView(baustein)
                }
            }
            .padding(18)
            .padding(.bottom, 40)
        }
        .gruenbuchSeite()
        .navigationTitle(karte.id)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func bausteinView(_ baustein: WissensKarte.Baustein) -> some View {
        switch baustein {
        case .wert(let gross, let beschriftung):
            VStack(spacing: 6) {
                Text(gross)
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundStyle(ALColor.goldHell)
                Text(beschriftung)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .nachtKarte(radius: 16)

        case .tabelle(let spalten, let zeilen):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ForEach(Array(spalten.enumerated()), id: \.offset) { i, spalte in
                        Text(spalte.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ALColor.goldHell.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                ForEach(Array(zeilen.enumerated()), id: \.offset) { zi, zeile in
                    Divider().overlay(Color.white.opacity(0.08))
                    HStack(alignment: .top) {
                        ForEach(Array(zeile.enumerated()), id: \.offset) { i, wert in
                            Text(wert)
                                .font(.system(size: 13, weight: i == 0 ? .semibold : .regular))
                                .foregroundStyle(i == 0 ? .white : .white.opacity(0.75))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }
            .nachtKarte(radius: 16)

        case .checkliste(let titel, let punkte):
            VStack(alignment: .leading, spacing: 10) {
                sektionTitel(titel, symbol: "checkmark.seal.fill", farbe: Color(hex: "66BB6A"))
                ForEach(punkte, id: \.self) { punkt in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "66BB6A"))
                        Text(punkt)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .nachtKarte(radius: 16)

        case .fehler(let punkte):
            VStack(alignment: .leading, spacing: 10) {
                sektionTitel("Häufige Fehler", symbol: "xmark.octagon.fill", farbe: Color(hex: "E57373"))
                ForEach(punkte, id: \.self) { punkt in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "E57373"))
                        Text(punkt)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .nachtKarte(radius: 16)

        case .schritte(let schritte):
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(schritte.enumerated()), id: \.offset) { i, schritt in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "0B150D"))
                            .frame(width: 26, height: 26)
                            .background(ALColor.goldHell, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(schritt.0)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text(schritt.1)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .nachtKarte(radius: 16)

        case .tipp(let text):
            hinweisKarte(titel: "Trainer-Tipp", symbol: "lightbulb.fill",
                         farbe: ALColor.goldHell, text: text)

        case .uebung(let text):
            hinweisKarte(titel: "Übung", symbol: "figure.golf",
                         farbe: Color(hex: "66BB6A"), text: text)

        case .merksatz(let text):
            hinweisKarte(titel: "Merksatz", symbol: "star.fill",
                         farbe: ALColor.goldHell, text: text)

        case .nachteil(let text):
            hinweisKarte(titel: "Nachteil", symbol: "minus.circle.fill",
                         farbe: Color(hex: "E57373"), text: text)
        }
    }

    private func sektionTitel(_ titel: String, symbol: String, farbe: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(titel.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
        }
        .foregroundStyle(farbe)
    }

    private func hinweisKarte(titel: String, symbol: String, farbe: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sektionTitel(titel, symbol: symbol, farbe: farbe)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .nachtKarte(radius: 16)
    }
}
