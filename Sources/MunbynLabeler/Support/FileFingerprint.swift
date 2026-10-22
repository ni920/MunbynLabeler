import CryptoKit
import Foundation

enum FileFingerprint {
    static func sha256LikeFingerprint(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
