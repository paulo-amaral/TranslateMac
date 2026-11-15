import Testing
@testable import TranslateCore

@Suite("CorrectionGuard")
struct CorrectionGuardTests {
    @Test func acceptsASmallCorrection() {
        #expect(CorrectionGuard.accepted("Hello world, this is a test.", original: "Helo wrld, this is a tset.")
            == "Hello world, this is a test.")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(CorrectionGuard.accepted("  Hello world\n", original: "Helo world") == "Hello world")
    }

    @Test func rejectsAnUnchangedAnswer() {
        #expect(CorrectionGuard.accepted("Hello world", original: " Hello world ") == nil)
    }

    @Test func rejectsAnEmptyAnswer() {
        #expect(CorrectionGuard.accepted("  \n", original: "Helo world") == nil)
    }

    @Test func rejectsAnAnswerThatExplainsInsteadOfCorrecting() {
        let answer = "Here is the corrected text: Hello world. I fixed two spelling mistakes for you."
        #expect(CorrectionGuard.accepted(answer, original: "Helo wrld") == nil)
    }

    @Test func rejectsAnAnswerThatDropsMostOfTheText() {
        #expect(CorrectionGuard.accepted("Hello.", original: "Helo wrld, this is a tset of the corector.") == nil)
    }

    @Test func rejectsAnAnswerThatAddsLines() {
        #expect(CorrectionGuard.accepted("Hello world\n(fixed)", original: "Helo world today") == nil)
    }
}
