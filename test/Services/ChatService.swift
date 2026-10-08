import Foundation

struct ChatServiceMessage: Sendable {
    var role: String
    var content: String
}

enum ChatServiceError: Error, Sendable {
    case noNetwork
    case apiLimit
    case failed
}

protocol ChatService: Sendable {
    func streamReply(to messages: [ChatServiceMessage]) -> AsyncThrowingStream<String, any Error>
}
