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
                    HStack(alignment: .top, spacing: SettingsMetrics.rowSpacing) {
                        Image(systemName: "hand.raised")
                            .font(.body)
                            .foregroundStyle(SortyTheme.accent)
                            .frame(width: SettingsMetrics.iconColumn)
                        Text(SettingsText.featureSourcePrivacy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, SettingsMetrics.twoLineRowVertical)
                }
            }

            SettingsExplainer(SettingsText.featureSourceRationale)
        }
    }
}
