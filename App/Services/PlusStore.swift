import Foundation
import StoreKit

/// Quote Plus 구매 상태를 관리한다.
///
/// 이 앱에 광고는 없다. 수익은 오직 이 구매 하나에서 나온다.
///
/// 설계 원칙 두 가지.
/// 1. **잠금 판단은 여기서만 한다.** 화면은 `isUnlocked(_:)` 를 물을 뿐,
///    "구독인지 평생인지"를 알 필요가 없다.
/// 2. **실패해도 앱이 멈추지 않는다.** 스토어를 못 불러오거나 검증이 실패하면
///    무료 사용자로 취급하고 넘어간다. 무료 기능은 전부 그대로 동작한다.
@MainActor
@Observable
final class PlusStore {

    /// App Store Connect 에 등록할 상품 식별자.
    enum ProductID {
        /// 자동 갱신 구독(월간). 기본으로 권하는 플랜이다.
        static let monthly = "com.quoteday.plus.monthly"
        /// 자동 갱신 구독(연간).
        static let yearly = "com.quoteday.plus.yearly"
        /// 비소모성 평생 이용권.
        static let lifetime = "com.quoteday.plus.lifetime"

        /// 페이월에 보일 순서. 스토어는 순서를 보장하지 않으므로 여기서 고정한다.
        static let all: [String] = [monthly, yearly, lifetime]
    }

    /// 구매 시도의 결과. 화면은 이 값만 보고 안내 문구를 고른다.
    enum PurchaseOutcome: Equatable {
        case purchased
        case cancelled
        /// 가족 공유 승인 대기 등, 나중에 결정되는 경우.
        case pending
        case failed(String)
    }

    // MARK: - 상태

    /// Plus 이용 권한이 있는지.
    ///
    /// 판매를 내려 둔 동안에는 항상 `true` 다 — 살 방법이 없는데 잠가 두면
    /// 사용자에게는 열 수 없는 자물쇠만 남는다.
    var isPlus: Bool {
        guard AppFeatureFlags.isPlusEnabled else { return true }
        return isDebugUnlocked || hasEntitlement
    }

    /// 스토어에서 불러온 상품. 순서는 `ProductID.all` 을 따른다.
    private(set) var products: [Product] = []
    /// 상품을 불러오는 중인지.
    private(set) var isLoadingProducts = false
    /// 구매가 진행 중인 상품 식별자.
    private(set) var purchasingProductID: String?
    /// 사용자에게 보여 줄 마지막 오류.
    var lastErrorMessage: String?

    /// 실제 영수증으로 확인된 권한.
    private(set) var hasEntitlement = false

    /// 개발·심사용 토글. 결제 없이 Plus 화면을 확인할 때 쓴다.
    ///
    /// 릴리스 빌드에서는 설정 화면에 노출되지 않으므로 켤 방법이 없다.
    var isDebugUnlocked: Bool {
        get {
            access(keyPath: \.isDebugUnlocked)
            return storedDebugUnlocked
        }
        set {
            withMutation(keyPath: \.isDebugUnlocked) {
                storedDebugUnlocked = newValue
                defaults.set(newValue, forKey: SharedDefaultsKey.plusDebugUnlocked)
            }
        }
    }

    @ObservationIgnored private var storedDebugUnlocked: Bool
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updateListener: Task<Void, Never>?

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.storedDebugUnlocked = defaults.bool(forKey: SharedDefaultsKey.plusDebugUnlocked)

        // 판매를 내려 둔 동안에는 StoreKit 을 아예 건드리지 않는다.
        guard AppFeatureFlags.isPlusEnabled else { return }

        // 앱 밖에서 일어난 구매(가족 공유 승인, 환불, 다른 기기에서의 구매)를 받는다.
        self.updateListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(update)
            }
        }
    }

    deinit {
        updateListener?.cancel()
    }

    // MARK: - 잠금 판단

    /// 이 기능을 지금 쓸 수 있는지.
    func isUnlocked(_ feature: PlusFeature) -> Bool {
        // 현재는 모든 Plus 기능이 하나의 권한으로 묶여 있다.
        // 기능별로 다르게 팔 일이 생기면 여기만 바꾸면 된다.
        _ = feature
        return isPlus
    }

    /// 화면에 구매·페이월·PLUS 표식을 그려도 되는지.
    /// 잠금 판단(`isUnlocked`)과 분리해 둔다 — 판매를 내려 두면
    /// "열려 있지만 파는 중은 아닌" 상태가 되기 때문이다.
    var isStoreVisible: Bool { AppFeatureFlags.isPlusEnabled }

    // MARK: - 스토어

    /// 상품 정보를 불러온다. 실패해도 던지지 않는다 — 페이월이 가격 없이 뜰 뿐이다.
    func loadProducts() async {
        guard AppFeatureFlags.isPlusEnabled else { return }
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: ProductID.all)
            // 스토어는 순서를 보장하지 않는다. 화면에 보일 순서를 여기서 고정한다.
            products = ProductID.all.compactMap { id in
                fetched.first { $0.id == id }
            }
        } catch {
            AppLog.plus.error("상품을 불러오지 못했습니다: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 저장된 영수증으로 권한을 다시 계산한다. 앱이 활성화될 때마다 호출한다.
    func refreshEntitlements() async {
        guard AppFeatureFlags.isPlusEnabled else { return }

        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            // 환불되었거나 업그레이드로 대체된 거래는 권한에서 뺀다.
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration <= .now { continue }
            unlocked = true
        }
        hasEntitlement = unlocked
    }

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "구매를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요."
                    return .failed("검증 실패")
                }
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("알 수 없는 결과")
            }
        } catch {
            AppLog.plus.error("구매 실패: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "결제를 완료하지 못했습니다. 네트워크 상태를 확인해 주세요."
            return .failed(error.localizedDescription)
        }
    }

    /// 기기를 바꿨거나 앱을 다시 깐 사용자를 위한 복원.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !hasEntitlement {
                lastErrorMessage = "복원할 구매 내역이 없습니다."
            }
        } catch {
            AppLog.plus.error("복원 실패: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "구매 내역을 복원하지 못했습니다."
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}
