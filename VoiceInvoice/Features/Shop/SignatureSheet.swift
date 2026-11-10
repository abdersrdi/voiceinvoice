import SwiftUI
import PencilKit

struct SignatureSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Data) -> Void

    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sign inside the box")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                SignaturePad(drawing: $drawing)
                    .frame(height: 260)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

                Spacer()
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear") { drawing = PKDrawing() }
                        .disabled(drawing.strokes.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(drawing.strokes.isEmpty)
                }
            }
        }
    }

    private func save() {
        let bounds = drawing.bounds.insetBy(dx: -8, dy: -8)
        var png: Data?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            png = drawing.image(from: bounds, scale: 3).pngData()
        }
        if let png {
            onSave(png)
            Haptics.success()
        }
        dismiss()
    }
}

struct SignaturePad: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SignaturePad

        init(_ parent: SignaturePad) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
