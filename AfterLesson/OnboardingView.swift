// OnboardingView – Erster Start: Modus- und Namenswahl.
// Ausgelagert aus ContentView.swift beim Aufräumen am 17.07.2026.

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import PDFKit
import UniformTypeIdentifiers
import Speech
import Combine

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @Binding var hasSelectedMode: Bool

    @State private var step = 0                      // 0 = Modus, 1 = Name
    @State private var selectedMode: AppMode = .teacher
    @State private var inputName = ""
    @State private var inputTitle = ""
    @FocusState private var nameFocused: Bool

    var canProceed: Bool {
        !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.12, blue: 0.10), ALColor.green],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if step == 0 {
                modeStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                nameStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: - Schritt 1: Modus wählen
    var modeStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 72))
                    .foregroundStyle(ALColor.gold)
                Text("Grünbuch")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Wähle deinen Modus")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Für Golflehrer und Schüler")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            VStack(spacing: 16) {
                // Golf Pro
                Button {
                    selectedMode = .teacher
                    inputTitle = "PGA Teaching Professional"
                    withAnimation { step = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        nameFocused = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(ALColor.gold).frame(width: 56, height: 56)
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ich bin Golf Pro")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Vorlagen erstellen & Schüler verwalten")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(ALColor.gold)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.white.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .stroke(ALColor.gold.opacity(0.5), lineWidth: 1.5))
                    )
                }
                .padding(.horizontal, 24)

                // Schüler
                Button {
                    selectedMode = .student
                    inputTitle = ""
                    withAnimation { step = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        nameFocused = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(ALColor.green).frame(width: 56, height: 56)
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ich bin Schüler")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Trainings empfangen & Fortschritt verfolgen")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(ALColor.green)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.white.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .stroke(ALColor.green.opacity(0.5), lineWidth: 1.5))
                    )
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Text("Grünbuch").font(.caption).foregroundStyle(.white.opacity(0.3)).padding(.bottom, 20)
        }
    }

    // MARK: - Schritt 2: Name eingeben
    var nameStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon je nach Modus
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selectedMode == .teacher ? ALColor.gold : ALColor.green)
                        .frame(width: 80, height: 80)
                    Image(systemName: selectedMode == .teacher ? "figure.golf" : "graduationcap.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
                Text(selectedMode == .teacher ? "Willkommen, Golf Pro!" : "Willkommen!")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Wie heisst du?")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 14) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dein Name")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                    TextField("Vorname Nachname", text: $inputName)
                        .focused($nameFocused)
                        .font(.system(size: 18, weight: .medium))
                        .padding(16)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .foregroundStyle(.white)
                        .tint(ALColor.gold)
                }

                // Titel (nur für Golf Pro)
                if selectedMode == .teacher {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dein Titel (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                        TextField("z.B. PGA Teaching Professional", text: $inputTitle)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .foregroundStyle(.white)
                            .tint(ALColor.gold)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Los geht's Button
            Button {
                let name = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                store.teacherName = name
                if selectedMode == .teacher && !inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.teacherTitle = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                store.appMode = selectedMode.rawValue
                hasSelectedMode = true
            } label: {
                Text("Los geht's →")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canProceed ? ALColor.dark : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(canProceed ? ALColor.gold : Color.white.opacity(0.08))
                    )
            }
            .disabled(!canProceed)
            .padding(.horizontal, 24)

            // Zurück
            Button { withAnimation { step = 0 } } label: {
                Text("← Zurück")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
    }
}
