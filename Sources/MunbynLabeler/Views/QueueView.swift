import LabelCore
import SwiftUI

struct QueueView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var jobStore: PrintJobStore

    var body: some View {
        Group {
            if jobStore.jobs.isEmpty {
                ContentUnavailableView(
                    "Noch keine Etiketten",
                    systemImage: "printer",
                    description: Text("Importierte Dateien erscheinen hier mit ihrem Druckstatus.")
                )
            } else {
                List(jobStore.jobs) { job in
                    HStack(spacing: 14) {
                        statusIcon(job.status)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(job.sourceURL.lastPathComponent)
                                .font(.headline)
                            Text(job.createdAt, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let error = job.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        Text(job.status.label)
                            .foregroundStyle(.secondary)
                        if job.status != .printed {
                            Button(job.status == .failed ? "Erneut" : "Drucken") {
                                if job.status == .failed { jobStore.retry(job.id) }
                                appStore.printJob(job)
                            }
                            .disabled(job.status == .printing)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .navigationTitle("Warteschlange")
        .toolbar {
            Button("Erledigte entfernen") {
                jobStore.clearCompleted()
            }
            .disabled(!jobStore.jobs.contains { $0.status == .printed })
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: PrintJob.Status) -> some View {
        switch status {
        case .ready:
            Image(systemName: "clock").foregroundStyle(.blue)
        case .printing:
            ProgressView().controlSize(.small)
        case .printed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}
