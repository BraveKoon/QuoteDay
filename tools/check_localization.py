#!/usr/bin/env python3
"""번역 사전(`.strings`)이 빠짐없이 채워져 있는지 검사한다.

Xcode 없이도 돌릴 수 있어서, 번역을 더하거나 화면 문구를 고친 뒤 바로 확인할 수 있다.

    python tools/check_localization.py          # 검사
    python tools/check_localization.py --todo   # 빠진 키를 .strings 형식으로 출력

검사하는 것

1. 소스에 있는 한국어 문구가 `en.lproj` / `zh-Hans.lproj` / `zh-Hant.lproj` 에 모두 있는지
2. 언어별 키 집합이 같은지 (한쪽만 지우는 실수를 막는다)
3. 자리표시자(`%@`, `%d` …)의 개수가 언어마다 같은지
4. 명언·인물·비하인드 스토리 데이터가 언어별로 채워져 있는지
5. 쓰이지 않는 키가 남아 있는지 (오타로 생긴 유령 키를 잡는다)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCE_ROOT = ROOT / "App" / "Resources"
# 번역이 있어야 하는 언어. 첫 번째가 기준(base)이다 — 키 집합과 쓰이지 않는 키는
# 이 언어를 기준으로 본다. zh-Hant 는 zh-Hans 를 변환해 만들므로 세 언어의 키가
# 모두 같아야 한다.
LANGUAGES = ["en", "zh-Hans", "zh-Hant"]

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# 번역하지 않는 파일들:
# - 데이터 원본(명언·인물·스토리·릴리스 노트)은 별도 항목으로 따로 검사한다.
# - 외국 인물 표기 사전은 이름 데이터라 UI 문구가 아니다.
DATA_FILES = {
    "Shared/Data/QuoteLibraryData.swift",
    "Shared/Data/AuthorLibrary.swift",
    "Shared/Data/BehindStoryLibrary.swift",
    "Shared/Data/ReleaseHistory.swift",
    "Shared/Data/ForeignNameLibrary.swift",
    "Shared/Data/MoodLibrary.swift",
}

# 문자열 리터럴 하나. (보간 `\\(...)` 이 섞인 것은 별도로 다룬다)
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
HANGUL = re.compile("[가-힣]")

# SwiftUI 가 스스로 번역해 주는 자리들 + 우리가 직접 찾는 `L(...)`.
# 여기에 걸리는 리터럴만 "번역해야 하는 문구"로 본다.
AUTO_CALLS = (
    "Text", "Label", "Button", "Toggle", "Picker", "TextField", "SecureField",
    "Stepper", "Link", "Menu", "Section", "navigationTitle", "navigationBarTitle",
    "alert", "confirmationDialog", "accessibilityLabel", "accessibilityHint",
    "accessibilityValue", "searchable", "ContentUnavailableView", "ShareLink",
    "progressView", "badge",
)

SKIP_MARKERS = (
    "AppLog.", "Logger(", "privacy:", "assert(", "XCTAssert", "NSLocalizedString",
    "#Preview", "fatalError", "precondition",
)

PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|u|f|\.\d+f|\.\d+lf)")


def unescape_swift(body: str) -> str:
    """Swift 리터럴 본문을 실제 문자로 바꾼다. (`\\(` 보간은 호출부에서 걸러진다)"""
    out: list[str] = []
    index = 0
    while index < len(body):
        char = body[index]
        if char != "\\":
            out.append(char)
            index += 1
            continue
        index += 1
        if index >= len(body):
            break
        escape = body[index]
        if escape == "n":
            out.append("\n")
        elif escape == "t":
            out.append("\t")
        elif escape == '"':
            out.append('"')
        elif escape == "'":
            out.append("'")
        elif escape == "\\":
            out.append("\\")
        elif escape == "u" and index + 1 < len(body) and body[index + 1] == "{":
            end = body.find("}", index)
            if end == -1:
                out.append(escape)
            else:
                try:
                    out.append(chr(int(body[index + 2:end], 16)))
                except ValueError:
                    out.append(escape)
                index = end
        else:
            out.append(escape)
        index += 1
    return "".join(out)


def parse_strings(path: Path) -> dict[str, str]:
    """.strings 파일을 읽는다. (따옴표로 감싼 `키 = 값;` 만 쓴다)"""
    text = path.read_text(encoding="utf-8")
    entries: dict[str, str] = {}
    index = 0
    length = len(text)

    def read_quoted(start: int) -> tuple[str, int]:
        assert text[start] == '"'
        cursor = start + 1
        buffer: list[str] = []
        while cursor < length:
            char = text[cursor]
            if char == "\\":
                buffer.append(text[cursor:cursor + 2])
                cursor += 2
                continue
            if char == '"':
                return unescape_swift("".join(buffer)), cursor + 1
            buffer.append(char)
            cursor += 1
        raise ValueError(f"{path}: 닫히지 않은 따옴표")

    while index < length:
        if text[index] in " \t\r\n":
            index += 1
            continue
        if text.startswith("//", index):
            end = text.find("\n", index)
            index = length if end == -1 else end + 1
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index)
            index = length if end == -1 else end + 2
            continue
        if text[index] != '"':
            # 키가 아닌 줄(`/* ... */` 안의 주석 등)은 건너뛴다.
            index += 1
            continue
        key, index = read_quoted(index)
        while index < length and text[index] in " \t\r\n":
            index += 1
        if index < length and text[index] == "=":
            index += 1
            while index < length and text[index] in " \t\r\n":
                index += 1
            if index < length and text[index] == '"':
                value, index = read_quoted(index)
            else:
                end = text.find(";", index)
                value = text[index:end].strip()
                index = length if end == -1 else end
            while index < length and text[index] in " \t\r\n":
                index += 1
            if index < length and text[index] == ";":
                index += 1
            if key in entries:
                raise ValueError(f"{path}: 키가 중복되었습니다 → {key!r}")
            entries[key] = value
    return entries


def line_of(text: str, position: int) -> str:
    start = text.rfind("\n", 0, position) + 1
    end = text.find("\n", position)
    return text[start:length_end(text, end)]


def length_end(text: str, index: int) -> int:
    return len(text) if index == -1 else index


def call_before(text: str, position: int) -> str:
    """리터럴을 감싸고 있는 호출의 이름. (`Text(`, `L(` …) 없으면 빈 문자열.

    여러 줄에 걸친 호출도 찾는다. 실제로 이렇게 쓰는 자리가 많다.

        text = L(
            "%@ %d월 %d일",
            frequency.title, ...
        )

    한 줄만 보면 `L` 을 놓쳐서, 번역이 멀쩡히 있는 문구를 "쓰이지 않는 키"로
    잘못 보고하게 된다.
    """
    start = text.rfind("\n", 0, position) + 1
    prefix = text[start:position].rstrip()
    match = re.search(r"([A-Za-z_][A-Za-z0-9_.]*)\s*\(\s*$", prefix)
    if match:
        return match.group(1).split(".")[-1]

    # 괄호를 거슬러 올라가 짝이 맞는 여는 괄호를 찾는다.
    depth = 0
    index = position - 1
    limit = max(0, position - 400)
    while index >= limit:
        char = text[index]
        if char == ")":
            depth += 1
        elif char == "(":
            if depth == 0:
                head = text[max(0, index - 40):index]
                found = re.search(r"([A-Za-z_][A-Za-z0-9_.]*)\s*$", head)
                return found.group(1).split(".")[-1] if found else ""
            depth -= 1
        elif char in ";}":
            return ""
        index -= 1
    return ""


# 이름 붙은 인자로 넘기는 문구도 번역 대상이다.
# (예: `EmptyStateView(title: "오늘은 등록된 일정이 없어요")`,
#  `card(title: "설정")`, `ComingSoonCard(title: "비하인드 스토리")`)
NAMED_ARG = re.compile(
    r"(title|subtitle|message|label|actionTitle|text|placeholder|hint|reason|body)\s*:\s*$"
)


def is_named_argument(text: str, position: int) -> bool:
    start = text.rfind("\n", 0, position) + 1
    return bool(NAMED_ARG.search(text[start:position].rstrip()))


def scan_sources() -> dict[str, set[str]]:
    """번역이 필요한 문구 → 쓰인 파일."""
    found: dict[str, set[str]] = {}

    for path in sorted(ROOT.rglob("*.swift")):
        relative = path.relative_to(ROOT).as_posix()
        if relative.startswith(("Tests/", "tools/")):
            continue
        if relative in DATA_FILES:
            continue
        text = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(text):
            body = match.group(1)
            if "\\(" in body:
                continue
            line = line_of(text, match.start())
            stripped = line.strip()
            if stripped.startswith(("//", "///", "*")):
                continue
            if any(marker in line for marker in SKIP_MARKERS):
                continue
            callee = call_before(text, match.start())
            if callee not in AUTO_CALLS and callee != "L" and not is_named_argument(text, match.start()):
                continue
            # `L(...)` 에 넘긴 문자열은 한국어가 아니어도 번역 키다.
            # (`L("%@ %@", "매주", "화요일")` 처럼 언어별 어순을 담는 자리)
            if callee != "L" and not HANGUL.search(body):
                continue
            key = unescape_swift(body)
            found.setdefault(key, set()).add(relative)
    return found


def scan_all_text() -> set[str]:
    """소스에 등장하는 모든 한국어 문자열.

    "쓰이지 않는 키" 를 셀 때만 쓴다. 우리가 직접 만든 도우미 함수
    (`recordLine("최고 점수", …)`)에 넘기는 문구는 호출 이름으로 찾아낼 수 없어서,
    이 목록이 없으면 멀쩡히 쓰이는 키가 유령 키로 보고된다.
    반대로 이 목록에 없는 키는 정말로 아무 데서도 쓰이지 않는다.
    """
    found: set[str] = set()
    for path in sorted(ROOT.rglob("*.swift")):
        relative = path.relative_to(ROOT).as_posix()
        if relative.startswith(("Tests/", "tools/")):
            continue
        if relative in DATA_FILES:
            continue
        text = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(text):
            body = match.group(1)
            if "\\(" in body or not HANGUL.search(body):
                continue
            line = line_of(text, match.start())
            if line.strip().startswith(("//", "///", "*")):
                continue
            if any(marker in line for marker in SKIP_MARKERS):
                continue
            found.add(unescape_swift(body))
    return found


def quote_slugs() -> list[str]:
    text = (ROOT / "Shared/Data/QuoteLibraryData.swift").read_text(encoding="utf-8")
    return re.findall(r'slug:\s*"([^"]+)"', text)


def author_entries() -> list[dict[str, object]]:
    """AuthorLibrary 에서 id·업적 개수·era·저서 개수를 뽑는다."""
    text = (ROOT / "Shared/Data/AuthorLibrary.swift").read_text(encoding="utf-8")
    entries = []
    for block in text.split("        Author(")[1:]:
        identifier = re.search(r'id:\s*"([^"]+)"', block)
        if not identifier:
            continue
        achievements = re.search(r"achievements:\s*\[(.*?)\]", block, re.S)
        works = re.search(r"notableWorks:\s*\[(.*?)\]", block, re.S)
        entries.append({
            "id": identifier.group(1),
            "achievements": len(re.findall(r'"[^"]*"', achievements.group(1))) if achievements else 0,
            "works": len(re.findall(r'"[^"]*"', works.group(1))) if works else 0,
            "era": bool(re.search(r"era:\s*\"", block)),
        })
    return entries


def story_slugs() -> list[str]:
    text = (ROOT / "Shared/Data/BehindStoryLibrary.swift").read_text(encoding="utf-8")
    return re.findall(r'quoteSlug:\s*"([^"]+)"', text)


def main() -> int:
    errors: list[str] = []

    tables: dict[str, dict[str, str]] = {}
    for language in LANGUAGES:
        path = RESOURCE_ROOT / f"{language}.lproj" / "Localizable.strings"
        if not path.exists():
            errors.append(f"번역 파일이 없습니다: {path.relative_to(ROOT)}")
            tables[language] = {}
            continue
        try:
            tables[language] = parse_strings(path)
        except ValueError as error:
            errors.append(str(error))
            tables[language] = {}

    # 1. 소스 문구 — 화면 문구는 하나도 빠지면 안 된다.
    sources = scan_sources()
    required = set(sources)

    # 2. 명언 본문 — 이것도 빠지면 안 된다.
    for slug in quote_slugs():
        required.add(f"quote.{slug}.text")

    # 3. 인물·비하인드 스토리
    #
    # 카드에 바로 보이는 이름·직업·국적은 필수다. 소개글·업적·저서·배경 설명은
    # 분량이 커서 **덮어 가며** 채운다. 빠진 항목은 한국어 원문으로 자연스럽게
    # 되돌아가므로 화면이 비거나 키가 드러나지 않는다.
    optional: set[str] = set()
    for author in author_entries():
        identifier = author["id"]
        for field in ("name", "occupation", "nationality"):
            required.add(f"author.{identifier}.{field}")
        optional.add(f"author.{identifier}.biography")
        if author["era"]:
            optional.add(f"author.{identifier}.era")
        for index in range(int(author["achievements"])):
            optional.add(f"author.{identifier}.achievement.{index}")
        for index in range(int(author["works"])):
            optional.add(f"author.{identifier}.work.{index}")
    for slug in story_slugs():
        for field in ("occasion", "context", "takeaway"):
            optional.add(f"story.{slug}.{field}")

    for language in LANGUAGES:
        table = tables[language]
        missing = sorted(key for key in required if key not in table)
        if missing:
            errors.append(f"[{language}] 번역이 없는 문구 {len(missing)}개")
            if "--todo" in sys.argv:
                for key in missing:
                    print(f'"{key}" = "";')
        # 자리표시자 개수
        for key in sorted(required & set(table)):
            expected = len(PLACEHOLDER.findall(key))
            actual = len(PLACEHOLDER.findall(table[key]))
            if expected and expected != actual:
                errors.append(f"[{language}] 자리표시자 개수가 다릅니다: {key!r} ({expected} ≠ {actual})")
        empty = sorted(key for key in required & set(table) if not table[key].strip())
        if empty:
            errors.append(f"[{language}] 값이 비어 있는 문구 {len(empty)}개: {empty[:3]}")

    # 키 집합은 모든 언어에서 같아야 한다.
    base_language = LANGUAGES[0]
    base_keys = set(tables[base_language])
    for language in LANGUAGES[1:]:
        keys = set(tables[language])
        for key in sorted(base_keys ^ keys):
            owner = base_language if key in base_keys else language
            errors.append(f"[{owner}] 에만 있는 키: {key!r}")

    # 4. 쓰이지 않는 키 — 오타로 생긴 유령 키를 잡는다. (실패는 아니다)
    unused = sorted(base_keys - required - optional - scan_all_text())
    if unused:
        print(f"참고: 쓰이지 않는 키 {len(unused)}개 — {unused[:6]}")

    # 5. 덮어 가며 채우는 항목의 진행률
    coverage: list[str] = []
    for language in LANGUAGES:
        done = len(optional & set(tables[language]))
        coverage.append(f"{language} {done}/{len(optional)}")

    if errors:
        print("번역 검사 실패")
        for error in errors:
            print(" -", error)
        for language in LANGUAGES:
            missing = [key for key in required if key not in tables[language]]
            if missing:
                sample = ", ".join(repr(key) for key in sorted(missing)[:6])
                print(f"   [{language}] 예: {sample}")
        return 1

    print(f"번역 검사 통과 — 필수 문구 {len(required)}개 × {len(LANGUAGES)}개 언어")
    print("   소개글·업적·배경 설명: " + " · ".join(coverage))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
