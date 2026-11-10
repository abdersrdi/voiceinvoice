import SwiftUI
import SwiftData

enum VoiceLimits {
    /// Voices the app can recognize per shop.
    static let maxEnrolledVoices = 3
}

struct TeamView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Employee.createdAt) private var employees: [Employee]

    @State private var showAdd = false
    @State private var newName = ""
    @AppStorage("ignoreOtherVoices") private var ignoreOtherVoices = false

    var body: some View {
        List {
            Section {
                Text("Add the people who dictate invoices. Enroll up to \(VoiceLimits.maxEnrolledVoices) voices so Talkstamp can tell who is speaking and note it on each invoice.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }

            Section {
                Toggle("Ignore other voices while dictating (beta)", isOn: $ignoreOtherVoices)
            } footer: {
                Text("After you stop, phrases that do not sound like the speaker are left out, and you can bring them back. Needs an enrolled voice.")
            }

            Section {
                ForEach(employees) { employee in
                    NavigationLink {
                        EmployeeDetailView(employee: employee)
                    } label: {
                        EmployeeRow(employee: employee)
                    }
                }
                .onDelete(perform: delete)

                Button {
                    newName = ""
                    showAdd = true
                } label: {
                    Label("Add team member", systemImage: "person.badge.plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Team & voices")
        .alert("Add team member", isPresented: $showAdd) {
            TextField("Name", text: $newName)
            Button("Add") { add() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let employee = Employee()
        employee.name = name
        context.insert(employee)
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets where employees.indices.contains(index) {
            let employee = employees[index]
            VoiceprintStore.delete(for: employee)
            context.delete(employee)
        }
        try? context.save()
    }
}

struct EmployeeRow: View {
    let employee: Employee

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: VoiceprintStore.hasVoiceprint(employee) ? "waveform.circle.fill" : "person.circle")
                .font(.title2)
                .foregroundStyle(VoiceprintStore.hasVoiceprint(employee) ? Theme.accent : Theme.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(employee.name.isEmpty ? String(localized: "Unnamed") : employee.name)
                    .font(.system(.body, design: .rounded, weight: .medium))
                Text(VoiceprintStore.hasVoiceprint(employee) ? String(localized: "Voice enrolled") : String(localized: "No voice enrolled"))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var employees: [Employee]

    @Bindable var employee: Employee

    @State private var showEnrollment = false
    @State private var showLimitAlert = false
    @State private var refresh = 0

    private var hasVoice: Bool {
        _ = refresh
        return VoiceprintStore.hasVoiceprint(employee)
    }

    private var enrolledCount: Int {
        employees.filter { VoiceprintStore.hasVoiceprint($0) }.count
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $employee.name)
            }

            Section {
                Label(hasVoice ? String(localized: "Voice enrolled") : String(localized: "No voice enrolled"),
                      systemImage: hasVoice ? "waveform.circle.fill" : "mic.slash")
                    .foregroundStyle(hasVoice ? Theme.accent : Theme.secondaryText)

                Button(hasVoice ? String(localized: "Re-enroll voice") : String(localized: "Enroll voice")) {
                    if !hasVoice && enrolledCount >= VoiceLimits.maxEnrolledVoices {
                        showLimitAlert = true
                    } else {
                        showEnrollment = true
                    }
                }

                if hasVoice {
                    Toggle("Sync voice to my other devices", isOn: syncBinding)
                    Button("Delete voice", role: .destructive) {
                        VoiceprintStore.delete(for: employee)
                        employee.voiceConsentAt = nil
                        try? context.save()
                        refresh += 1
                    }
                }
            } header: {
                Text("Voice")
            } footer: {
                Text("Only a numeric voiceprint is kept, never a recording. With sync on it is stored in the shop's iCloud so you enroll once; turn it off to keep it on this device only. Deleting removes it everywhere.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(employee.name.isEmpty ? String(localized: "Team member") : employee.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEnrollment, onDismiss: { refresh += 1 }) {
            VoiceEnrollmentFlow(employee: employee)
        }
        .alert("Voice limit reached", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A shop can enroll up to \(VoiceLimits.maxEnrolledVoices) voices. Delete one to enroll another.")
        }
    }

    private var syncBinding: Binding<Bool> {
        Binding(
            get: { employee.voiceSyncEnabled },
            set: { enabled in
                VoiceprintStore.setSync(enabled, for: employee)
                try? context.save()
                refresh += 1
            }
        )
    }
}

struct VoiceEnrollmentFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let employee: Employee

    @State private var consented = false
    @State private var step = 0
    @State private var embeddings: [[Float]] = []
    @State private var capture = VoiceCapture()
    @State private var secondsLeft = 0
    @State private var working = false
    @State private var message: String?

    private let recordSeconds = 5
    private let prompts: [LocalizedStringKey] = [
        "“Two shirts at twenty each and a pair of pants for forty.”",
        "“Add three coffees for twelve in total.”",
        "“One jacket at a hundred and fifty, thank you.”"
    ]

    var body: some View {
        NavigationStack {
            Group {
                if consented { recordingStep } else { consentStep }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Voice enrollment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        _ = capture.stop()
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(working || capture.isRecording)
        }
    }

    // MARK: Consent

    private var consentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "waveform.badge.person.crop")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accent)
            Text("Voice consent")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Talkstamp will learn the voice of \(employee.name.isEmpty ? String(localized: "this person") : employee.name) from three short readings, so it can tell who is dictating.")
            Text("Only a numeric voiceprint is stored, never the recording. It can be deleted at any time, and it is removed from every device.")
                .foregroundStyle(Theme.secondaryText)
            Text("A voiceprint is not a security lock. It only helps label who dictated an invoice.")
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Button("The person being enrolled agrees") {
                consented = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .font(.system(.body, design: .rounded))
    }

    // MARK: Recording

    private var recordingStep: some View {
        VStack(spacing: 20) {
            Text("Reading \(min(step + 1, prompts.count)) of \(prompts.count)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            if step < prompts.count {
                Text(prompts[step])
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .cardStyle()
            }

            ZStack {
                Circle()
                    .fill(Theme.burgundy.opacity(0.18))
                    .frame(width: 110, height: 110)
                    .scaleEffect(capture.isRecording ? 1 + CGFloat(capture.level) * 0.7 : 1)
                    .animation(.easeOut(duration: 0.12), value: capture.level)
                Button {
                    Task { await record() }
                } label: {
                    ZStack {
                        Circle().fill(Theme.heroGradient).frame(width: 84, height: 84)
                        if capture.isRecording {
                            Text("\(secondsLeft)")
                                .font(Theme.amount(30, weight: .bold))
                                .foregroundStyle(.white)
                        } else if working {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(capture.isRecording || working)
            }
            .frame(height: 120)

            Text(capture.isRecording ? String(localized: "Speak in your normal voice…") : String(localized: "Tap the mic, then read the sentence aloud."))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private func record() async {
        message = nil
        guard await capture.start() else {
            message = capture.error
            return
        }
        for remaining in stride(from: recordSeconds, through: 1, by: -1) {
            secondsLeft = remaining
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        let clip = capture.stop()
        working = true
        let embedding = await Task.detached(priority: .userInitiated) {
            SpeakerEmbedding.make(samples: clip.samples, sampleRate: clip.sampleRate)
        }.value
        working = false

        guard let embedding else {
            message = String(localized: "We didn't hear enough. Move closer, speak a little louder and try again.")
            return
        }
        embeddings.append(embedding)
        step += 1
        Haptics.tap()
        if step >= prompts.count { finish() }
    }

    private func finish() {
        guard let voiceprint = Voiceprint.enroll(from: embeddings) else {
            embeddings = []
            step = 0
            message = String(localized: "Enrollment did not work. Please try again.")
            return
        }
        VoiceprintStore.save(voiceprint, for: employee)
        employee.voiceConsentAt = Date()
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
