#!/usr/bin/env python3
"""`tools/prepare_asc_key.py` 자체 점검.

    python3 tools/prepare_asc_key_test.py

App Store Connect 키를 넣는 방법이 여러 가지라(그대로·한 줄·base64 …), 그중 하나가
조용히 깨지면 업로드할 때가 되어서야 알게 된다. 여기서는 실제 키를 하나 만들어
**모든 입력 형태가 같은 바이트로 돌아오는지** 확인한다.

openssl 이 없으면 건너뛴다. (러너에는 들어 있다)
"""

from __future__ import annotations

import base64
import importlib.util
import pathlib
import shutil
import subprocess
import sys
import tempfile

TOOLS = pathlib.Path(__file__).resolve().parent


def load_module():
    spec = importlib.util.spec_from_file_location("prepare_asc_key", TOOLS / "prepare_asc_key.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_key(directory: pathlib.Path) -> bytes:
    """Apple 과 같은 모양(PKCS#8, EC P-256)의 테스트 키를 만든다."""
    result = subprocess.run(
        "openssl ecparam -genkey -name prime256v1 -noout | "
        "openssl pkcs8 -topk8 -nocrypt",
        shell=True,
        check=True,
        capture_output=True,
    )
    pem = result.stdout
    (directory / "AuthKey_TEST.p8").write_bytes(pem)
    return pem


def main() -> int:
    if shutil.which("openssl") is None:
        print("openssl 이 없어 건너뜁니다.")
        return 0

    module = load_module()
    failures: list[str] = []
    checks = 0

    with tempfile.TemporaryDirectory() as temp:
        directory = pathlib.Path(temp)
        pem = make_key(directory).decode("utf-8")
        expected = module.normalize(pem)[0]

        if expected != pem.encode("utf-8"):
            failures.append("p8 원문을 그대로 돌려주지 않았다.")
        checks += 1

        # 붙여 넣는 과정에서 생길 수 있는 모양들.
        forms = {
            "여러 줄 그대로": pem,
            "양 끝 공백": f"\n\n{pem}\n\n",
            "줄바꿈이 모두 사라진 한 줄": "".join(pem.splitlines()),
            "\\n 이 두 글자": pem.replace("\n", "\\n"),
            "CRLF": pem.replace("\n", "\r\n"),
            "따옴표로 감쌈": f'"{pem}"',
            "base64 (여러 줄)": base64.encodebytes(pem.encode()).decode(),
            "base64 (한 줄)": base64.b64encode(pem.encode()).decode(),
            "base64 + 따옴표": f"'{base64.b64encode(pem.encode()).decode()}'",
        }
        for name, value in forms.items():
            checks += 1
            try:
                data, _ = module.normalize(value)
            except module.KeyError_ as error:
                failures.append(f"{name}: 해석하지 못했다 ({error})")
                continue
            if data != expected:
                failures.append(f"{name}: 원본과 다른 바이트가 나왔다.")
            elif module.validate(data) is None:
                failures.append(f"{name}: openssl 확인을 건너뛰었다.")

        # 실패해야 하는 값들. 조용히 통과하면 잘못된 키로 아카이브까지 간다.
        bad = {
            "빈 값": "",
            "공백만": "   \n  ",
            "아무 문자열": "hello",
            "무관한 base64": base64.b64encode(b"not a key").decode(),
            "잘린 p8": "\n".join(pem.splitlines()[:3]),
            "본문이 망가진 p8": pem.replace(pem.splitlines()[2], "A" * 64),
        }
        for name, value in bad.items():
            checks += 1
            try:
                data, _ = module.normalize(value)
                if module.validate(data) is not None:
                    failures.append(f"{name}: 실패해야 하는데 통과했다.")
            except module.KeyError_:
                pass

        # CLI 로 끝까지 한 번 (파일 → 파일)
        checks += 1
        output = directory / "out.p8"
        result = subprocess.run(
            [sys.executable, str(TOOLS / "prepare_asc_key.py"),
             "--from-file", str(directory / "AuthKey_TEST.p8"), "--output", str(output)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            failures.append(f"CLI 실행 실패: {result.stderr.strip()}")
        elif not output.exists() or output.read_bytes() != expected:
            failures.append("CLI 가 만든 파일이 원본과 다르다.")

        # 로그에 키 내용이 새면 안 된다.
        checks += 1
        if "PRIVATE KEY" in result.stdout or "MIG" in result.stdout:
            failures.append("CLI 출력에 키 내용이 섞였다.")

    print(f"prepare_asc_key 점검 {checks}건")
    if failures:
        for failure in failures:
            print(" -", failure)
        return 1
    print("통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
