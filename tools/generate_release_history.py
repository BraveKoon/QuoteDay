#!/usr/bin/env python3
"""CHANGELOG.md 에서 Shared/Data/ReleaseHistory.swift 를 만든다.

앱 정보 화면에 뜨는 버전과 깃허브 릴리스 태그가 어긋나지 않게 하려면
출처가 하나여야 한다. 그 하나가 CHANGELOG.md 다.

    CHANGELOG.md  ──generate_release_history.py──▶  ReleaseHistory.swift  (앱 화면)
          │
          └─ project.yml 의 MARKETING_VERSION ──▶ Info.plist ──▶ release.yml 이 v<버전> 태그

check_project.py 가 셋(CHANGELOG 최신 항목 · MARKETING_VERSION · 생성된 파일)이
같은지 확인하고, 다르면 CI 를 실패시킨다.

    python tools/generate_release_history.py          # 파일을 새로 쓴다
    python tools/generate_release_history.py --check   # 최신인지만 확인 (0/1)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
OUTPUT = ROOT / "Shared/Data/ReleaseHistory.swift"
REPO_URL = "https://github.com/BraveKoon/QuoteDay"

VERSION_HEADING = re.compile(r"^## \[([0-9]+(?:\.[0-9]+)*)\] - (\d{4}-\d{2}-\d{2})\s*$")
SECTION_HEADING = re.compile(r"^### (.+?)\s*$")
LINK = re.compile(r"\[([^\]]+)\]\([^)]+\)")


def plain(text: str) -> str:
    """마크다운 강조를 벗긴다.

    화면에서는 런타임 문자열의 마크다운이 그대로 렌더링되지 않는다.
    별표가 눈에 보이느니 처음부터 없는 편이 낫다.
    """
    text = LINK.sub(r"\1", text)
    text = text.replace("**", "").replace("`", "")
    return " ".join(text.split())


def parse(markdown: str) -> list[dict]:
    """버전별로 ### 절과 **최상위** 항목만 뽑는다.

    들여쓴 하위 항목과 코드 블록은 싣지 않는다. 변경 이력 화면은 전체 기록을
    한 번에 훑는 곳이라, 항목마다 근거까지 붙으면 아무도 끝까지 읽지 않는다.
    자세한 내용은 CHANGELOG.md 와 깃허브 릴리스에 있고 화면에서 링크로 잇는다.
    """
    releases: list[dict] = []
    current: dict | None = None
    section: dict | None = None
    bullet: list[str] | None = None
    # 하위 항목 안에 들어와 있는지. 하위 항목의 이어진 줄(4칸 들여쓰기)이
    # 최상위 항목에 달라붙지 않게 막는다.
    nested = False

    def flush_bullet() -> None:
        nonlocal bullet
        if bullet and section is not None:
            section["items"].append(plain(" ".join(bullet)))
        bullet = None

    def flush_section() -> None:
        nonlocal section
        flush_bullet()
        if section is not None and section["items"] and current is not None:
            current["sections"].append(section)
        section = None

    for raw in markdown.splitlines():
        heading = VERSION_HEADING.match(raw)
        if heading:
            flush_section()
            nested = False
            current = {
                "version": heading.group(1),
                "date": heading.group(2),
                "summary": "",
                "sections": [],
            }
            releases.append(current)
            continue
        if current is None:
            continue

        heading = SECTION_HEADING.match(raw)
        if heading:
            flush_section()
            nested = False
            section = {"title": plain(heading.group(1)), "items": []}
            continue

        if not raw.strip():
            flush_bullet()
            nested = False
            continue

        indent = len(raw) - len(raw.lstrip(" "))
        body = raw.strip()

        if indent == 0 and body.startswith("- "):
            flush_bullet()
            nested = False
            bullet = [body[2:]]
        elif indent > 0 and body.startswith("- "):
            flush_bullet()
            nested = True
        elif indent == 2 and not nested and bullet is not None:
            bullet.append(body)
        elif indent == 0 and section is None:
            # 첫 ### 앞의 한 줄 요약 ("첫 버전.")
            current["summary"] = plain(body)

    flush_section()
    return releases


def swift_string(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def render(releases: list[dict]) -> str:
    lines = [
        "// 이 파일은 자동 생성된다. 직접 고치지 말 것.",
        "//",
        "//     python tools/generate_release_history.py",
        "//",
        "// 원본은 CHANGELOG.md 다. 내용을 고치려면 그쪽을 고치고 다시 생성한다.",
        "",
        "import Foundation",
        "",
        "public extension ReleaseHistory {",
        "    /// 최신 버전이 앞에 온다.",
        "    static let all: [Release] = [",
    ]
    for release in releases:
        lines.append("        Release(")
        lines.append(f"            version: {swift_string(release['version'])},")
        lines.append(f"            date: {swift_string(release['date'])},")
        summary = swift_string(release["summary"]) if release["summary"] else "nil"
        lines.append(f"            summary: {summary},")
        lines.append("            sections: [")
        for section in release["sections"]:
            lines.append("                ReleaseSection(")
            lines.append(f"                    title: {swift_string(section['title'])},")
            lines.append("                    items: [")
            for item in section["items"]:
                lines.append(f"                        {swift_string(item)},")
            lines.append("                    ]")
            lines.append("                ),")
        lines.append("            ]")
        lines.append("        ),")
    lines.append("    ]")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def build() -> str:
    releases = parse(CHANGELOG.read_text(encoding="utf-8"))
    if not releases:
        raise SystemExit("CHANGELOG.md 에서 버전을 하나도 찾지 못했다.")
    return render(releases)


def main() -> int:
    generated = build()
    if "--check" in sys.argv:
        existing = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if existing != generated:
            print("ReleaseHistory.swift 가 CHANGELOG.md 와 어긋난다.")
            print("  python tools/generate_release_history.py 를 실행하고 커밋할 것.")
            return 1
        print("ReleaseHistory.swift 최신 상태")
        return 0
    OUTPUT.write_text(generated, encoding="utf-8")
    count = generated.count("        Release(")
    print(f"생성 완료: {OUTPUT.relative_to(ROOT)} - 릴리스 {count}개")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
