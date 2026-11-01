import AuthenticationServices
import Foundation

/// Sign in with Apple.
///
/// 서버가 없는 앱이라 토큰을 어디로 보내지 않는다. 여기서 하는 일은 두 가지다.
///
/// 1. 사용자가 **본인 Apple 계정으로** 들어왔다는 사실을 확인한다.
/// 2. 애플이 돌려준 사용자 식별자·이름·이메일을 기기에 저장한다.
///
/// 버튼은 애플이 제공하는 `SignInWithAppleButton` 을 그대로 쓴다. 모양을
/// 앱 디자인에 맞춰 새로 그리면 App Store 심사에서 문제가 된다.
/// 이 타입은 그 버튼이 돌려준 결과를 앱이 쓰는 형태로 바꾸는 일만 한다.
enum AppleSignIn {

    /// 애플이 돌려준 최소한의 신원 정보.
    struct Credential: Sendable {
        /// 같은 사람인지 확인하는 데 쓰는 안정적인 식별자.
        let userIdentifier: String
        /// 이름. **최초 로그인에서만** 온다. 두 번째부터는 nil.
        let displayName: String?
        /// 이메일. 사용자가 "가리기"를 고르면 릴레이 주소가 온다.
        let email: String?
    }

    /// `ASAuthorization` → `Credential`. 애플 자격 증명이 아니면 nil.
    static func credential(from authorization: ASAuthorization) -> Credential? {
        // `ASAuthorizationAppleIDCredential` 의 식별자는 `user` 다.
        // (`userIdentifier` 라는 속성은 없다 — 자주 틀리는 이름이다.)
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              !credential.user.isEmpty else {
            return nil
        }
        return Credential(
            userIdentifier: credential.user,
            displayName: credential.fullName.flatMap(formattedName),
            email: credential.email
        )
    }

    /// 실패를 화면에 보여 줄 한 줄로 바꾼다.
    ///
    /// **사용자가 그냥 닫은 경우는 nil** 이다. 취소는 오류가 아니므로
    /// 아무 말도 하지 않는 것이 맞다.
    static func message(for error: Error) -> String? {
        guard let authError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }
        switch authError.code {
        case .canceled:
            return nil
        case .unknown, .notHandled, .failed:
            // 시뮬레이터이거나 Apple 계정이 설정되지 않은 기기에서 가장 흔하다.
            return L("이 기기에서는 Apple 로그인을 사용할 수 없습니다. 로그인 없이 사용할 수 있어요.")
        case .invalidResponse:
            return L("Apple 로그인 응답을 이해하지 못했습니다. 잠시 뒤 다시 시도해 주세요.")
        default:
            return error.localizedDescription
        }
    }

    /// 애플 쪽에 이 사용자와의 연결이 아직 살아 있는지 묻는다.
    ///
    /// 설정 화면에서 "Apple 로그인 연결됨"을 확인할 때 쓴다. 실패는 조용히
    /// nil 로 본다 — 표시를 못 할 뿐 로그인 자체와는 상관없다.
    static func credentialState(for userIdentifier: String) async
        -> ASAuthorizationAppleIDProvider.CredentialState? {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    /// `PersonNameComponents` → "홍길동". 비어 있으면 nil.
    private static func formattedName(_ components: PersonNameComponents) -> String? {
        let formatted = PersonNameComponentsFormatter().string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}
