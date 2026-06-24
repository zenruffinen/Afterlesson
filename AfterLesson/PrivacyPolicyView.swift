import SwiftUI

struct PrivacyPolicyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Datenschutzerklärung")
          .font(.title2.bold())

        Text("Stand: Juni 2026")
          .font(.caption)
          .foregroundStyle(.secondary)

        privacySection(
          title: "Verantwortlich",
          body: """
          AfterLesson wird von Hans Ruffin betrieben. Bei Fragen zum Datenschutz erreichst du uns unter support@hansruffin.ch.
          """
        )

        privacySection(
          title: "Grundsatz",
          body: """
          AfterLesson speichert deine Unterrichtsdaten ausschliesslich lokal auf deinem Gerät. Es gibt keine Benutzerkonten, keine Cloud-Synchronisation und kein Tracking. Wir erheben keine personenbezogenen Daten auf Servern.
          """
        )

        privacySection(
          title: "Lokal gespeicherte Daten",
          body: """
          Lektionen, Stunden, Schülerordner, Medien, Notizen und Einstellungen bleiben in der App auf deinem iPhone oder iPad. Du kannst Inhalte per AirDrop, Dateien oder andere Apps teilen – dann gelten die Datenschutzbestimmungen des gewählten Kanals.
          """
        )

        privacySection(
          title: "Kamera",
          body: """
          Mit deiner Erlaubnis kannst du Fotos und Videos direkt in AfterLesson aufnehmen, z. B. für Lerninhalte oder Trainingsdokumentation. Aufnahmen werden nur lokal gespeichert, sofern du sie nicht selbst exportierst.
          """
        )

        privacySection(
          title: "Mikrofon",
          body: """
          Mit deiner Erlaubnis kannst du Sprachnotizen aufnehmen. Die Audiodaten werden lokal in der App gespeichert und nicht an uns übermittelt.
          """
        )

        privacySection(
          title: "Fotos",
          body: """
          Mit deiner Erlaubnis kannst du vorhandene Bilder aus deiner Mediathek in Lektionen einbinden. AfterLesson liest nur die von dir ausgewählten Fotos; sie werden lokal in der App abgelegt.
          """
        )

        privacySection(
          title: "Spracherkennung",
          body: """
          Mit deiner Erlaubnis kann AfterLesson gesprochene Trainingsstunden in Text umwandeln. Die Verarbeitung erfolgt über die Spracherkennung von Apple auf dem Gerät bzw. in dem von Apple vorgesehenen Rahmen; wir erhalten keine Transkripte.
          """
        )

        privacySection(
          title: "Face ID / Touch ID",
          body: """
          Optional kannst du die Bildschirmsperre mit Face ID oder Touch ID aktivieren. Biometrische Daten verbleiben im Secure Enclave deines Geräts; AfterLesson speichert sie nicht und hat keinen Zugriff darauf. Alternativ kannst du einen PIN verwenden, der sicher im Schlüsselbund deines Geräts hinterlegt wird.
          """
        )

        privacySection(
          title: "PIN & Schlüsselbund",
          body: """
          Wenn du einen PIN oder Lehrer-PIN festlegst, wird nur ein Hash-Wert im iOS-Schlüsselbund gespeichert. Der PIN selbst verlässt dein Gerät nicht.
          """
        )

        privacySection(
          title: "Deine Rechte",
          body: """
          Du kannst gespeicherte Inhalte jederzeit in der App löschen oder die App deinstallieren, um alle lokalen Daten zu entfernen. Es besteht kein Anspruch auf Auskunft bei uns, da wir keine zentral gespeicherten Nutzerdaten führen.
          """
        )

        privacySection(
          title: "Änderungen",
          body: """
          Diese Datenschutzerklärung kann bei Bedarf angepasst werden. Die aktuelle Fassung findest du jederzeit unter Einstellungen → Datenschutz in der App.
          """
        )
      }
      .padding()
    }
    .navigationTitle("Datenschutz")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func privacySection(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
      Text(body)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
