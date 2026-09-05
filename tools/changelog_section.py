#!/usr/bin/env python3
"""CHANGELOG.md 에서 특정 버전의 절을 뽑아 낸다.

릴리스 노트를 두 곳에 적으면 반드시 어긋난다(버전 번호로 이미 겪었다).
CHANGELOG 를 유일한 출처로 두고, 릴리스 워크플로는 여기서 읽기만 한다.

    python tools/changelog_section.py 1.3        # 본문을 stdout 으로
    python tools/changelog_section.py 1.3 --check  # 있는지만 확인

해당 버전의 절이 없으면 종료 코드 1 로 끝난다.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"


def section(version: str, text: str) -> str | None:
    """`## [1.3] - 2026-09-05` 부터 다음 `## [` 직전까지."""
    # 버전 번호에 정규식 특수문자(.)가 있으므로 이스케이프한다.
    pattern = re.compile(
        rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)",
        re.S | re.M,
    )
    found = pattern.search(text)
    if found is None:
        return None
    body = found.group(1).strip()
    return body or None


def main() -> int:
    parser = argparse.ArgumentParser(description="CHANGELOG 에서 버전 절을 뽑는다.")
    parser.add_argument("version", help="예: 1.3")
    parser.add_argument(
        "--check",
        action="store_true",
        help="본문을 출력하지 않고 존재 여부만 확인한다.",
    )
    args = parser.parse_args()

    if not CHANGELOG.exists():
        print("CHANGELOG.md 가 없습니다.", file=sys.stderr)
        return 1

    body = section(args.version, CHANGELOG.read_text(encoding="utf-8"))
    if body is None:
        print(
            f"CHANGELOG.md 에 [{args.version}] 절이 없습니다. "
            "[미출시] 를 버전 번호로 바꾸었는지 확인하세요.",
            file=sys.stderr,
        )
        return 1

    if not args.check:
        print(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
