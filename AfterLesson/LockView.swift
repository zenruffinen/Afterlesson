import SwiftUI
import LocalAuthentication
import CryptoKit

private let pinKey = "al_pin_hash"
private let teacherPinKey = "al_teacher_pin_hash"

// MARK: - Lock Screen (Glass, Arca-inspiriert)

struct LockView: View {
    @Binding var isUnlocked: Bool
    var forTeacherMode: Bool = false

    private var pinStorageKey: String { forTeacherMode ? teacherPinKey : pinKey }

    private var hasPIN: Bool {
        KeychainManager.shared.load(key: pinStorageKey) != nil
    }

    var body: some View {
        ZStack {
            lockBackground
            if hasPIN {
                AfterLessonPINEntryView(isUnlocked: $isUnlocked, pinKey: pinStorageKey)
            } else {
                AfterLessonPINSetupView(isUnlocked: $isUnlocked, pinKey: pinStorageKey)
            }
        }
    }

    private var lockBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "0D160D"),
                    Color(hex: "1B3D1F"),
                    Color(hex: "2D6A30").opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(ALColor.gold.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: -80, y: -200)

            Circle()
                .fill(ALColor.green.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 100, y: 220)
        }
    }
}

// MARK: - PIN Setup

struct AfterLessonPINSetupView: View {
    @Binding var isUnlocked: Bool
    let pinKey: String

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step: SetupStep = .create
    @State private var errorMessage = ""
    @State private var shake = false

    enum SetupStep { case create, confirm }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            glassCard {
                VStack(spacing: 24) {
                    AfterLessonGlassMark(size: 88)

                    VStack(spacing: 8) {
                        Text("Grünbuch schützen")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text(step == .create
                             ? String(localized: "Erstelle deinen 4-stelligen PIN")
                             : String(localized: "PIN zur Bestätigung wiederholen"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }

                    pinDots(count: step == .create ? pin.count : confirmPin.count)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                    }

                    AfterLessonPINPad { digit in
                        handleInput(digit)
                    } onDelete: {
                        handleDelete()
                    }
                }
                .padding(28)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .offset(x: shake ? -8 : 0)
        .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: shake)
    }

    func handleInput(_ digit: String) {
        let current = step == .create ? pin : confirmPin
        guard current.count < 4 else { return }

        if step == .create {
            pin += digit
            if pin.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    step = .confirm
                    errorMessage = ""
                }
            }
        } else {
            confirmPin += digit
            if confirmPin.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if pin == confirmPin {
                        savePIN(pin)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        isUnlocked = true
                    } else {
                        errorMessage = String(localized: "PINs stimmen nicht überein")
                        confirmPin = ""
                        pin = ""
                        step = .create
                        shake = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        }
    }

    func handleDelete() {
        if step == .create {
            if !pin.isEmpty { pin.removeLast() }
        } else if !confirmPin.isEmpty {
            confirmPin.removeLast()
        }
    }

    func savePIN(_ pin: String) {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        KeychainManager.shared.save(key: pinKey, value: hashString)
    }
}

// MARK: - PIN Entry

struct AfterLessonPINEntryView: View {
    @Binding var isUnlocked: Bool
    let pinKey: String

    @State private var pin = ""
    @State private var errorMessage = ""
    @State private var shake = false
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            glassCard {
                VStack(spacing: 24) {
                    AfterLessonGlassMark(size: 92)

                    VStack(spacing: 6) {
                        Text("Grünbuch")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Text("PIN eingeben")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    pinDots(count: pin.count)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    AfterLessonPINPad { digit in
                        handleInput(digit)
                    } onDelete: {
                        if !pin.isEmpty { pin.removeLast() }
                    }

                    Button { authenticateWithBiometrics() } label: {
                        Label("Face ID / Touch ID", systemImage: "faceid")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ALColor.gold)
                    }
                }
                .padding(28)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .onAppear { authenticateWithBiometrics() }
        .offset(x: shake ? -8 : 0)
        .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: shake)
    }

    func handleInput(_ digit: String) {
        guard pin.count < 4 else { return }
        pin += digit
        if pin.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { checkPIN() }
        }
    }

    func checkPIN() {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        let saved = KeychainManager.shared.load(key: pinKey) ?? ""

        if hashString == saved {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isUnlocked = true
        } else {
            attempts += 1
            pin = ""
            shake = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
            errorMessage = attempts >= 3
                ? String(format: String(localized: "Falscher PIN (%d Versuche)"), attempts)
                : String(localized: "Falscher PIN")
        }
    }

    func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: String(localized: "Grünbuch entsperren")) { success, _ in
            DispatchQueue.main.async {
                if success { isUnlocked = true }
            }
        }
    }
}

// MARK: - Shared PIN UI

@ViewBuilder
private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .frame(maxWidth: .infinity)
        .alGlass(tint: ALColor.green.opacity(0.35), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
        )
}

private func pinDots(count: Int) -> some View {
    HStack(spacing: 18) {
        ForEach(0..<4, id: \.self) { i in
            Circle()
                .fill(i < count ? ALColor.gold : Color.white.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(i < count ? 1.15 : 1.0)
                .animation(.spring(response: 0.2), value: count)
        }
    }
}

struct AfterLessonPINPad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let digits = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(digits, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 68, height: 68)
                        } else if key == "⌫" {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDelete()
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.title3)
                                    .frame(width: 68, height: 68)
                                    .alGlass(tint: .white.opacity(0.15), in: Circle())
                            }
                            .foregroundStyle(.white)
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDigit(key)
                            } label: {
                                Text(key)
                                    .font(.title2.bold())
                                    .frame(width: 68, height: 68)
                                    .alGlass(tint: .white.opacity(0.12), in: Circle())
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Teacher Mode PIN Gate

struct TeacherModePINGate: View {
    @Binding var isGranted: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var errorMessage = ""
    @State private var shake = false

    private var hasTeacherPIN: Bool {
        KeychainManager.shared.load(key: teacherPinKey) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F0EDE6").ignoresSafeArea()
                if hasTeacherPIN {
                    VStack(spacing: 24) {
                        AfterLessonGlassMark(size: 72)
                        Text("Lehrer-Modus")
                            .font(.title2.bold())
                        Text("PIN eingeben")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        pinDots(count: pin.count)
                        if !errorMessage.isEmpty {
                            Text(errorMessage).font(.caption).foregroundStyle(.red)
                        }
                        AfterLessonPINPad { digit in
                            guard pin.count < 4 else { return }
                            pin += digit
                            if pin.count == 4 { checkPIN() }
                        } onDelete: {
                            if !pin.isEmpty { pin.removeLast() }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .offset(x: shake ? -8 : 0)
                } else {
                    AfterLessonPINSetupView(isUnlocked: $isGranted, pinKey: teacherPinKey)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onChange(of: isGranted) { _, granted in
                if granted { dismiss() }
            }
        }
    }

    func checkPIN() {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        if hashString == KeychainManager.shared.load(key: teacherPinKey) {
            isGranted = true
            dismiss()
        } else {
            pin = ""
            shake = true
            errorMessage = String(localized: "Falscher PIN")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
        }
    }
}
