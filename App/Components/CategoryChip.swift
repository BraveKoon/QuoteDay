import SwiftUI

/// 카테고리를 나타내는 작은 클레이 칩.
struct CategoryChip: View {
    enum Size {
        case regular, small

        var font: Font {
            switch self {
            case .regular: ClayFont.callout()
            case .small: ClayFont.caption()
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .regular: ClayTheme.Spacing.s
            case .small: ClayTheme.Spacing.xs + 2
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .regular: ClayTheme.Spacing.xs + 1
            case .small: 4
            }
        }
    }

    let category: AppCategory
    var size: Size = .regular
    var showsTitle: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Text(category.emoji)
            if showsTitle {
                Text(category.title)
                    .font(size.font)
                    .foregroundStyle(ClayTheme.textOnTint)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .clayCard(cornerRadius: ClayTheme.Radius.chip, tint: category.tint, elevation: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("카테고리 \(category.title)")
    }
}

/// 카테고리를 고르는 그리드. 일정 편집과 설정에서 함께 쓴다.
struct CategoryPicker: View {
    @Binding var selection: AppCategory
    var categories: [AppCategory] = AppCategory.allCases

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: ClayTheme.Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: ClayTheme.Spacing.s) {
            ForEach(categories) { category in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = category
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(category.emoji)
                        Text(category.title)
                            .font(ClayFont.callout())
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ClayTheme.Spacing.s)
                    .foregroundStyle(
                        selection == category ? ClayTheme.textOnTint : ClayTheme.textSecondary
                    )
                }
                .buttonStyle(CategoryButtonStyle(
                    category: category,
                    isSelected: selection == category
                ))
                .accessibilityLabel(category.title)
                .accessibilityAddTraits(selection == category ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

private struct CategoryButtonStyle: ButtonStyle {
    let category: AppCategory
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isSelected {
                configuration.label
                    .clayCard(
                        cornerRadius: ClayTheme.Radius.control,
                        tint: category.tint,
                        elevation: 10,
                        isPressed: configuration.isPressed
                    )
            } else {
                configuration.label
                    .claySunken(cornerRadius: ClayTheme.Radius.control)
                    .scaleEffect(configuration.isPressed ? 0.97 : 1)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 프리뷰에서 선택 상태를 보여 주기 위한 래퍼.
private struct CategoryPickerPreview: View {
    @State private var selection: AppCategory = .study

    var body: some View {
        ScrollView {
            VStack(spacing: ClayTheme.Spacing.l) {
                HStack {
                    CategoryChip(category: .study)
                    CategoryChip(category: .exercise, size: .small)
                }
                CategoryPicker(selection: $selection)
            }
            .padding(ClayTheme.Spacing.l)
        }
        .clayBackground()
    }
}

#Preview("카테고리") {
    CategoryPickerPreview()
}
