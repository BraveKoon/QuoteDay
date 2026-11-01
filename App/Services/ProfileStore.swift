import Foundation

/// 사용자의 로그인 상태와 닉네임.
///
/// 이 앱은 **서버가 없다.** 그래서 Apple 로그인은 "계정을 서버에 만드는 일"이
/// 아니라 "이 기기의 주인이 누구인지 밝히는 일"에 가깝다. Apple 이 돌려준
/// 사용자 식별자와 이름만 기기에 저장하고, 로그인 없이 쓰는 사람에게도 똑같이
/// 닉네임을 받는다. 어느 쪽이든 앱의 기능은 하나도 줄지 않는다.
///
/// 값은 App Group `UserDefaults` 에 저장된다. 위젯도 닉네임을 읽을 수 있다.
@MainActor
@Observable
final class ProfileStore {

    /// 어떻게 들어왔는지.
    ///
    /// `.guest` 는 "로그인 없이 사용하기"다. 계정은 없지만 사용자는 있다.
    enum SignInProvider: String, Codable, Sendable {
        case guest
        case apple

        var isApple: Bool { self == .apple }
    }

    /// 닉네임 길이 제한. 화면에서 입력 길이를 막고, 여기서도 한 번 더 자른다.
    static let nicknameLimit = 20

    @ObservationIgnored private let defaults: UserDefaults

    @ObservationIgnored private var storedProvider: SignInProvider?
    @ObservationIgnored private var storedAppleUserIdentifier: String?
    @ObservationIgnored private var storedAppleDisplayName: String?
    @ObservationIgnored private var storedAppleEmail: String?
    @ObservationIgnored private var storedNickname: String
    @ObservationIgnored private var storedCompleted: Bool

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.storedProvider = defaults.string(forKey: SharedDefaultsKey.signInProvider)
            .flatMap(SignInProvider.init(rawValue:))
        self.storedAppleUserIdentifier = defaults.string(forKey: SharedDefaultsKey.appleUserIdentifier)
        self.storedAppleDisplayName = defaults.string(forKey: SharedDefaultsKey.appleDisplayName)
        self.storedAppleEmail = defaults.string(forKey: SharedDefaultsKey.appleEmail)
        self.storedNickname = defaults.string(forKey: SharedDefaultsKey.nickname) ?? ""
        self.storedCompleted = defaults.bool(forKey: SharedDefaultsKey.onboardingCompleted)
    }

    // MARK: - 상태

    /// 로그인 방식. 안내 화면을 끝내기 전에는 nil 이다.
    var provider: SignInProvider? {
        access(keyPath: \.provider)
        return storedProvider
    }

    /// Apple 로그인으로 들어왔는지.
    var isSignedInWithApple: Bool {
        access(keyPath: \.isSignedInWithApple)
        return storedProvider?.isApple ?? false
    }

    /// Apple 이 준 이름(최초 로그인 때 한 번만 온다). 닉네임 기본값으로 쓴다.
    var appleDisplayName: String? {
        access(keyPath: \.appleDisplayName)
        return storedAppleDisplayName
    }

    /// Apple 이 준 이메일. "가리기"를 고른 경우 실제 주소가 아니라 릴레이 주소다.
    var appleEmail: String? {
        access(keyPath: \.appleEmail)
        return storedAppleEmail
    }

    /// 이 기기에 저장된 Apple 사용자 식별자.
    var appleUserIdentifier: String? {
        access(keyPath: \.appleUserIdentifier)
        return storedAppleUserIdentifier
    }

    /// 닉네임. 홈 인사말과 설정 화면에 쓴다.
    var nickname: String {
        get {
            access(keyPath: \.nickname)
            return storedNickname
        }
        set {
            let cleaned = Self.cleaned(newValue)
            withMutation(keyPath: \.nickname) {
                storedNickname = cleaned
                if cleaned.isEmpty {
                    defaults.removeObject(forKey: SharedDefaultsKey.nickname)
                } else {
                    defaults.set(cleaned, forKey: SharedDefaultsKey.nickname)
                }
            }
        }
    }

    /// 첫 실행 안내를 끝냈는지. false 면 앱이 안내 화면만 보여 준다.
    var hasCompletedOnboarding: Bool {
        access(keyPath: \.hasCompletedOnboarding)
        return storedCompleted
    }

    /// 설정 화면에 보여 줄 계정 요약. 닉네임이 비어 있으면 nil.
    var greetingName: String? { nickname.isEmpty ? nil : nickname }

    // MARK: - 진행

    /// Apple 로그인 결과를 저장한다. 닉네임은 다음 단계에서 정한다.
    func applyAppleCredential(_ credential: AppleSignIn.Credential) {
        withMutation(keyPath: \.provider) {
            storedProvider = .apple
            storedAppleUserIdentifier = credential.userIdentifier
            defaults.set(SignInProvider.apple.rawValue, forKey: SharedDefaultsKey.signInProvider)
            defaults.set(credential.userIdentifier, forKey: SharedDefaultsKey.appleUserIdentifier)
        }
        // 이름·이메일은 **최초 1회만** 온다. 두 번째 로그인부터는 nil 이므로
        // 이미 저장된 값을 지우지 않는다.
        if let name = credential.displayName, !name.isEmpty {
            withMutation(keyPath: \.appleDisplayName) {
                storedAppleDisplayName = name
                defaults.set(name, forKey: SharedDefaultsKey.appleDisplayName)
            }
        }
        if let email = credential.email, !email.isEmpty {
            withMutation(keyPath: \.appleEmail) {
                storedAppleEmail = email
                defaults.set(email, forKey: SharedDefaultsKey.appleEmail)
            }
        }
    }

    /// 안내 화면에서 "로그인 없이 사용하기"를 고른다.
    func continueAsGuest() {
        withMutation(keyPath: \.provider) {
            storedProvider = .guest
            defaults.set(SignInProvider.guest.rawValue, forKey: SharedDefaultsKey.signInProvider)
        }
    }

    /// 닉네임을 정하고 안내를 끝낸다.
    func finishOnboarding(nickname: String) {
        self.nickname = nickname
        withMutation(keyPath: \.hasCompletedOnboarding) {
            storedCompleted = true
            defaults.set(true, forKey: SharedDefaultsKey.onboardingCompleted)
        }
    }

    /// 로그아웃. 안내 화면으로 돌아가고, **명언·기록은 지우지 않는다.**
    /// (계정이 없는 앱이라 "로그아웃"은 곧 "처음 화면으로"다.)
    func signOut() {
        withMutation(keyPath: \.provider) {
            storedProvider = nil
            storedAppleUserIdentifier = nil
            storedAppleDisplayName = nil
            storedAppleEmail = nil
            storedNickname = ""
            storedCompleted = false
            for key in [
                SharedDefaultsKey.signInProvider,
                SharedDefaultsKey.appleUserIdentifier,
                SharedDefaultsKey.appleDisplayName,
                SharedDefaultsKey.appleEmail,
                SharedDefaultsKey.nickname,
                SharedDefaultsKey.onboardingCompleted
            ] {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - 도우미

    /// 앞뒤 공백을 지우고, 너무 길면 자른다. (`@Observable` 은 계산 프로퍼티의
    /// `didSet` 을 쓸 수 없어 변이 지점을 한곳으로 모아 둔다.)
    static func cleaned(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > nicknameLimit else { return trimmed }
        return String(trimmed.prefix(nicknameLimit))
    }

    /// 닉네임으로 쓸 수 있는지. (지금은 비어 있지만 않으면 된다.)
    static func isValid(nickname: String) -> Bool {
        !cleaned(nickname).isEmpty
    }
}
