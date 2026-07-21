import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

// MARK: - App Entry

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab: Tab = .home

    enum Tab { case home, lessons, students, notes, settings }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:     HomeView(selectedTab: $selectedTab)
                case .lessons:  DatenpoolView()
                case .students: StudentsView()
                case .notes:    NotesView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }

            AfterLessonTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .alert(
            "Empfangen",
            isPresented: Binding(
                get: { store.importConfirmation != nil },
                set: { if !$0 { store.importConfirmation = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.importConfirmation = nil }
        } message: {
            Text(store.importConfirmation ?? "")
        }
    }
}

// MARK: - Tab Bar

struct AfterLessonTabBar: View {
    @Binding var selected: ContentView.Tab
    @EnvironmentObject var store: AppStore

    // Glaslupe wie im Mac-Dock (Hans, 21.07.): Beim Rüberfahren wächst
    // die Kachel unter dem Finger, Loslassen wählt sie aus.
    @State private var fingerX: CGFloat? = nil
    @State private var barWidth: CGFloat = 0

    private let tabOrder: [ContentView.Tab] = [.home, .lessons, .students, .notes, .settings]

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home,     index: 0, icon: "house.fill",            label: "Start")
            tabItem(.lessons,  index: 1, icon: "books.vertical.fill",   label: "Bibliothek", subtitle: "Tipps & Stoff")
            tabItem(.students, index: 2, icon: "figure.golf",
                    label: store.appMode == AppMode.teacher.rawValue ? "Schüler" : "Profil")
            tabItem(.notes,    index: 3, icon: "note.text.badge.plus", label: "Notizen", subtitle: "Pro")
            tabItem(.settings, index: 4, icon: "gearshape.fill",       label: "Einstellungen")
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { barWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in barWidth = w }
            }
        }
        // Kurzes Tippen geht weiter direkt an die Knöpfe — erst das
        // Rüberfahren (ab ein paar Punkten Bewegung) weckt die Lupe.
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    fingerX = value.location.x
                }
                .onEnded { value in
                    if barWidth > 0 {
                        let idx = min(tabOrder.count - 1,
                                      max(0, Int(value.location.x / (barWidth / CGFloat(tabOrder.count)))))
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = tabOrder[idx]
                        }
                    }
                    fingerX = nil
                }
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: fingerX)
        .padding(.bottom, 28)
        .background(Color(hex: "0D160D"))
        .overlay(alignment: .top) {
            Rectangle().fill(Color(hex: "2A3A2A")).frame(height: 0.5)
        }
    }

    /// Vergrößerung einer Kachel abhängig vom Fingerabstand (Dock-Formel).
    private func magnification(for index: Int) -> CGFloat {
        guard let x = fingerX, barWidth > 0 else { return 1 }
        let slot = barWidth / CGFloat(tabOrder.count)
        let center = (CGFloat(index) + 0.5) * slot
        let closeness = max(0, 1 - abs(x - center) / (slot * 1.25))
        return 1 + 0.5 * closeness
    }

    @ViewBuilder
    func tabItem(_ tab: ContentView.Tab, index: Int, icon: String, label: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = tab
            }
        } label: {
            let isSelected = selected == tab
            let mag = magnification(for: index)
            VStack(spacing: subtitle == nil ? 4 : 2) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected || mag > 1.25 ? ALColor.gold : Color.white.opacity(0.45))
                    .scaleEffect(isSelected ? 1.10 : 1.0)
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected || mag > 1.25 ? ALColor.gold : Color.white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 7, weight: .regular))
                        .foregroundStyle(isSelected ? ALColor.gold.opacity(0.75) : Color.white.opacity(0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .scaleEffect(mag, anchor: .bottom)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Branding Colors

enum ALColor {
    static let green    = Color(hex: "2D6A30")                          // Golf-Grün (warm, edel)
    static let gold     = Color(red: 0.72, green: 0.57, blue: 0.22)   // Golf-Gold
    static let dark     = Color(red: 0.10, green: 0.12, blue: 0.10)   // Fast Schwarz
    static let fairway  = Color(red: 0.17, green: 0.50, blue: 0.22)   // Fairway-Grün
    static let sand     = Color(red: 0.93, green: 0.87, blue: 0.70)   // Bunker-Sand
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView().environmentObject(AppStore())
}
