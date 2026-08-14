#!/usr/bin/env python3
"""Xcode 없이 프로젝트를 정적으로 검증한다.

macOS 에서 실제로 컴파일하기 전에 걸러 낼 수 있는 문제를 확인한다.

1. project.pbxproj 를 직접 파싱해 구조와 상호 참조가 온전한지
2. 파일 참조가 실제로 디스크에 존재하는지
3. 모든 Swift 파일이 적어도 하나의 타겟에 들어가 있는지
4. Swift 소스의 괄호/따옴표 균형
5. 타겟 경계 위반 — 위젯이 앱 전용 타입을 참조하는지 (모듈이 다르므로 컴파일 오류가 된다)

    python tools/check_project.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "QuoteDay.xcodeproj" / "project.pbxproj"

# Windows 콘솔(cp949)에서도 한글/기호가 깨지지 않도록.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

TARGET_ROOTS = {
    "QuoteDay": ["App", "Shared"],
    "QuoteDayWidgetExtension": ["Widget", "Shared"],
    "QuoteDayTests": ["Tests"],
}

errors: list[str] = []
warnings: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def warn(message: str) -> None:
    warnings.append(message)


# --------------------------------------------------------------------------
# 1. pbxproj 파서 (생성기가 쓰는 OpenStep plist 부분집합)
# --------------------------------------------------------------------------

TOKEN_RE = re.compile(r'"(?:[^"\\]|\\.)*"|[A-Za-z0-9_./$@<>+-]+|[{}();,=]')


def strip_comments(text: str) -> str:
    out = []
    index = 0
    length = len(text)
    while index < length:
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            index = length if end == -1 else end + 2
            out.append(" ")
        elif text[index] == '"':
            end = index + 1
            while end < length:
                if text[end] == "\\":
                    end += 2
                    continue
                if text[end] == '"':
                    break
                end += 1
            out.append(text[index:end + 1])
            index = end + 1
        else:
            out.append(text[index])
            index += 1
    return "".join(out)


class Parser:
    def __init__(self, tokens: list[str]) -> None:
        self.tokens = tokens
        self.pos = 0

    def peek(self) -> str | None:
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def next(self) -> str:
        token = self.tokens[self.pos]
        self.pos += 1
        return token

    def expect(self, token: str) -> None:
        actual = self.next()
        if actual != token:
            raise ValueError(f"'{token}' 를 기대했지만 '{actual}' 를 만났습니다 (토큰 {self.pos}).")

    def parse_value(self):
        token = self.peek()
        if token == "{":
            return self.parse_dict()
        if token == "(":
            return self.parse_array()
        value = self.next()
        if value.startswith('"') and value.endswith('"'):
            return value[1:-1]
        return value

    def parse_dict(self) -> dict:
        self.expect("{")
        result: dict[str, object] = {}
        while True:
            token = self.peek()
            if token is None:
                raise ValueError("딕셔너리가 닫히지 않았습니다.")
            if token == "}":
                self.next()
                return result
            key = self.next()
            if key.startswith('"'):
                key = key[1:-1]
            self.expect("=")
            result[key] = self.parse_value()
            if self.peek() == ";":
                self.next()

    def parse_array(self) -> list:
        self.expect("(")
        result: list[object] = []
        while True:
            token = self.peek()
            if token is None:
                raise ValueError("배열이 닫히지 않았습니다.")
            if token == ")":
                self.next()
                return result
            result.append(self.parse_value())
            if self.peek() == ",":
                self.next()


def check_pbxproj() -> dict | None:
    if not PBXPROJ.exists():
        fail(f"{PBXPROJ.relative_to(ROOT)} 가 없습니다. tools/generate_xcodeproj.py 를 먼저 실행하세요.")
        return None

    raw = PBXPROJ.read_text(encoding="utf-8")
    if not raw.startswith("// !$*UTF8*$!"):
        fail("pbxproj 첫 줄의 UTF-8 마커가 없습니다.")

    body = strip_comments(raw)
    body = body[body.index("{"):]
    tokens = TOKEN_RE.findall(body)

    try:
        root = Parser(tokens).parse_dict()
    except ValueError as error:
        fail(f"pbxproj 파싱 실패: {error}")
        return None

    objects = root.get("objects")
    if not isinstance(objects, dict):
        fail("objects 섹션을 찾을 수 없습니다.")
        return None

    print(f"  pbxproj 파싱 성공 - 객체 {len(objects)}개")

    # 상호 참조 확인
    id_pattern = re.compile(r"^[0-9A-F]{24}$")
    referenced: set[str] = set()

    def walk(value) -> None:
        if isinstance(value, dict):
            for key, item in value.items():
                if key != "isa":
                    walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)
        elif isinstance(value, str) and id_pattern.match(value):
            referenced.add(value)

    walk(objects)
    walk(root.get("rootObject", ""))

    missing = sorted(referenced - set(objects))
    for obj_id in missing:
        fail(f"정의되지 않은 객체를 참조합니다: {obj_id}")

    orphans = sorted(set(objects) - referenced - {root.get("rootObject")})
    for obj_id in orphans:
        warn(f"어디에서도 참조되지 않는 객체: {obj_id} ({objects[obj_id].get('isa')})")

    root_object = root.get("rootObject")
    if root_object not in objects:
        fail("rootObject 가 objects 에 없습니다.")
    elif objects[root_object].get("isa") != "PBXProject":
        fail("rootObject 가 PBXProject 가 아닙니다.")

    # 필수 섹션
    counts: dict[str, int] = {}
    for obj in objects.values():
        isa = obj.get("isa", "?")
        counts[isa] = counts.get(isa, 0) + 1
    for required in ("PBXNativeTarget", "PBXSourcesBuildPhase", "PBXFileReference", "PBXGroup"):
        if counts.get(required, 0) == 0:
            fail(f"{required} 섹션이 비어 있습니다.")

    targets = {
        obj["name"]: obj
        for obj in objects.values()
        if obj.get("isa") == "PBXNativeTarget"
    }
    for name in TARGET_ROOTS:
        if name not in targets:
            fail(f"타겟이 없습니다: {name}")

    # 타겟별 소스 파일 목록 재구성
    file_paths = resolve_group_paths(objects)
    target_files: dict[str, set[str]] = {}

    for name, target in targets.items():
        phases = target.get("buildPhases", [])
        source_phase = next(
            (objects[p] for p in phases if objects.get(p, {}).get("isa") == "PBXSourcesBuildPhase"),
            None,
        )
        if source_phase is None:
            fail(f"{name} 에 Sources 빌드 페이즈가 없습니다.")
            continue

        files = set()
        for build_file_id in source_phase.get("files", []):
            build_file = objects.get(build_file_id, {})
            ref = build_file.get("fileRef")
            path = file_paths.get(ref)
            if path is None:
                fail(f"{name} 의 빌드 파일이 알 수 없는 파일을 가리킵니다: {ref}")
                continue
            files.add(path)
        target_files[name] = files
        if not files:
            fail(f"{name} 의 소스가 비어 있습니다.")

        config_list = target.get("buildConfigurationList")
        if config_list not in objects:
            fail(f"{name} 의 빌드 구성 목록이 없습니다.")

    # 디스크 존재 확인
    for ref_id, path in file_paths.items():
        if not (ROOT / path).exists():
            fail(f"파일 참조가 실제 파일과 맞지 않습니다: {path}")

    # 기대한 소스 집합과 비교
    for name, roots in TARGET_ROOTS.items():
        expected = set()
        for root_dir in roots:
            expected.update(
                p.relative_to(ROOT).as_posix()
                for p in (ROOT / root_dir).rglob("*.swift")
            )
        actual = target_files.get(name, set())
        for path in sorted(expected - actual):
            fail(f"{name} 타겟에 포함되지 않은 Swift 파일: {path}")
        for path in sorted(actual - expected):
            fail(f"{name} 타겟에 예상 밖의 파일이 있습니다: {path}")

    return objects


def resolve_group_paths(objects: dict) -> dict[str, str]:
    """PBXGroup 트리를 따라 각 PBXFileReference 의 프로젝트 상대 경로를 만든다."""
    project = next(obj for obj in objects.values() if obj.get("isa") == "PBXProject")
    main_group = project["mainGroup"]

    paths: dict[str, str] = {}

    def walk(group_id: str, prefix: str) -> None:
        group = objects.get(group_id)
        if group is None:
            return
        own = group.get("path", "")
        current = f"{prefix}/{own}" if prefix and own else (own or prefix)
        for child_id in group.get("children", []):
            child = objects.get(child_id)
            if child is None:
                fail(f"그룹이 존재하지 않는 자식을 참조합니다: {child_id}")
                continue
            if child.get("isa") == "PBXGroup":
                walk(child_id, current)
            elif child.get("isa") == "PBXFileReference":
                if child.get("sourceTree") == "BUILT_PRODUCTS_DIR":
                    continue
                name = child.get("path", "")
                paths[child_id] = f"{current}/{name}" if current else name

    walk(main_group, "")
    return paths


# --------------------------------------------------------------------------
# 2. Swift 소스 정적 점검
# --------------------------------------------------------------------------

DECL_RE = re.compile(
    r"^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|final\s+|@\w+\s+)*"
    r"(struct|class|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)


def strip_swift_noise(source: str) -> str:
    """문자열 리터럴과 주석을 공백으로 바꾼다 (괄호 세기 위함)."""
    out = []
    index = 0
    length = len(source)
    depth = 0
    while index < length:
        char = source[index]
        if source.startswith("//", index):
            end = source.find("\n", index)
            index = length if end == -1 else end
        elif source.startswith("/*", index):
            depth = 1
            index += 2
            while index < length and depth:
                if source.startswith("/*", index):
                    depth += 1
                    index += 2
                elif source.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
        elif source.startswith('"""', index):
            end = source.find('"""', index + 3)
            index = length if end == -1 else end + 3
            out.append(" ")
        elif char == '"':
            index += 1
            while index < length:
                if source[index] == "\\":
                    index += 2
                    continue
                if source[index] == '"':
                    index += 1
                    break
                index += 1
            out.append(" ")
        else:
            out.append(char)
            index += 1
    return "".join(out)


def check_swift_sources() -> None:
    declarations: dict[str, set[str]] = {}
    all_files = 0

    for root_dir in ("App", "Shared", "Widget", "Tests"):
        names: set[str] = set()
        for path in sorted((ROOT / root_dir).rglob("*.swift")):
            all_files += 1
            source = path.read_text(encoding="utf-8")
            relative = path.relative_to(ROOT).as_posix()

            cleaned = strip_swift_noise(source)
            for opener, closer, label in (("{", "}", "중괄호"), ("(", ")", "괄호"), ("[", "]", "대괄호")):
                if cleaned.count(opener) != cleaned.count(closer):
                    fail(
                        f"{relative}: {label} 개수가 맞지 않습니다 "
                        f"({cleaned.count(opener)} vs {cleaned.count(closer)})."
                    )

            if "\r\n" in source:
                warn(f"{relative}: CRLF 줄바꿈이 포함되어 있습니다.")

            for _, name in DECL_RE.findall(source):
                names.add(name)
        declarations[root_dir] = names

    print(f"  Swift 파일 {all_files}개 점검")

    # 위젯은 App 모듈을 볼 수 없다.
    app_only = declarations["App"] - declarations["Shared"] - declarations["Widget"]
    widget_source = "\n".join(
        strip_swift_noise(path.read_text(encoding="utf-8"))
        for path in (ROOT / "Widget").rglob("*.swift")
    )
    for name in sorted(app_only):
        if re.search(rf"\b{re.escape(name)}\b", widget_source):
            fail(f"위젯 타겟이 앱 전용 타입 '{name}' 을 참조합니다. Shared 로 옮겨야 합니다.")

    # Shared 는 App 전용 타입에 의존하면 안 된다.
    shared_source = "\n".join(
        strip_swift_noise(path.read_text(encoding="utf-8"))
        for path in (ROOT / "Shared").rglob("*.swift")
    )
    for name in sorted(app_only):
        if re.search(rf"\b{re.escape(name)}\b", shared_source):
            fail(f"Shared 코드가 앱 전용 타입 '{name}' 을 참조합니다.")

    # 위젯 번들 진입점은 정확히 하나여야 한다.
    main_count = len(re.findall(r"^@main", widget_source, re.MULTILINE))
    if main_count != 1:
        fail(f"위젯 타겟의 @main 이 {main_count}개입니다. 정확히 1개여야 합니다.")

    app_source = "\n".join(
        strip_swift_noise(path.read_text(encoding="utf-8"))
        for path in (ROOT / "App").rglob("*.swift")
    )
    app_main = len(re.findall(r"^@main", app_source, re.MULTILINE))
    if app_main != 1:
        fail(f"앱 타겟의 @main 이 {app_main}개입니다. 정확히 1개여야 합니다.")


# --------------------------------------------------------------------------
# 3. 리소스 점검
# --------------------------------------------------------------------------

def check_resources() -> None:
    required = [
        "App/Resources/Info.plist",
        "App/Resources/QuoteDay.entitlements",
        "App/Resources/Assets.xcassets/Contents.json",
        "App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
        "App/Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
        "Widget/Info.plist",
        "Widget/QuoteDayWidget.entitlements",
        "Widget/Assets.xcassets/Contents.json",
    ]
    for path in required:
        if not (ROOT / path).exists():
            fail(f"필수 리소스가 없습니다: {path}")

    app_group = "group.com.quoteday.app"
    for entitlement in ("App/Resources/QuoteDay.entitlements", "Widget/QuoteDayWidget.entitlements"):
        text = (ROOT / entitlement).read_text(encoding="utf-8")
        if app_group not in text:
            fail(f"{entitlement} 에 App Group 이 없습니다.")

    shared_store = (ROOT / "Shared/Services/SharedStore.swift").read_text(encoding="utf-8")
    if app_group not in shared_store:
        fail("SharedStore.swift 의 App Group 식별자가 entitlements 와 다릅니다.")

    info = (ROOT / "App/Resources/Info.plist").read_text(encoding="utf-8")
    if "quoteday" not in info:
        fail("Info.plist 에 quoteday URL 스킴이 없습니다.")
    if "NSCalendarsFullAccessUsageDescription" not in info:
        fail("Info.plist 에 캘린더 권한 설명이 없습니다.")

    widget_info = (ROOT / "Widget/Info.plist").read_text(encoding="utf-8")
    if "com.apple.widgetkit-extension" not in widget_info:
        fail("위젯 Info.plist 의 확장 포인트가 잘못되었습니다.")

    check_app_icon()


def check_app_icon() -> None:
    """앱 아이콘이 iOS 요구사항(1024x1024, 알파 없는 PNG)을 만족하는지."""
    import json
    import struct

    iconset = ROOT / "App/Resources/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((iconset / "Contents.json").read_text(encoding="utf-8"))
    images = contents.get("images", [])
    filenames = [entry["filename"] for entry in images if entry.get("filename")]

    if not filenames:
        warn("앱 아이콘 이미지가 없습니다. 홈 화면에 빈 아이콘으로 표시됩니다.")
        return

    for filename in filenames:
        path = iconset / filename
        if not path.exists():
            fail(f"Contents.json 이 없는 아이콘 파일을 가리킵니다: {filename}")
            continue

        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            fail(f"{filename} 이 PNG 가 아닙니다.")
            continue

        width, height, _, color_type = struct.unpack(">IIBB", data[16:26])
        if (width, height) != (1024, 1024):
            fail(f"{filename} 크기가 {width}x{height} 입니다. 1024x1024 여야 합니다.")
        # 컬러타입 4(Gray+A) / 6(RGBA) 는 알파 채널을 포함한다.
        # App Store Connect 는 알파가 있는 앱 아이콘을 거부한다.
        if color_type in (4, 6):
            fail(f"{filename} 에 알파 채널이 있습니다. 알파 없는 PNG 로 저장해야 합니다.")

    print(f"  앱 아이콘 {len(filenames)}개 점검")


# --------------------------------------------------------------------------
# 4. 명언 데이터 정합성
# --------------------------------------------------------------------------

CATEGORY_CASES = [
    "work", "leisure", "meal", "study",
    "exercise", "health", "relationship", "growth", "daily", "etc",
]
MIN_QUOTES = 100
MIN_PER_CATEGORY = 6


def check_quote_data() -> None:
    data = (ROOT / "Shared/Data/QuoteLibraryData.swift").read_text(encoding="utf-8")
    authors_src = (ROOT / "Shared/Data/AuthorLibrary.swift").read_text(encoding="utf-8")

    entries = re.findall(
        r'Quote\(slug: "([^"]+)",\s*\n\s*text: "((?:[^"\\]|\\.)*)"'
        r'(?:,\s*\n\s*originalText: "(?:[^"\\]|\\.)*")?'
        r',\s*\n\s*authorID: "([^"]+)", category: \.(\w+)',
        data,
    )
    slugs = [slug for slug, _, _, _ in entries]
    declared = re.findall(r'Quote\(slug: "', data)

    if len(entries) != len(declared):
        fail(
            f"명언 {len(declared)}개 중 {len(entries)}개만 파싱되었습니다. "
            "데이터 형식이 예상과 다릅니다."
        )

    if len(slugs) < MIN_QUOTES:
        fail(f"명언이 {len(slugs)}개뿐입니다. 최소 {MIN_QUOTES}개가 필요합니다.")

    duplicates = {slug for slug in slugs if slugs.count(slug) > 1}
    for slug in sorted(duplicates):
        fail(f"slug 가 중복되었습니다: {slug}")

    author_ids = set(re.findall(r'Author\(\s*\n?\s*id: "([^"]+)"', authors_src))
    if not author_ids:
        fail("AuthorLibrary 에서 인물을 하나도 찾지 못했습니다.")

    used_authors = set()
    per_category: dict[str, int] = {}
    for slug, text, author_id, category in entries:
        used_authors.add(author_id)
        if author_id not in author_ids:
            fail(f"{slug} 가 존재하지 않는 인물 '{author_id}' 를 참조합니다.")
        if category not in CATEGORY_CASES:
            fail(f"{slug} 의 카테고리 '{category}' 가 AppCategory 에 없습니다.")
        per_category[category] = per_category.get(category, 0) + 1
        if not text.strip():
            fail(f"{slug} 의 본문이 비어 있습니다.")

    # 보조 카테고리까지 합산해 폴백 없이도 충분한지 본다.
    for category in CATEGORY_CASES:
        if category == "etc":
            continue  # etc 는 의도적으로 폴백에 의존한다.
        count = per_category.get(category, 0)
        if count < MIN_PER_CATEGORY:
            fail(f"'{category}' 카테고리의 명언이 {count}개뿐입니다 (최소 {MIN_PER_CATEGORY}개).")

    for author_id in sorted(author_ids - used_authors):
        warn(f"명언이 하나도 없는 인물: {author_id}")

    print(f"  명언 {len(slugs)}편 / 인물 {len(author_ids)}명 점검")


def main() -> int:
    print("QuoteDay 정적 검증")
    print("-" * 46)
    check_pbxproj()
    check_swift_sources()
    check_resources()
    check_quote_data()

    print("-" * 46)
    for message in warnings:
        print(f"  경고: {message}")
    if errors:
        for message in errors:
            print(f"  오류: {message}")
        print(f"\n실패: 오류 {len(errors)}건")
        return 1
    print(f"통과 (경고 {len(warnings)}건)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
