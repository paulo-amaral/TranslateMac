import Foundation
import Testing
@testable import TranslateUI

@MainActor
@Suite("Dictation")
struct DictationTests {
    /// The panel can close, or Clear can be pressed, while macOS is still asking for permission.
    /// The microphone must not open afterwards.
    @Test func stopWithdrawsAStartStillWaitingForPermission() async {
        let (reached, reachedSignal) = AsyncStream<Void>.makeStream()
        let (released, releaseSignal) = AsyncStream<Void>.makeStream()
        let dictation = Dictation(authorize: {
            reachedSignal.yield()
            for await _ in released { break }
            return true
        })

        let start = dictation.toggle(language: Locale.Language(identifier: "en")) { _ in }
        for await _ in reached { break }
        dictation.stop()
        releaseSignal.yield()
        await start?.value

        #expect(!dictation.isListening)
        #expect(dictation.problem == nil)
    }

    @Test func deniedPermissionExplainsHowToFixIt() async {
        let dictation = Dictation(authorize: { false })
        await dictation.toggle(language: Locale.Language(identifier: "en")) { _ in }?.value
        #expect(!dictation.isListening)
        #expect(dictation.problem?.contains("System Settings") == true)
    }
}
