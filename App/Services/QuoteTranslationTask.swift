import SwiftUI
import Translation

/// ZenQuotes 에서 받아 온 영어 명언을 기기에서 한국어로 옮긴다.
///
/// ## 왜 애플의 온디바이스 번역인가
///
/// 번역 API 를 쓰려면 키가 필요하고, 키를 앱에 넣으면 꺼내 쓰는 사람을 막을 수 없다.
/// 서버를 두면 그 서버를 운영해야 한다. 애플의 Translation 프레임워크는
/// **키도 서버도 비용도 없고 문장이 기기 밖으로 나가지 않는다.**
///
/// ## 대가
///
/// 프로그램으로 번역을 부르는 API 는 **iOS 18 부터**다(17.4 는 시스템 시트만 띄운다).
/// 그래서 iOS 17 에서는 이 기능이 조용히 꺼지고 영어가 그대로 보인다.
/// 앱 전체의 최소 버전을 올리지 않은 것은, 번역 하나 때문에 쓰던 사람을
/// 떨어뜨릴 이유가 없어서다.
///
/// 처음 한 번은 시스템이 한국어 번역 자료를 내려받겠냐고 묻는다. 거절해도 앱은 그대로 돈다.
///
/// ## 기계 번역이라는 것
///
/// 잠언은 기계가 옮기기 어려운 글이다. 그래서 **영어 원문을 지우지 않고**
/// 번역문 아래에 남긴다(`Quote.originalText`). 번역이 어색하면 원문을 볼 수 있고,
/// 설정에서 번역을 끄면 예전처럼 영어만 보인다.
/// 이 기기에서 기기 내 번역을 쓸 수 있는지.
///
/// 화면이 "왜 번역이 안 되는지"를 말해 줄 수 있도록 따로 꺼내 두었다.
/// 조용히 아무 일도 일어나지 않는 것보다 이유를 아는 편이 낫다.
enum QuoteTranslationSupport {
    static var isAvailable: Bool {
        if #available(iOS 18.0, *) { true } else { false }
    }
}

struct RemoteQuoteTranslation: ViewModifier {
    @Environment(AppEnvironment.self) private var environment

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.modifier(
                TranslationRunner(
                    source: environment.pendingTranslationSource,
                    onTranslated: { korean, source in
                        environment.applyTranslation(korean, for: source)
                    }
                )
            )
        } else {
            content
        }
    }
}

/// 실제로 번역을 도는 부분. iOS 18 아래에서는 이 타입 자체가 쓰이지 않는다.
@available(iOS 18.0, *)
private struct TranslationRunner: ViewModifier {
    /// 번역할 영어 원문. nil 이면 할 일이 없다.
    let source: String?
    let onTranslated: (String, String) -> Void

    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .task(id: source) {
                guard source != nil else {
                    configuration = nil
                    return
                }
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "ko")
                )
            }
            .translationTask(configuration) { session in
                guard let source else { return }
                do {
                    let response = try await session.translate(source)
                    onTranslated(response.targetText, source)
                } catch {
                    // 자료를 안 받았거나 거절했을 때도 여기로 온다. 영어를 그대로 두면 된다.
                    AppLog.quotes.debug(
                        "명언 번역 실패: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
    }
}

extension View {
    /// 오늘의 명언이 영어면 한국어로 옮긴다. 최상위 화면에 한 번만 붙인다.
    func translatingRemoteQuote() -> some View {
        modifier(RemoteQuoteTranslation())
    }
}
