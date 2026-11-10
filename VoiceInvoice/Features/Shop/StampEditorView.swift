import SwiftUI
import VisionKit

struct StampSource: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Document camera wrapper. Calls `onComplete` with the first scanned page, or nil if cancelled.
struct DocumentScanner: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onComplete(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onComplete(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onComplete(nil)
        }
    }
}

/// Lets the user tune how much of the paper is removed, then saves a transparent PNG.
struct StampEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let source: StampSource
    let onSave: (Data) -> Void

    @State private var processor: StampProcessor?
    @State private var sensitivity = 0.55
    @State private var result: UIImage?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Checkerboard())
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Clean-up")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Spacer()
                        Text("\(Int(sensitivity * 100))%")
                            .font(Theme.amount(14, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Slider(value: $sensitivity, in: 0...1)
                    Text("Move right to keep faint ink. Move left to remove paper noise and shadows.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                .cardStyle()

                Spacer()
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Company stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(result == nil)
                }
            }
            .task(id: sensitivity) { await rerender() }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let result {
            Image(uiImage: result)
                .resizable()
                .scaledToFit()
                .padding(16)
        } else if failed {
            Text("No stamp found. Try a clearer photo or move the slider right.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding()
        } else {
            ProgressView()
        }
    }

    private func rerender() async {
        try? await Task.sleep(nanoseconds: 120_000_000)
        if Task.isCancelled { return }

        if processor == nil {
            let image = source.image
            processor = await Task.detached(priority: .userInitiated) {
                StampProcessor(image: image)
            }.value
        }
        guard let processor else {
            failed = true
            return
        }
        let value = sensitivity
        let image = await Task.detached(priority: .userInitiated) {
            processor.render(sensitivity: value)
        }.value
        if Task.isCancelled { return }
        result = image
        failed = image == nil
    }

    private func save() {
        guard let data = result?.pngData() else { return }
        onSave(data)
        Haptics.success()
        dismiss()
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 14
            let columns = Int(size.width / tile) + 1
            let rows = Int(size.height / tile) + 1
            for row in 0..<rows {
                for column in 0..<columns {
                    let dark = (row + column) % 2 == 0
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(dark ? Color(white: 0.86) : Color(white: 0.96)))
                }
            }
        }
    }
}
