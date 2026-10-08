import Foundation

struct WordChangeRibbon: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case unchanged
        case removed
        case inserted
    }

    enum Piece: Equatable, Sendable {
        case unchanged(String)
        case removed(String)
        case inserted(String)
        case space
        case lineBreak(Kind)
    }

    let pieces: [Piece]

    init(source: String, result: String) {
        let sourceTokens = wordTokens(in: source)
        let resultTokens = wordTokens(in: result)
        let difference = resultTokens.difference(from: sourceTokens)
        var removalOffsets = Set<Int>()
        var insertionOffsets = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                removalOffsets.insert(offset)
            case .insert(let offset, _, _):
                insertionOffsets.insert(offset)
            }
        }

        var pieces: [Piece] = []
        var lastWasWord = false
        var sourceIndex = 0
        var resultIndex = 0

        func append(_ token: WordToken, removed: Bool, inserted: Bool) {
            switch token {
            case .lineBreak:
                pieces.append(.lineBreak(kind(removed: removed, inserted: inserted)))
                lastWasWord = false
            case .word(let text):
                if lastWasWord {
                    pieces.append(.space)
                }
                if removed {
                    pieces.append(.removed(text))
                } else if inserted {
                    pieces.append(.inserted(text))
                } else {
                    pieces.append(.unchanged(text))
                }
                lastWasWord = true
            }
        }

        func kind(removed: Bool, inserted: Bool) -> Kind {
            if removed {
                .removed
            } else if inserted {
                .inserted
            } else {
                .unchanged
            }
        }

        while sourceIndex < sourceTokens.count || resultIndex < resultTokens.count {
            let sourceStart = sourceIndex
            let resultStart = resultIndex

            if sourceIndex < sourceTokens.count, removalOffsets.contains(sourceIndex) {
                append(sourceTokens[sourceIndex], removed: true, inserted: false)
                sourceIndex += 1
            }

            if resultIndex < resultTokens.count, insertionOffsets.contains(resultIndex) {
                append(resultTokens[resultIndex], removed: false, inserted: true)
                resultIndex += 1
            }

            if sourceIndex < sourceTokens.count,
               resultIndex < resultTokens.count,
               !removalOffsets.contains(sourceIndex),
               !insertionOffsets.contains(resultIndex) {
                append(sourceTokens[sourceIndex], removed: false, inserted: false)
                sourceIndex += 1
                resultIndex += 1
            }

            if sourceIndex == sourceStart, resultIndex == resultStart {
                break
            }
        }

        self.pieces = pieces
    }
}

private enum WordToken: Equatable, Hashable {
    case word(String)
    case lineBreak
}

private func wordTokens(in text: String) -> [WordToken] {
    var tokens: [WordToken] = []
    var word = ""
    var index = text.startIndex

    func flushWord() {
        if word.isEmpty { return }
        tokens.append(.word(word))
        word = ""
    }

    while index < text.endIndex {
        let character = text[index]
        if character == "\r" {
            flushWord()
            let next = text.index(after: index)
            if next < text.endIndex, text[next] == "\n" {
                index = text.index(after: next)
            } else {
                index = next
            }
            tokens.append(.lineBreak)
        } else if character == "\n" {
            flushWord()
            tokens.append(.lineBreak)
            index = text.index(after: index)
        } else if character.isWhitespace {
            flushWord()
            index = text.index(after: index)
        } else {
            word.append(character)
            index = text.index(after: index)
        }
    }
    flushWord()
    return tokens
}
