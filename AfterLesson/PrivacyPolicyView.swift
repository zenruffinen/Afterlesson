import SwiftUI

struct PrivacyPolicyView: View {
  private let sections: [(titleKey: String, bodyKey: String)] = [
    ("privacy.responsible.title", "privacy.responsible.body"),
    ("privacy.principle.title", "privacy.principle.body"),
    ("privacy.local.title", "privacy.local.body"),
    ("privacy.camera.title", "privacy.camera.body"),
    ("privacy.microphone.title", "privacy.microphone.body"),
    ("privacy.photos.title", "privacy.photos.body"),
    ("privacy.speech.title", "privacy.speech.body"),
    ("privacy.biometrics.title", "privacy.biometrics.body"),
    ("privacy.keychain.title", "privacy.keychain.body"),
    ("privacy.rights.title", "privacy.rights.body"),
    ("privacy.changes.title", "privacy.changes.body"),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("privacy.title")
          .font(.title2.bold())

        Text("privacy.updated")
          .font(.caption)
          .foregroundStyle(.secondary)

        ForEach(sections, id: \.titleKey) { section in
          privacySection(titleKey: section.titleKey, bodyKey: section.bodyKey)
        }
      }
      .padding()
    }
    .navigationTitle("settings.privacy")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func privacySection(titleKey: String, bodyKey: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(LocalizedStringKey(titleKey))
        .font(.headline)
      Text(LocalizedStringKey(bodyKey))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
