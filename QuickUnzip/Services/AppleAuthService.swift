import Foundation
import AuthenticationServices

class AppleAuthService: NSObject, ObservableObject {
    static let shared = AppleAuthService()

    @Published var isLoggedIn = false
    @Published var userName: String = ""
    @Published var userEmail: String = ""

    private let appleUserIdKey = "apple_user_id"
    private let appleUserNameKey = "apple_user_name"
    private let appleUserEmailKey = "apple_user_email"

    private let baseURL = "https://781391.cn/admin"

    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "cs_device_id") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "cs_device_id")
        return newId
    }

    override init() {
        super.init()
        loadLocalUser()
        checkCredentialState()
    }

    // MARK: - Load Local User

    private func loadLocalUser() {
        if let userId = UserDefaults.standard.string(forKey: appleUserIdKey), !userId.isEmpty {
            isLoggedIn = true
            userName = UserDefaults.standard.string(forKey: appleUserNameKey) ?? ""
            userEmail = UserDefaults.standard.string(forKey: appleUserEmailKey) ?? ""
        }
    }

    // MARK: - Check Credential State

    private func checkCredentialState() {
        guard let userId = UserDefaults.standard.string(forKey: appleUserIdKey), !userId.isEmpty else { return }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    break
                case .revoked, .notFound:
                    self?.logout()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Sign In

    func signIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // MARK: - Logout

    func logout() {
        // Only remove user ID to mark as logged out
        // Keep name and email cached because Apple only provides them on first sign-in
        UserDefaults.standard.removeObject(forKey: appleUserIdKey)
        isLoggedIn = false
        userName = ""
        userEmail = ""
    }

    // MARK: - Send to Server

    private func sendToServer(appleUserId: String, name: String, email: String) {
        guard let url = URL(string: "\(baseURL)/api.php?action=apple_login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "apple_user_id": appleUserId,
            "name": name,
            "email": email
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Apple login server sync failed: \(error)")
            }
        }.resume()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userId = credential.user
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = credential.email ?? ""

        // Apple only returns name/email on first login; use saved values if empty
        let savedName = UserDefaults.standard.string(forKey: appleUserNameKey) ?? ""
        let savedEmail = UserDefaults.standard.string(forKey: appleUserEmailKey) ?? ""
        let finalName = fullName.isEmpty ? savedName : fullName
        let finalEmail = email.isEmpty ? savedEmail : email

        UserDefaults.standard.set(userId, forKey: appleUserIdKey)
        if !finalName.isEmpty {
            UserDefaults.standard.set(finalName, forKey: appleUserNameKey)
        }
        if !finalEmail.isEmpty {
            UserDefaults.standard.set(finalEmail, forKey: appleUserEmailKey)
        }

        DispatchQueue.main.async {
            self.isLoggedIn = true
            self.userName = finalName
            self.userEmail = finalEmail
        }

        sendToServer(appleUserId: userId, name: finalName, email: finalEmail)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In failed: \(error)")
    }
}
