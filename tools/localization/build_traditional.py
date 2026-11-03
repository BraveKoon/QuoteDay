#!/usr/bin/env python3
"""간체 사전(`zh-Hans`)에서 번체 사전(`zh-Hant`)을 만든다.

대상은 세 종류다 — 화면 문구(`Localizable.strings`), 사진·캘린더 권한 안내처럼
시스템이 직접 띄우는 문구(`InfoPlist.strings`), 그리고 `docs/` 의 번역 문서
(개인정보 처리방침). 모두 간체가 원본이다.

번체를 따로 손으로 쓰지 않는 이유는, 같은 문장을 두 번 관리하면 반드시
어긋나기 때문이다. 간체 사전이 원본이고 번체는 **변환 결과**다. 문구를
고칠 때는 간체만 고치고 이 스크립트를 다시 돌린다.

    python tools/localization/build_traditional.py            # 파일을 새로 쓴다
    python tools/localization/build_traditional.py --check    # 최신인지만 확인 (0/1)

변환은 OpenCC 의 `s2twp`(간체 → 대만 정체 + 대만 어휘)를 쓴다.
`s2t` 가 아니라 `s2twp` 인 이유는 글자만 바꾸면 대만 사용자에게 어색한
낱말이 남기 때문이다 — 软件→軟體, 信息→資訊, 默认→預設 처럼 어휘까지
바뀌어야 읽힌다.

    pip install opencc-python-reimplemented

OpenCC 가 다룰 수 없는 몇 가지는 `OVERRIDES` 에서 직접 정한다.
(예: "명언" 은 대만에서도 名言 이 맞지만, 앱 이름에 쓰는 "오늘의 명언" 처럼
짧은 표제는 대만에서 더 흔한 표현으로 바꾸고 싶을 수 있다.)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
RESOURCES = ROOT / "App" / "Resources"
# 간체를 원본으로 삼아 번체를 만드는 `.strings` 파일 이름들.
TABLES = ["Localizable.strings", "InfoPlist.strings"]
# 통째로 변환하는 문서. (간체 → 번체) 머리말을 따로 붙이지 않는다 —
# 공개 문서에 작업 지시가 섞이면 안 된다. 어긋남은 `--check` 가 잡는다.
DOCUMENTS = [
    ("docs/PRIVACY.zh-Hans.md", "docs/PRIVACY.zh-Hant.md"),
]
# OpenCC 가 글자는 바꾸지만 대만 낱말로는 못 바꾸는 것들. **문서에만** 적용한다 —
# 앱 화면 사전(`Localizable.strings`)은 이미 `日程·日曆·應用` 으로 통일되어 있어서,
# 거기까지 고치면 앱 전체의 용어 결정이 되므로 이 보정표의 몫이 아니다.
DOCUMENT_FIXES = {
    "識別符號": "識別碼",
    "許可權": "權限",
    "跟蹤": "追蹤",
    "賬號": "帳號",
    "隱私政策": "隱私權政策",
    "退出登入": "登出",
    "推送": "推播",
    "應用": "App",
}

HEADER = """/* zh-Hant — QuoteDay */
/* zh-Hans 사전에서 자동으로 만든 파일이다. 직접 고치지 말 것. */
/* 고치는 곳: App/Resources/zh-Hans.lproj/{table}  */
/* 다시 만들기: python tools/localization/build_traditional.py  */
"""

# 간체 → 번체 변환 뒤에도 대만 관습과 어긋나는 문구.
# 키는 한국어 원문(= 사전 키)이 아니라 **간체 문구**다.
OVERRIDES = {
    "每一天": "每一天",
    "名言": "名言",
    "简体中文": "簡體中文",
}

PAIR = None  # 정규식은 아래에서 만든다.


def space_latin(text: str) -> str:
    """`App` 이 한자에 붙어 있으면 띄운다. (`刪除App後` → `刪除 App 後`)

    보정표가 `應用` 을 `App` 으로 바꾸면 앞뒤 글자와 붙는다. 같은 문서의
    `照片 App` 처럼 띄어 쓰는 것이 이 앱 문서의 표기다.
    """
    import re

    text = re.sub(r"(?<=[\u4e00-\u9fff])App", " App", text)
    return re.sub(r"App(?=[\u4e00-\u9fff])", "App ", text)


def build_converter():
    try:
        from opencc import OpenCC
    except ImportError:  # pragma: no cover - 환경 문제
        sys.exit(
            "OpenCC 가 필요합니다.\n"
            "    pip install opencc-python-reimplemented"
        )
    return OpenCC("s2twp")


def parse(path: Path) -> list[tuple[str, str]]:
    """`.strings` 를 (키, 값) 목록으로 읽는다. 주석과 빈 줄은 버린다."""
    import re

    global PAIR
    if PAIR is None:
        PAIR = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";$')
    entries: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = PAIR.match(line.strip())
        if match:
            entries.append((match.group(1), match.group(2)))
    return entries


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')


def render(table: str, entries: list[tuple[str, str]], convert) -> str:
    """섹션 주석은 원본 그대로 옮기고, 값만 변환한다."""
    source = RESOURCES / "zh-Hans.lproj" / table
    source_lines = source.read_text(encoding="utf-8").splitlines()
    pairs = dict(entries)
    out: list[str] = [HEADER.format(table=table)]
    for line in source_lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("/*") and stripped.endswith("*/"):
            # 원본 머리말(3줄)은 번체 머리말로 대신한다.
            if "zh-Hans — QuoteDay" in stripped:
                continue
            if stripped.startswith("/* 화면 문구는"):
                continue
            if stripped.startswith("/* 데이터 문구"):
                continue
            out.append("")
            out.append(stripped.replace("zh-Hans", "zh-Hant"))
            continue
        match = PAIR.match(stripped) if PAIR else None
        if not match:
            continue
        key = match.group(1)
        value = pairs.get(key)
        if value is None:  # pragma: no cover - 파싱 버그
            continue
        converted = OVERRIDES.get(value) or convert(value)
        out.append(f'"{key}" = "{escape(converted)}";')
    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="최신인지만 확인한다")
    args = parser.parse_args()

    convert = build_converter()
    stale = False

    for table in TABLES:
        source = RESOURCES / "zh-Hans.lproj" / table
        output = RESOURCES / "zh-Hant.lproj" / table
        if not source.exists():
            sys.exit(f"원본이 없습니다: {source}")

        entries = parse(source)
        if not entries:
            sys.exit(f"간체 사전에서 문구를 하나도 읽지 못했습니다: {table}")

        text = render(table, entries, convert.convert)

        if args.check:
            current = output.read_text(encoding="utf-8") if output.exists() else ""
            if current != text:
                print(f"번체 사전이 간체 사전과 어긋납니다: {table} — build_traditional.py 를 실행하세요.")
                stale = True
            else:
                print(f"번체 사전 최신 — {table} {len(entries)}개 문구")
            continue

        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text, encoding="utf-8")
        print(f"생성 완료: {output.relative_to(ROOT)} - 문구 {len(entries)}개")

    for source_name, output_name in DOCUMENTS:
        source = ROOT / source_name
        output = ROOT / output_name
        if not source.exists():
            sys.exit(f"원본이 없습니다: {source}")
        text = convert.convert(source.read_text(encoding="utf-8"))
        for wrong, right in DOCUMENT_FIXES.items():
            text = text.replace(wrong, right)
        text = space_latin(text)

        if args.check:
            current = output.read_text(encoding="utf-8") if output.exists() else ""
            if current != text:
                print(f"번체 문서가 간체 문서와 어긋납니다: {output_name} — build_traditional.py 를 실행하세요.")
                stale = True
            else:
                print(f"번체 문서 최신 — {output_name}")
            continue

        output.write_text(text, encoding="utf-8")
        print(f"생성 완료: {output_name}")

    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
