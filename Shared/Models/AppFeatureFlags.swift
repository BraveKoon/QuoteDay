import Foundation

/// 화면 전체를 켜고 끄는 스위치.
///
/// 기능을 지우지 않고 잠시 내려 두고 싶을 때 쓴다. 코드를 지웠다가 다시 쓰면
/// 그 사이에 벌어진 변경과 충돌하지만, 스위치는 한 줄만 되돌리면 된다.
public enum AppFeatureFlags {
    /// Quote Plus 판매를 켤지.
    ///
    /// `false` 이면:
    /// - 유료로 잠겨 있던 기능이 **전부 무료로 열린다**. 살 방법이 없는데 잠가 두면
    ///   사용자는 열 수 없는 자물쇠만 보게 된다. 그건 미뤄 두는 게 아니라 망가뜨리는 것이다.
    /// - 페이월·구매·복원 버튼과 PLUS 표식이 화면에서 사라진다.
    /// - StoreKit 을 아예 건드리지 않는다. 상품 조회도, 거래 감시도 하지 않는다.
    ///
    /// 판매를 시작할 때는 이 값을 `true` 로 바꾸고,
    /// App Store Connect 에 `PlusStore.ProductID` 의 상품을 등록하면 된다.
    public static let isPlusEnabled = false
}
