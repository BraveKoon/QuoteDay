import SwiftUI

/// "1년 전 오늘, 이렇게 적었어요".
///
/// 이 릴리스에서 **가장 강력한 카드**다. 기록을 쓰게 만드는 것보다 어려운 일은
/// 쓴 것을 값어치 있게 만드는 것인데, 그 답이 이거다. 개발비는 거의 0이다 —
/// 데이터가 이미 다 있다.
///
/// 경쟁 앱이 명언을 500편 넣어도 내 석 달치 기록은 복사하지 못한다.
/// 콘텐츠 앱이 가질 수 있는 해자는 이것 하나뿐이다.
struct ThrowbackCard: View {
    @Environment(NoteStore.self) private var notes
    @Environment(AppRouter.self) private var router

    private var throwback: Throwback? {
        JournalRepository.throwback(in: notes.notes.map(\.archived))
    }

    var body: some View {
        // 없으면 그리지 않는다. 빈 카드로 자리를 채우지 않는다.
        if let throwback {
            VStack(alignment: .leading, spacing: ClayTheme.Spacing.s) {
                Label(throwback.headline, systemImage: "clock.arrow.circlepath")
                    .font(ClayFont.caption())
                    .foregroundStyle(ClayTheme.textSecondary)

                Text(throwback.note.text)
                    .font(ClayFont.body())
                    .foregroundStyle(ClayTheme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                ClayDivider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\u{201C}\(throwback.note.quoteText)\u{201D}")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(throwback.note.authorName)")
                        .font(ClayFont.caption())
                        .foregroundStyle(ClayTheme.textSecondary)
                }
            }
            .padding(ClayTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clayCard(cornerRadius: ClayTheme.Radius.card)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(throwback.headline). \(throwback.note.text)")
            .onTapGesture {
                if let quote = QuoteService.shared.quote(slug: throwback.note.quoteSlug) {
                    router.showQuote(quote)
                }
            }
        }
    }
}
