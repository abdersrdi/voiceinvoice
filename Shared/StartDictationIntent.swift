import AppIntents

/// Opens Talkstamp straight into dictation. Used by Siri, the Action Button,
/// the Control Center control and widgets.
struct StartDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "New invoice"
    static var description = IntentDescription("Start dictating a new invoice.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        PendingAction.set(.dictate)
        return .result()
    }
}
