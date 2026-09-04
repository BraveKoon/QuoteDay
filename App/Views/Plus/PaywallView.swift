import StoreKit
import SwiftUI

/// Quote Plus 구매 화면.
///
/// 무료 기능을 빼앗아 만든 화면이 아니라는 점을 먼저 말한다.
/// 광고가 없다는 사실이 이 앱의 판매 논리이므로 그것을 맨 위에 둔다.
struct PaywallView: View {
    /// 어떤 기능을 누르다 여기 왔는지. 그 기능을 목록 맨 위로 올린다.
    var highlighted: PlusFeature?

    @Environment(PlusStore.self) private var plus
    @Environment(\.dismiss) private var dismiss

    @State private var didPurchase = false
    @State private var noticeMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ClayTheme.Spacing.l) {
                    header
                    featureList
                    productSection
                    restoreButton
                    legalFootnote
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle("Quote Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task { await plus.loadProducts() }
            .alert("안내", isPresented: Binding(
                get: { noticeMessage != nil },
                set: { if !$0 { noticeMessage = nil } }
            )) {
                Button("확인") { noticeMessage = nil }
            } message: {
                Text(noticeMessage ?? "")
            }
            .onChange(of: didPurchase) { _, purchased in
                if purchased { dismiss() }
            }
        }
    }

    // MARK: - 구획

    private var header: some View {
        VStack(spacing: ClayTheme.Spacing.s) {
            Image(systemName: "book.pages")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(ClayTheme.accent)
                .padding(ClayTheme.Spacing.m)
                .claySunken(cornerRadius: ClayTheme.Radius.control)

            Text("명언 뒤의 이야기까지")
                .font(ClayFont.hero())
                .foregroundStyle(ClayTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("QuoteDay 에는 광고가 없습니다. 앞으로도 넣지 않습니다.\nQuote Plus 는 그 약속을 지키면서 앱을 이어 가는 방법이에요.")
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, ClayTheme.Spacing.s)
    }

    /// 눌러서 들어온 기능을 맨 위로 올린 목록.
    private var orderedFeatures: [PlusFeature] {
        guard let highlighted else { return PlusFeature.allCases }
        return [highlighted] + PlusFeature.allCases.filter { $0 != highlighted }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedFeatures.enumerated()), id: \.element.id) { index, feature in
                if index > 0 { ClayDivider() }
                HStack(alignment: .top, spacing: ClayTheme.Spacing.s) {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ClayTheme.accent)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(ClayFont.headline())
                            .foregroundStyle(ClayTheme.textPrimary)
                        Text(feature.detail)
                            .font(ClayFont.caption())
                            .foregroundStyle(ClayTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, ClayTheme.Spacing.s)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    @ViewBuilder
    private var productSection: some View {
        if plus.isPlus {
            VStack(spacing: ClayTheme.Spacing.xs) {
                Label("이미 Quote Plus 를 쓰고 있어요", systemImage: "checkmark.seal.fill")
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.accent)
                Text("고맙습니다. 덕분에 광고 없이 만들고 있어요.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(ClayTheme.Spacing.m)
            .clayCard()
        } else if plus.isLoadingProducts {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(ClayTheme.Spacing.l)
                .clayCard()
        } else if plus.products.isEmpty {
            // 심사 중이거나 오프라인일 때. 화면이 비어 보이지 않게 이유를 적는다.
            VStack(spacing: ClayTheme.Spacing.xs) {
                Text("지금은 가격을 불러올 수 없어요")
                    .font(ClayFont.headline())
                    .foregroundStyle(ClayTheme.textPrimary)
                Text("네트워크 상태를 확인한 뒤 다시 열어 주세요.")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(ClayTheme.Spacing.m)
            .clayCard()
        } else {
            VStack(spacing: ClayTheme.Spacing.s) {
                ForEach(plus.products, id: \.id) { product in
                    productButton(product)
                }
            }
        }
    }

    private func productButton(_ product: Product) -> some View {
        Button {
            Task { await buy(product) }
        } label: {
            HStack(spacing: ClayTheme.Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(ClayFont.headline())
                    Text(subtitle(for: product))
                        .font(ClayFont.caption())
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                if plus.purchasingProductID == product.id {
                    ProgressView().tint(ClayTheme.textOnAccent)
                } else {
                    Text(product.displayPrice)
                        .font(ClayFont.headline())
                }
            }
        }
        .clayButton(.primary, fullWidth: true)
        .disabled(plus.purchasingProductID != nil)
    }

    private func subtitle(for product: Product) -> String {
        if product.subscription != nil {
            return "매년 갱신 · 언제든 해지"
        }
        return "한 번 결제하면 계속 사용"
    }

    private var restoreButton: some View {
        Button("구매 복원") {
            Task {
                await plus.restore()
                if plus.isPlus {
                    didPurchase = true
                } else {
                    noticeMessage = plus.lastErrorMessage ?? "복원할 구매 내역이 없습니다."
                }
            }
        }
        .clayButton(.secondary, fullWidth: true)
    }

    private var legalFootnote: some View {
        VStack(spacing: ClayTheme.Spacing.xs) {
            Text("연간 플랜은 해지하지 않으면 만료 24시간 전에 자동으로 갱신됩니다. 구매 후 App Store 계정 설정에서 언제든 해지할 수 있어요.")
            Text("평생 이용권은 한 번만 결제하며 갱신되지 않습니다.")
        }
        .font(ClayFont.caption())
        .foregroundStyle(ClayTheme.textSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, ClayTheme.Spacing.s)
    }

    // MARK: - 동작

    private func buy(_ product: Product) async {
        switch await plus.purchase(product) {
        case .purchased:
            didPurchase = true
        case .pending:
            noticeMessage = "승인을 기다리는 중이에요. 승인되면 자동으로 열립니다."
        case .cancelled:
            break
        case .failed:
            noticeMessage = plus.lastErrorMessage ?? "결제를 완료하지 못했습니다."
        }
    }
}

#Preview("페이월") {
    PaywallView(highlighted: .behindStory)
        .injecting(AppEnvironment.preview())
}
