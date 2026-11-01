#!/usr/bin/env python3
"""App Store Connect API 키(.p8)를 러너에 풀어 놓는다.

깃허브 시크릿은 **여러 줄 값을 그대로 받는다.** 그래서 `.p8` 파일을 열어 나오는
내용을 통째로 붙여 넣어도 되고, 한 줄로 만들고 싶으면 base64 로 인코딩해도 된다.
이 스크립트는 그 둘을 구분하지 않고 받아 준다 — 값을 넣는 사람이 "어느 형식이었더라"
를 기억하지 않아도 되게 하는 것이 목적이다.

받아 주는 모양

1. **p8 원문** (여러 줄)

       -----BEGIN PRIVATE KEY-----
       MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
       -----END PRIVATE KEY-----

2. **p8 원문을 한 줄로 이어 붙인 것** (`\\n` 을 두 글자로 넣은 경우 포함)
3. **base64** — 파일 전체를 인코딩한 값. 줄바꿈이 섞여 있어도 된다.
4. 위 어느 것이든 따옴표로 감싼 것

쓰는 법

    APP_STORE_CONNECT_KEY="$(cat AuthKey_XXXX.p8)" python3 tools/prepare_asc_key.py
    APP_STORE_CONNECT_KEY="$(base64 -i AuthKey_XXXX.p8 | tr -d '\\n')" python3 tools/prepare_asc_key.py

    python3 tools/prepare_asc_key.py --from-file AuthKey_XXXX.p8   # 로컬 확인용

키 내용은 **절대 출력하지 않는다.** 어떤 형식으로 읽었는지와 바이트 수만 남긴다.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import os
import pathlib
import re
import shutil
import subprocess
import sys

OUTPUT = pathlib.Path("AuthKey.p8")
PEM_MARK = "PRIVATE KEY"


class KeyError_(Exception):
    """사람이 읽고 바로 고칠 수 있는 메시지를 담는다."""


def normalize(raw: str) -> tuple[bytes, str]:
    """붙여 넣은 값을 PEM 바이트로 바꾼다. (바이트, 어떤 형식이었는지)"""
    if not raw or not raw.strip():
        raise KeyError_("APP_STORE_CONNECT_KEY 가 비어 있습니다.")

    text = raw.strip()

    # 양 끝 따옴표는 흔한 실수다. (쉘에서 감싸 복사한 경우)
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        text = text[1:-1].strip()

    # `\n` 을 두 글자로 붙여 넣은 경우가 많다. 실제 줄바꿈이 하나도 없을 때만 바꾼다.
    if "\\n" in text and "\n" not in text:
        text = text.replace("\\n", "\n")

    text = text.replace("\r\n", "\n").replace("\r", "\n")

    if "BEGIN" in text and PEM_MARK in text:
        return _rebuild_pem(text), "p8 원문"

    # base64. 줄바꿈·공백이 섞여 있어도 받아 준다.
    compact = "".join(text.split())
    if not compact:
        raise KeyError_("APP_STORE_CONNECT_KEY 에 쓸 수 있는 글자가 없습니다.")

    try:
        data = base64.b64decode(compact + "=" * (-len(compact) % 4), validate=False)
    except (binascii.Error, ValueError) as error:
        raise KeyError_(
            "APP_STORE_CONNECT_KEY 를 해석하지 못했습니다. "
            f"p8 원문이나 base64 여야 합니다. ({error})"
        ) from error

    if PEM_MARK.encode() not in data:
        raise KeyError_(
            "APP_STORE_CONNECT_KEY 가 .p8 파일이 아닙니다. "
            "AuthKey_XXXX.p8 의 내용(p8 원문) 또는 그 파일의 base64 를 넣어 주세요."
        )
    return _rebuild_pem(data.decode("utf-8", "replace")), "base64"


HEADER = re.compile(r"-----BEGIN ([A-Z0-9 ]*PRIVATE KEY)-----")
FOOTER = re.compile(r"-----END ([A-Z0-9 ]*PRIVATE KEY)-----")


def _rebuild_pem(text: str) -> bytes:
    """PEM 을 표준 모양으로 다시 만든다.

    한 줄로 이어 붙인 p8(`-----BEGIN-----MIGT...-----END-----`)은 그대로는
    OpenSSL 이 읽지 못한다 — 머리말·꼬리말이 따로 줄에 있어야 하기 때문이다.
    붙여 넣는 과정에서 줄바꿈이 사라지는 일이 흔해서, 본문만 뽑아 64자씩
    다시 끊어 준다.
    """
    header = HEADER.search(text)
    footer = FOOTER.search(text)
    if not header or not footer or footer.start() <= header.end():
        raise KeyError_(
            "p8 키의 머리말/꼬리말(-----BEGIN PRIVATE KEY----- … -----END PRIVATE KEY-----)을 찾지 못했습니다."
        )

    label = header.group(1)
    body = text[header.end():footer.start()]
    # 본문에는 base64 글자만 남긴다. (공백·줄바꿈·따옴표 제거)
    body = re.sub(r"[^A-Za-z0-9+/=]", "", body)
    if len(body) < 100:
        raise KeyError_("p8 키의 본문이 비어 있습니다. 파일을 다시 열어 통째로 붙여 넣어 주세요.")

    lines = [f"-----BEGIN {label}-----"]
    lines += [body[index:index + 64] for index in range(0, len(body), 64)]
    lines.append(f"-----END {label}-----")
    return ("\n".join(lines) + "\n").encode("utf-8")


def validate(data: bytes) -> str | None:
    """키가 실제로 풀리는지 확인한다. openssl 이 없으면 형식만 본다.

    잘못된 키를 그대로 두면 아카이브 단계의 `-authenticationKeyPath` 에서
    "Failed to authenticate" 라는, 원인을 알기 어려운 오류로 나타난다.
    여기서 먼저 멈추는 편이 훨씬 낫다.
    """
    if shutil.which("openssl") is None:
        return None

    result = subprocess.run(
        ["openssl", "pkey", "-noout"],
        input=data,
        capture_output=True,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip().splitlines()
        raise KeyError_(
            "p8 키를 열지 못했습니다. App Store Connect 에서 다시 받아 주세요."
            + (f" ({message[0]})" if message else "")
        )
    return "openssl 확인 통과"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--from-file",
        type=pathlib.Path,
        help="환경 변수 대신 파일에서 읽는다. (로컬에서 형식을 확인할 때)",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=OUTPUT,
        help=f"키를 쓸 경로 (기본: {OUTPUT})",
    )
    args = parser.parse_args()

    if args.from_file:
        raw = args.from_file.read_text(encoding="utf-8")
        source = str(args.from_file)
    else:
        raw = os.environ.get("APP_STORE_CONNECT_KEY", "")
        source = "APP_STORE_CONNECT_KEY"

    try:
        data, form = normalize(raw)
        checked = validate(data)
    except KeyError_ as error:
        print(f"::error::{error}", file=sys.stderr)
        print(
            "  AuthKey_XXXX.p8 을 텍스트 편집기로 열어 -----BEGIN PRIVATE KEY----- 부터 "
            "-----END PRIVATE KEY----- 까지 전부 붙여 넣으면 됩니다.",
            file=sys.stderr,
        )
        return 1

    args.output.write_bytes(data)
    try:
        args.output.chmod(0o600)
    except OSError:  # pragma: no cover - 파일 시스템에 따라
        pass

    # 어떤 형식으로 들어왔는지만 알린다. 키 내용은 절대 찍지 않는다.
    print(f"{source} → {args.output} ({len(data)} bytes, {form}" f"{', ' + checked if checked else ''})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
