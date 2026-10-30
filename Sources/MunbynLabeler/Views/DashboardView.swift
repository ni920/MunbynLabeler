import AppKit
import LabelCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var bluetooth: BluetoothPrinterService
    @ObservedObject var jobStore: PrintJobStore

    private var selectedJob: PrintJob? {
        if let id = appStore.selectedJobID,
           let match = jobStore.jobs.first(where: { $0.id == id && $0.postageStampIDs == nil && $0.letterFlowID == nil }) {
            return match
        }
        return jobStore.jobs.first(where: { $0.postageStampIDs == nil && $0.letterFlowID == nil && ($0.status == .ready || $0.status == .failed) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ShippingFormView(appStore: appStore, postage: appStore.postage, controller: appStore.letterFlowController)
                if let selectedJob {
                    readyLabelCard(selectedJob)
                }
                if let message = appStore.lastMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Versenden")
    }

    private func readyLabelCard(_ job: PrintJob) -> some View {
        HStack(spacing: 18) {
            preview(for: job.sourceURL)
                .frame(width: 70, height: 85)

            VStack(alignment: .leading, spacing: 9) {
                Label(job.status.label, systemImage: job.status == .failed ? "exclamationmark.circle" : "doc")
                    .font(.headline)
                Text(job.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(job.resolvedLabelFormat.sizeDescription)")
                    .foregroundStyle(.secondary)
                if let error = job.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Button("Druckvorschau") {
                    appStore.presentPrintPreview(job)
                }
                .buttonStyle(.bordered)
                .disabled(job.status == .printing)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func preview(for url: URL) -> some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "doc")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
