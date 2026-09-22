import Foundation

/// 오늘의 명언을 **누가 어떤 기준으로 고르는지**를 한곳에 모은다.
///
/// 앱과 위젯은 서로 다른 프로세스에서 각자 계산한다. 그래서 같은 결과가 나오려면
/// 같은 입력으로 같은 규칙을 밟아야 하는데, 규칙이 두 곳에 나뉘어 있으면
/// 한쪽만 고쳐도 아무 데서도 오류가 나지 않는다 — 두 곳의 문장이 조용히 갈릴 뿐이다.
/// 실제로 그렇게 갈렸다. 그래서 규칙을 여기 한 벌만 둔다.
public enum DailyQuoteSelection {

    /// 앱 설정의 선호 카테고리. 고르지 않았으면 nil.
    ///
    /// 위젯 프로세스에서도 읽어야 해서 `AppSettings`(앱 타겟) 대신 공유 저장소를
    /// 직접 본다.
    public static func preferredCategory(defaults: UserDefaults = AppGroup.defaults) -> AppCategory? {
        guard let stored = defaults.string(forKey: SharedDefaultsKey.preferredCategory) else {
            return nil
        }
        return AppCategory(rawValue: stored)
    }

    /// 위젯이 실제로 쓸 카테고리.
    ///
    /// - Parameter widgetChoice: 위젯을 길게 눌러 고른 카테고리. "앱 설정 따름"이면 nil.
    ///
    /// 위젯에서 따로 고르지 않았으면 **앱 설정을 따른다.** 위젯에는 자기만의
    /// 카테고리 설정이 있어서, 앱에서 카테고리를 고른 사람의 홈 화면에는 서로 다른
    /// 두 문장이 나란히 떠 있었다.
    public static func resolvedCategory(
        widgetChoice: AppCategory?,
        defaults: UserDefaults = AppGroup.defaults
    ) -> AppCategory? {
        widgetChoice ?? preferredCategory(defaults: defaults)
    }
}
