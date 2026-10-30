import LabelCore
import SwiftUI

struct ShippingTaskPicker: View {
    var disabled: Bool
    var choose: (GuidedShippingJourney.Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Neuer Versand").font(.system(size: 26, weight: .semibold))
                Text("Was möchtest du drucken?").font(.title3)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(GuidedShippingJourney.Task.allCases) { task in
                        taskButton(task, compact: false).frame(width: 200, height: 182)
                    }
                }.frame(width: 624, alignment: .leading)
                VStack(spacing: 10) {
                    ForEach(GuidedShippingJourney.Task.allCases) { task in taskButton(task, compact: true) }
                }
            }
            .disabled(disabled)
            DisclosureGroup("Adressen aus Etsy übernehmen") {
                Text("Sende eine Bestellung mit der Browser-Erweiterung an Label Helper. Alternativ kannst du im Briefschritt eine Etsy-CSV importieren.")
                    .font(.callout).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)
        }
    }

    private func title(_ task: GuidedShippingJourney.Task) -> String {
        switch task { case .letter: "Brief"; case .parcel: "Paketlabel"; case .postage: "Briefmarken" }
    }
    private func subtitle(_ task: GuidedShippingJourney.Task) -> String {
        switch task {
        case .letter: "Adresse und Frankierung"
        case .parcel: "DHL-Label aus PDF"
        case .postage: "Marken zum Ausschneiden"
        }
    }

    private func taskButton(_ task: GuidedShippingJourney.Task, compact: Bool) -> some View {
        Button { choose(task) } label: {
            let icon = Image(systemName: task.icon)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
            let copy = VStack(alignment: .leading, spacing: 6) {
                Text(title(task)).font(.headline)
                Text(subtitle(task)).font(.callout).multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(width: compact ? nil : 148, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Group {
                if compact {
                    HStack(spacing: 14) { icon; copy; Spacer(); Image(systemName: "chevron.right").accessibilityHidden(true) }
                } else {
                    VStack(alignment: .leading, spacing: 16) { icon; copy; Spacer(minLength: 0) }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: compact ? 62 : 155, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .accessibilityLabel(task.title)
        .accessibilityHint(subtitle(task))
    }
}
