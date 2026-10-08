import Foundation

enum Secrets {
    static let obfuscatedKey: [UInt8] = [19, 22, 24, 43, 77, 54, 6, 53, 72, 88, 27, 96, 25, 17, 21, 30, 92, 6, 54, 9, 37, 127, 65, 95, 35, 34, 23, 13, 76, 84, 52, 54, 19, 120, 60, 97, 60, 82, 59, 48, 89, 34, 6, 42, 69, 89, 6, 65, 39, 17, 67, 77, 86, 42, 8, 90]

    private static let salt = "test.groq.v1"

    /// Байт `i` ключа хранится как `keyUTF8[i] ^ saltUTF8[i % saltUTF8.count]`.
    /// Соль — UTF-8 строка `test.groq.v1`. Декодирование — тот же XOR.
    static func decodedKey() -> String {
        let saltBytes = Array(salt.utf8)
        guard !obfuscatedKey.isEmpty, !saltBytes.isEmpty else { return "" }

        var decoded = [UInt8]()
        decoded.reserveCapacity(obfuscatedKey.count)
        for (index, byte) in obfuscatedKey.enumerated() {
            decoded.append(byte ^ saltBytes[index % saltBytes.count])
        }
        return String(bytes: decoded, encoding: .utf8) ?? ""
    }
}
