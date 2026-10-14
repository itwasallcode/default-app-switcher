import DASCLI
import DASCore
import Foundation

func runPlumbingTests(_ t: TestRunner) {
    t.suite("shortcut-feedback") { t in
        var feedback = ShortcutFeedback()
        t.equal(feedback.remainingMilliseconds(at: 10), nil, "idle feedback does not poll")
        feedback.press(.refresh, at: 10)
        t.equal(feedback.key, .refresh, "the pressed shortcut is recorded")
        t.expect(
            feedback.remainingMilliseconds(at: 10.08) != nil,
            "feedback remains visible during its duration")
        feedback.press(.search, at: 10.08)
        t.equal(feedback.key, .search, "the latest shortcut replaces the previous one")
        t.expect(
            feedback.remainingMilliseconds(at: 10.13) != nil,
            "another press extends feedback beyond the original deadline")
        t.equal(feedback.remainingMilliseconds(at: 10.21), nil, "feedback expires without input")
        t.equal(feedback.key, nil, "expired feedback clears the pressed shortcut")

        let input = Pipe()
        defer {
            input.fileHandleForReading.closeFile()
            input.fileHandleForWriting.closeFile()
        }
        t.equal(
            RawTerminal.readKey(
                searching: false, timeoutMilliseconds: 10,
                from: input.fileHandleForReading.fileDescriptor),
            .other, "timed input returns when no key arrives")
        input.fileHandleForWriting.write(Data("r".utf8))
        t.equal(
            RawTerminal.readKey(
                searching: false, timeoutMilliseconds: 10,
                from: input.fileHandleForReading.fileDescriptor),
            .refresh, "a timeout does not consume the next key")
    }

    t.suite("search-input") { t in
        func read(_ bytes: [UInt8], searching: Bool = true) -> Key {
            let input = Pipe()
            input.fileHandleForWriting.write(Data(bytes))
            input.fileHandleForWriting.closeFile()
            return RawTerminal.readKey(
                searching: searching, from: input.fileHandleForReading.fileDescriptor)
        }

        t.equal(read(Array("a".utf8)), .character("a"), "ASCII letters remain searchable")
        for character in ["r", "R"] {
            t.equal(
                read(Array(character.utf8), searching: false), .refresh,
                "refresh is available outside search")
            t.equal(
                read(Array(character.utf8)), .character(Character(character)),
                "refresh keys remain searchable letters")
        }
        t.equal(read(Array("ş".utf8)), .character("ş"), "Turkish letters are searchable")
        t.equal(read(Array("日".utf8)), .character("日"), "three-byte characters are searchable")
        t.equal(read(Array("😀".utf8)), .character("😀"), "four-byte characters are searchable")
        let input = Pipe()
        input.fileHandleForWriting.write(Data("şx".utf8))
        input.fileHandleForWriting.closeFile()
        t.equal(
            RawTerminal.readKey(searching: true, from: input.fileHandleForReading.fileDescriptor),
            .character("ş"), "a UTF-8 character consumes all of its bytes")
        t.equal(
            RawTerminal.readKey(searching: true, from: input.fileHandleForReading.fileDescriptor),
            .character("x"), "the next key remains available")
        t.equal(read([0x7F]), .backspace, "backspace still removes a search character")
        t.equal(read([0xE2, 0x28, 0xA1]), .other, "invalid UTF-8 is ignored")
        t.equal(read([0xC3]), .other, "incomplete UTF-8 is ignored")
        t.equal(read(Array("ş".utf8), searching: false), .other, "typing outside search is ignored")
    }

    t.suite("text-layout") { t in
        t.equal(visibleLength("plain"), 5, "plain text measures its characters")
        t.equal(visibleLength("\u{1B}[2mdim\u{1B}[0m"), 3, "escape sequences occupy no columns")
        t.equal(
            visibleLength("\u{1B}[7m\u{1B}[2mboth\u{1B}[0m"), 4, "consecutive sequences are skipped"
        )
        t.equal(visibleLength(""), 0, "empty string measures zero")
        t.equal(
            visibleLength("\u{1B}[38;5;120mcolour\u{1B}[0m"), 6,
            "multi-parameter sequences are skipped")

        t.equal(stripANSI("\u{1B}[2mdim\u{1B}[0m"), "dim", "stripping leaves no fragments")
        t.equal(stripANSI("a\u{1B}[31mb\u{1B}[0mc"), "abc", "stripping keeps surrounding text")
        t.equal(stripANSI("no codes"), "no codes", "text without codes is unchanged")
        t.expect(!stripANSI("\u{1B}[2mx\u{1B}[0m").contains("m"), "no stray final bytes survive")

        t.equal(pad("ab", 5), "ab   ", "pad fills to width")
        t.equal(pad("abcdef", 3), "abcdef", "pad never truncates")
        t.equal(
            visibleLength(pad("\u{1B}[2mab\u{1B}[0m", 5)), 5, "styled text pads to visible width")

        t.equal(trimTrailing("a   "), "a", "trailing spaces are dropped")
        t.equal(trimTrailing("a"), "a", "text without trailing spaces is unchanged")
        t.equal(trimTrailing("   "), "", "an all-space string collapses")
    }

    t.suite("errors") { t in
        t.equal(DASError.usage("x").exitCode, 2, "usage errors exit 2")
        t.equal(DASError.cancelled.exitCode, 4, "cancellation exits 4")
        t.equal(DASError.timedOut(seconds: 1).exitCode, 5, "timeout exits 5")
        t.equal(DASError.helperFailed("x").exitCode, 1, "other failures exit 1")
    }
}
