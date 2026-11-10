import Foundation

/// One recognized word with its position in the audio (seconds from the start of the recording).
struct TimedWord: Equatable {
    var text: String
    var start: Double
    var duration: Double

    var end: Double { start + duration }
}

/// Optional "ignore other voices" filter. After a dictation it splits the words into phrases
/// (separated by pauses), compares each phrase's audio with the speaker's voiceprint, and drops
/// phrases that sound like somebody else. Phrases that are too short to judge are kept, because
/// losing the owner's own words is worse than keeping a stranger's.
enum SpeakerGate {
    struct Result: Equatable {
        var kept: [TimedWord]
        var droppedPhrases: Int
    }

    static func phrases(_ words: [TimedWord], pause: Double = 0.7) -> [[TimedWord]] {
        var result: [[TimedWord]] = []
        var current: [TimedWord] = []
        for word in words {
            if let last = current.last, word.start - last.end >= pause {
                result.append(current)
                current = []
            }
            current.append(word)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func filter(
        words: [TimedWord],
        samples: [Float],
        sampleRate: Double,
        startOffset: Int = 0,
        profile: VoiceProfile,
        gate: Float? = nil,
        gateFactor: Float = 3,
        minimumGate: Float = 3
    ) -> Result {
        let limit = gate ?? max(profile.radius * gateFactor, minimumGate)
        var kept: [TimedWord] = []
        var dropped = 0
        for phrase in phrases(words) {
            guard let first = phrase.first, let last = phrase.last else { continue }
            let from = Int(first.start * sampleRate) - startOffset
            let to = Int(last.end * sampleRate) - startOffset
            guard from >= 0, to <= samples.count, to > from else {
                kept += phrase
                continue
            }
            guard let embedding = SpeakerEmbedding.make(samples: Array(samples[from..<to]), sampleRate: sampleRate) else {
                kept += phrase
                continue
            }
            if SpeakerMatcher.distance(embedding, profile.centroid) <= limit {
                kept += phrase
            } else {
                dropped += 1
            }
        }
        return Result(kept: kept, droppedPhrases: dropped)
    }

    static func text(from words: [TimedWord], language: ParserLanguage) -> String {
        words.map(\.text).joined(separator: language == .zh ? "" : " ")
    }
}
