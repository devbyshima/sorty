import SwiftUI

/// Where the acoustic columns get their numbers.
///
/// Checkmark rows rather than the `Picker` this used to be. Each source carries
/// a sentence that is the only explanation in the app of why the choice exists
/// at all - `FeatureSourceMode.explanation` - and a segmented control had
/// nowhere to put one, so the explanation lived in a footer describing whichever
/// option happened to be selected and the other two went unexplained.
struct AudioFeatureSettingsView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        SettingsScaffold(title: SettingsText.audioFeatures) {
            // The reason the choice exists, above the choice. This used to be a
            // footer under the card, where it was read after the decision and
            // where it restated three things the rows already said.
            SettingsLead(SettingsText.featureSourceLead)

            SettingsCard {
                ForEach(FeatureSourceMode.allCases, id: \.self) { source in
                    SettingsSelectRow(
                        icon: source.symbolName,
                        title: source.label,
                        detail: source.explanation,
                        isSelected: session.configuration.featureSource == source
                    ) {
                        session.configuration.featureSource = source
                    }
                }
            }

            // Only under the source that does it, and phrased as what leaves
            // rather than as a warning: naming the host, the one thing sent, and
            // the things that are not.
            if session.configuration.featureSource.sendsTrackIDsOffDevice {
                SettingsCard {
                    SettingsNote(icon: "hand.raised", text: SettingsText.featureSourcePrivacy)
                }
            }
        }
    }
}
