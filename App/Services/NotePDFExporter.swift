import CoreGraphics
import Foundation
import SwiftUI

/// 필사 노트를 PDF 한 권으로 굽는다. Quote Plus 전용 기능이다.
///
/// 페이지는 노트 한 개당 한 장이다. 한 페이지에 여러 노트를 욱여넣으면
/// 글이 길 때 잘리는데, 사용자가 쓴 글이 잘려 나가는 것보다는
/// 페이지가 늘어나는 편이 낫다고 봤다.
///
/// 폭은 A4 로 고정하고, 내용이 A4 높이를 넘으면 그 페이지만 길어진다.
/// (PDF 는 페이지마다 다른 크기를 허용한다.)
@MainActor
enum NotePDFExporter {
    /// A4 (72dpi 기준 포인트).
    static let pageWidth: CGFloat = 595
    static let pageHeight: CGFloat = 842

    enum ExportError: LocalizedError {
        case noNotes
        case contextUnavailable

        var errorDescription: String? {
            switch self {
            case .noNotes: "내보낼 노트가 없습니다."
            case .contextUnavailable: "PDF 를 만들 수 없습니다. 저장 공간을 확인해 주세요."
            }
        }
    }

    /// 노트를 PDF 로 저장하고 그 위치를 돌려준다.
    static func export(notes: [QuoteNote], exportedAt: Date = .now) throws -> URL {
        guard !notes.isEmpty else { throw ExportError.noNotes }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuoteDay-노트-\(Formatters.fileStamp.string(from: exportedAt)).pdf")

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard
            let consumer = CGDataConsumer(url: url as CFURL),
            let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, documentInfo(exportedAt))
        else {
            throw ExportError.contextUnavailable
        }

        draw(NoteCoverPage(noteCount: notes.count, exportedAt: exportedAt), into: pdf)
        for (index, note) in notes.enumerated() {
            draw(NotePDFPage(note: note, pageNumber: index + 1), into: pdf)
        }
        pdf.closePDF()

        return url
    }

    // MARK: - 내부

    /// SwiftUI 뷰 한 장을 PDF 페이지로 그린다.
    private static func draw(_ page: some View, into pdf: CGContext) {
        let renderer = ImageRenderer(content: page.frame(width: pageWidth))
        renderer.render { size, drawInContext in
            // 내용이 A4 보다 길면 그 페이지만 늘린다.
            let box = CGRect(x: 0, y: 0, width: pageWidth, height: max(pageHeight, size.height))
            let boxData = withUnsafeBytes(of: box) { Data($0) }
            let info = [kCGPDFContextMediaBox as String: boxData] as CFDictionary

            pdf.beginPDFPage(info)
            drawInContext(pdf)
            pdf.endPDFPage()
        }
    }

    private static func documentInfo(_ exportedAt: Date) -> CFDictionary {
        [
            kCGPDFContextTitle as String: "QuoteDay 노트",
            kCGPDFContextCreator as String: "QuoteDay",
            kCGPDFContextSubject as String: "\(Formatters.fullDate.string(from: exportedAt)) 내보냄"
        ] as CFDictionary
    }
}

// MARK: - 페이지 레이아웃

/// PDF 표지.
private struct NoteCoverPage: View {
    let noteCount: Int
    let exportedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 200)

            Text("QuoteDay 노트")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(Color(hex: 0x2E3350))

            Text("명언 \(noteCount)편에 남긴 생각")
                .font(.system(size: 18, design: .serif))
                .foregroundStyle(Color(hex: 0x6E7595))

            Rectangle()
                .fill(Color(hex: 0x5A64D8))
                .frame(width: 72, height: 3)
                .padding(.top, 8)

            Spacer()

            Text(Formatters.fullDate.string(from: exportedAt) + " 내보냄")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(Color(hex: 0x9AA1B8))
        }
        .padding(64)
        .frame(width: NotePDFExporter.pageWidth, height: NotePDFExporter.pageHeight, alignment: .topLeading)
        .background(Color.white)
    }
}

/// 노트 한 편.
private struct NotePDFPage: View {
    let note: QuoteNote
    let pageNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\u{201C}\(note.quoteTextSnapshot)\u{201D}")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: 0x2E3350))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(note.authorNameSnapshot)")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Color(hex: 0x6E7595))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xF3F4F8))

            Text(note.text)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(Color(hex: 0x2E3350))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 24)

            HStack {
                Text(Formatters.shortDateTime.string(from: note.updatedAt))
                Spacer()
                Text("\(pageNumber)")
            }
            .font(.system(size: 11, design: .serif))
            .foregroundStyle(Color(hex: 0x9AA1B8))
        }
        .padding(56)
        .frame(width: NotePDFExporter.pageWidth, minHeight: NotePDFExporter.pageHeight, alignment: .topLeading)
        .background(Color.white)
    }
}
