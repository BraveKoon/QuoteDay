import StoreKit
import SwiftUI

/// 한 달을 되돌아보는 화면.
///
/// 기록의 **대가**다. 이게 없으면 기록은 그냥 숙제다.
///
/// 열리는 조건이 하나 있다 — 기록 세 편. 빈 회고는 안 만드는 것만 못하다.
struct MonthlyReviewView: View {
    let month: Date

    @Environment(NoteStore.self) private var notes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    /// 공유용으로 구워 둔 이미지. 화면이 뜬 뒤에 만든다.
    @State private var sharedFile: URL?
    /// 회고를 끝까지 본 사람에게만 별점을 묻는다.
    @State private var sawTheReview = false

    private var review: MonthlyReview {
        MonthlyReview.make(
            from: notes.notes.map(\.archived),
            month: month,
            categoryForSlug: { slug in QuoteService.shared.quote(slug: slug)?.category }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ClayTheme.Spacing.m) {
                    if review.isWorthShowing {
                        content(review)
                    } else {
                        notEnoughYet(review)
                    }
                }
                .padding(ClayTheme.Spacing.m)
                .padding(.bottom, ClayTheme.Spacing.l)
            }
            .scrollIndicators(.hidden)
            .clayBackground()
            .navigationTitle(Formatters.monthTitle.string(from: month))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onDisappear {
                // 회고를 **처음 닫은 직후**가 별점이 가장 높게 나오는 순간이다.
                // 앱을 열자마자 묻는 것과는 완전히 다른 자리다.
                guard sawTheReview else { return }
                requestReview()
            }
        }
    }

    // MARK: - 내용

    @ViewBuilder
    private func content(_ review: MonthlyReview) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.xs) {
            Text(review.headline)
                .font(ClayFont.hero())
                .foregroundStyle(ClayTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { sawTheReview = true }

        statRows(review)

        if let longest = review.longestNote {
            highlight(longest)
        }

        bookends(review)

        if let sharedFile {
            ShareLink(item: sharedFile, preview: SharePreview(review.headline)) {
                Label("회고 이미지로 공유하기", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .clayButton(.primary, fullWidth: true)
        } else {
            // 1080×1080 을 굽는 동안 화면을 붙잡지 않는다. 다 되면 버튼이 바뀐다.
            Label("공유 이미지 만드는 중…", systemImage: "hourglass")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .task { sharedFile = makeShareImage(review) }
        }
    }

    private func statRows(_ review: MonthlyReview) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            if let author = review.topAuthor {
                statRow("가장 자주 만난 인물", author, symbol: "person.fill")
            }
            if let category = review.topCategory {
                statRow("가장 많이 읽은 갈래", "\(category.emoji) \(category.title)", symbol: "square.grid.2x2.fill")
            }
            if let mood = review.topMood, let parsed = QuoteMood(rawValue: mood) {
                statRow("가장 많이 고른 기분", "\(parsed.emoji) \(parsed.title)", symbol: "heart.fill")
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func statRow(_ title: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: ClayTheme.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(ClayTheme.accent)
                .frame(width: 22)
            Text(title)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Spacer(minLength: ClayTheme.Spacing.xs)
            Text(value)
                .font(ClayFont.headline())
                .foregroundStyle(ClayTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// 그달 가장 긴 글. 마음이 가장 많이 움직였던 날이다.
    private func highlight(_ note: ArchivedNote) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            Label("가장 길게 쓴 날", systemImage: "text.alignleft")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Text(note.text)
                .font(ClayFont.body())
                .foregroundStyle(ClayTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text(note.dayKey)
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func bookends(_ review: MonthlyReview) -> some View {
        VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
            if let first = review.firstNote {
                bookend("이 달의 첫 기록", first)
            }
            if let last = review.lastNote, last.id != review.firstNote?.id {
                ClayDivider()
                bookend("마지막 기록", last)
            }
        }
        .padding(ClayTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard()
    }

    private func bookend(_ title: String, _ note: ArchivedNote) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title) · \(note.dayKey)")
                .font(ClayFont.caption())
                .foregroundStyle(ClayTheme.textSecondary)
            Text(note.text)
                .font(ClayFont.callout())
                .foregroundStyle(ClayTheme.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 아직 열 때가 아니다.
    private func notEnoughYet(_ review: MonthlyReview) -> some View {
        EmptyStateView(
            symbol: "calendar.badge.clock",
            title: "아직 되돌아볼 것이 적어요",
            message: review.noteCount == 0
                ? "이 달에는 남긴 기록이 없어요. 홈에서 오늘 한 줄을 남겨 보세요."
                : "기록 \(MonthlyReview.minimumNotes)편부터 회고를 만들어요. 지금은 \(review.noteCount)편이에요."
        )
        .clayCard()
    }

    // MARK: - 공유

    private func makeShareImage(_ review: MonthlyReview) -> URL? {
        QuoteCardRenderer.pngFile(
            MonthlyReviewCard(review: review, side: QuoteCardRenderer.exportSide),
            named: "QuoteDay-회고-\(month.dayKey()).png"
        )
    }
}

// MARK: - 공유 이미지

/// 회고를 1080×1080 한 장으로. 공유 카드와 같은 크기를 쓴다.
struct MonthlyReviewCard: View {
    let review: MonthlyReview
    let side: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: side * 0.035) {
            Text(Formatters.monthTitle.string(from: review.month))
                .font(.system(size: side * 0.045, weight: .medium))
                .foregroundStyle(.secondary)

            Text(review.headline)
                .font(.system(size: side * 0.075, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let author = review.topAuthor {
                Text("가장 자주 만난 인물 · \(author)")
                    .font(.system(size: side * 0.038))
                    .foregroundStyle(.secondary)
            }

            if let longest = review.longestNote {
                Spacer(minLength: 0)
                Text("\u{201C}\(longest.text)\u{201D}")
                    .font(.system(size: side * 0.045))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            Text("QuoteDay")
                .font(.system(size: side * 0.034, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(side * 0.085)
        .frame(width: side, height: side, alignment: .topLeading)
        .background(ClayTheme.background)
    }
}

/// `sheet(item:)` 에 넘기기 위한 껍데기. `Date` 는 `Identifiable` 이 아니다.
struct ReviewMonth: Identifiable, Equatable {
    let date: Date
    var id: String { date.dayKey() }
}
