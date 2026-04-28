import CryptoKit
import DeviceCheck
import Foundation

enum AppAttestError: Error {
    case notSupported
    case invalidResponse
}

final class AppAttestService {
    static let shared = AppAttestService()

    private let baseURL = URL(string: "https://notatherapist.vercel.app")!
    private let keyIDKey = "appAttestKeyID"
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    func challenge() async throws -> String {
        let (data, response) = try await session.data(from: baseURL.appending(path: "/api/attest/challenge"))
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AppAttestError.invalidResponse
        }
        return try JSONDecoder().decode(AppAttestChallengeResponse.self, from: data).challenge
    }

    func assertionHeaders(for payload: Data) async -> [String: String] {
        guard isSupported else { return [:] }

        do {
            let keyID = try await existingOrVerifiedKeyID()
            let clientDataHash = Data(SHA256.hash(data: payload))
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
            let authentication = AppAttestAssertion(keyId: keyID, assertion: assertion.base64EncodedString())
            let encoded = try JSONEncoder().encode(authentication).base64EncodedString()
            return ["X-App-Attest": encoded]
        } catch {
            UserDefaults.standard.removeObject(forKey: keyIDKey)
            return [:]
        }
    }

    private func existingOrVerifiedKeyID() async throws -> String {
        if let keyID = UserDefaults.standard.string(forKey: keyIDKey) {
            return keyID
        }
        return try await attestNewKey()
    }

    private func attestNewKey() async throws -> String {
        guard isSupported else { throw AppAttestError.notSupported }

        let challenge = try await challenge()
        let keyID = try await DCAppAttestService.shared.generateKey()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)

        var request = URLRequest(url: baseURL.appending(path: "/api/attest/verify"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            AppAttestVerifyRequest(
                keyId: keyID,
                challenge: challenge,
                attestation: attestation.base64EncodedString()
            )
        )

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AppAttestError.invalidResponse
        }

        UserDefaults.standard.set(keyID, forKey: keyIDKey)
        return keyID
    }
}

private struct AppAttestChallengeResponse: Decodable {
    let ok: Bool
    let challenge: String
}

private struct AppAttestVerifyRequest: Encodable {
    let keyId: String
    let challenge: String
    let attestation: String
}

private struct AppAttestAssertion: Encodable {
    let keyId: String
    let assertion: String
}
