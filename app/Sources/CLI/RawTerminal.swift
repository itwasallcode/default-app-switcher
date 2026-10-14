import Foundation

nonisolated(unsafe) private var savedTermios = termios()
nonisolated(unsafe) private var termiosSaved = false

package enum Key: Equatable {
    case up, down, enter, back, quit
    case search
    case character(Character)
    case backspace
    case other
}

package enum RawTerminal {
    static var isInteractive: Bool {
        isatty(STDIN_FILENO) == 1
            && isatty(STDOUT_FILENO) == 1
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
    }

    static func enterRawMode() {
        guard tcgetattr(STDIN_FILENO, &savedTermios) == 0 else { return }
        termiosSaved = true
        var inputSettings = savedTermios
        inputSettings.c_lflag &= ~UInt(ECHO | ICANON)
        withUnsafeMutableBytes(of: &inputSettings.c_cc) { controls in
            controls[Int(VMIN)] = 1
            controls[Int(VTIME)] = 0
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &inputSettings)
        for interruption in [SIGINT, SIGTERM] {
            signal(interruption) { received in
                RawTerminal.restore()
                exit(128 + received)
            }
        }
        atexit { RawTerminal.restore() }
        emit("\u{1B}[?1049h\u{1B}[?25l")
    }

    static func restore() {
        guard termiosSaved else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &savedTermios)
        termiosSaved = false
        emit("\u{1B}[?25h\u{1B}[?1049l")
    }

    static func emit(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    static var size: (rows: Int, columns: Int) {
        var window = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &window) == 0, window.ws_row > 0 {
            return (Int(window.ws_row), Int(window.ws_col))
        }
        return (24, 80)
    }

    package static func readKey(searching: Bool, from descriptor: Int32 = STDIN_FILENO) -> Key {
        guard let byte = readByte(from: descriptor) else { return .quit }

        switch byte {
        case 0x0D, 0x0A: return .enter
        case 0x03, 0x04: return .quit
        case 0x7F, 0x08: return .backspace
        case 0x1B: return readEscapeSequence(from: descriptor)
        default: break
        }

        if searching {
            return readCharacter(startingWith: byte, from: descriptor)
        }

        switch byte {
        case 0x20: return .enter
        case 0x6B, 0x4B: return .up
        case 0x6A, 0x4A: return .down
        case 0x68: return .back
        case 0x71, 0x51: return .quit
        case 0x2F: return .search
        default: return .other
        }
    }

    private static func readCharacter(startingWith first: UInt8, from descriptor: Int32) -> Key {
        if first < 0x80 {
            return first >= 0x20 ? .character(Character(UnicodeScalar(first))) : .other
        }

        let length: Int
        switch first {
        case 0xC2...0xDF: length = 2
        case 0xE0...0xEF: length = 3
        case 0xF0...0xF4: length = 4
        default: return .other
        }

        var bytes = [first]
        for _ in 1..<length {
            guard byteReady(within: 100, from: descriptor),
                let next = readByte(from: descriptor), next & 0xC0 == 0x80
            else { return .other }
            bytes.append(next)
        }
        guard let text = String(bytes: bytes, encoding: .utf8),
            let scalar = text.unicodeScalars.first,
            !CharacterSet.controlCharacters.contains(scalar)
        else { return .other }
        return .character(Character(text))
    }

    private static func readEscapeSequence(from descriptor: Int32) -> Key {
        guard byteReady(within: 50, from: descriptor), let next = readByte(from: descriptor)
        else { return .back }
        guard next == 0x5B, let final = readByte(from: descriptor) else { return .other }
        switch final {
        case 0x41: return .up
        case 0x42: return .down
        case 0x44: return .back
        default: return .other
        }
    }

    private static func readByte(from descriptor: Int32) -> UInt8? {
        var byte: UInt8 = 0
        return read(descriptor, &byte, 1) == 1 ? byte : nil
    }

    private static func byteReady(within milliseconds: Int32, from fileDescriptor: Int32) -> Bool {
        var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0)
        return poll(&descriptor, 1, milliseconds) > 0
    }
}
