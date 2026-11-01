import AuthenticationServices
import SwiftUI

/// 애플이 제공하는 로그인 버튼을 앱의 클레이 스타일에 맞춰 감싼 것.
///
/// 버튼 모양은 **바꾸지 않는다.** 애플이 그려 준 그대로 두고 모서리만 다듬는다.
/// (직접 만든 버튼은 App Store 심사에서 반려된다.)
struct AppleSignInButton: View {
    /// 로그인에 성공했을 때. 취소·실패면 불리지 않는다.
    var onCredential: (AppleSignIn.Credential) -> Void
    /// 실패를 알린다. 사용자가 그냥 닫았으면 nil 이 온다.
    var onFailure: (String?) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            // 이름과 이메일은 **최초 로그인에서만** 온다. 그래서 처음에 다 받는다.
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                if let credential = AppleSignIn.credential(from: authorization) {
                    onCredential(credential)
                } else {
                    onFailure(L("Apple 로그인 정보를 읽지 못했습니다. 다시 시도해 주세요."))
                }
            case .failure(let error):
                onFailure(AppleSignIn.message(for: error))
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: ClayTheme.Radius.control, style: .continuous))
        .accessibilityLabel(Text("Apple로 로그인"))
    }
}

#Preview("Apple 로그인 버튼") {
    VStack {
        AppleSignInButton(onCredential: { _ in }, onFailure: { _ in })
    }
    .padding()
    .clayBackground()
}
