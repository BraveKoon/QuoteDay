#!/usr/bin/env python3
"""App Store Connect **Build Upload API** 로 .ipa 를 올린다.

왜 altool 이 아니라 REST 인가
-----------------------------
`xcrun altool --upload-app`, `xcodebuild -exportArchive -destination upload`
는 애플의 옛 contentdelivery 서비스로 먼저 인사를 한다. 이 서비스가 팀 API
키를 `Cannot verify client's JWT headers (3004)` 로 거부하는 사례가 알려져
있고, **같은 키·같은 키 ID·같은 발급자 ID 로 App Store Connect REST API 는
그대로 동작한다.** 그래서 서명·내보내기는 xcodebuild 로 하고, 업로드만
REST(Build Upload API)로 옮긴다.

동작 순서
---------
1. `GET /v1/apps?filter[bundleId=...]` — 키가 유효한지, 앱 레코드가 있는지 확인
2. `POST /v1/buildUploads` — 버전·빌드 번호로 업로드 예약
3. `POST /v1/buildUploadFiles` — 파일 크기를 알려 주고 업로드 조각을 받음
4. 각 조각을 `PUT` (오프셋 단위로 잘라서)
5. `PATCH .../buildUploadFiles/{id}` — `uploaded: true`
6. `GET /v1/buildUploads/{id}` — 상태가 COMPLETE 가 될 때까지 기다림

의존성 없음: 서명은 `openssl dgst`, 통신은 표준 라이브러리만 쓴다.

사용법
------
    python3 tools/asc_upload.py --check
    python3 tools/asc_upload.py --upload build/export/QuoteDay.ipa

환경 변수로도 받는다: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, ASC_BUNDLE_ID
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"
DEFAULT_BUNDLE_ID = "com.quoteday.QuoteDay"

# 종료 코드
OK = 0
FAILED = 1
BAD_CREDENTIALS = 2


# ────────────────────────────── JWT (ES256) ──────────────────────────────


def b64u(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _read_der_len(raw: bytes, i: int) -> tuple[int, int]:
    """DER 길이 필드를 읽는다. (길이, 다음 위치)"""
    first = raw[i]
    if first < 0x80:
        return first, i + 1
    count = first & 0x7F
    value = int.from_bytes(raw[i + 1 : i + 1 + count], "big")
    return value, i + 1 + count


def der_signature_to_raw(der: bytes) -> bytes:
    """openssl 이 주는 DER(`30 .. 02 r 02 s`) 을 JWS 용 r||s 64바이트로."""
    if not der or der[0] != 0x30:
        raise ValueError("서명이 DER SEQUENCE 가 아닙니다.")
    _, i = _read_der_len(der, 1)
    parts = []
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("서명에 INTEGER 가 없습니다.")
        length, i = _read_der_len(der, i + 1)
        value = der[i : i + length]
        i += length
        # 앞쪽 0 패딩은 떼고, 32바이트로 왼쪽을 채운다.
        value = value.lstrip(b"\x00") or b"\x00"
        parts.append(value.rjust(32, b"\x00"))
    if any(len(p) > 32 for p in parts):
        raise ValueError("서명 길이가 32바이트를 넘습니다.")
    return parts[0] + parts[1]


def sign_es256(key_path: str, message: bytes) -> bytes:
    with tempfile.NamedTemporaryFile(delete=False) as handle:
        handle.write(message)
        message_path = handle.name
    try:
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path, message_path],
            capture_output=True,
        )
        if result.returncode != 0:
            raise RuntimeError(
                "openssl 로 서명하지 못했습니다: "
                + result.stderr.decode("utf-8", "replace").strip()
            )
        return der_signature_to_raw(result.stdout)
    finally:
        os.unlink(message_path)


def make_token(
    key_path: str,
    key_id: str,
    issuer_id: str | None,
    kind: str = "team",
    now: int | None = None,
    lifetime: int = 900,
) -> str:
    """App Store Connect 용 JWT.

    team       : `iss` = 발급자 ID (App Store Connect → 사용자 및 액세스 → **팀 키**)
    individual : `sub` = "user", 발급자 없음 (**개인 키**)
    """
    stamp = int(time.time() if now is None else now)
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload: dict[str, object] = {
        "iat": stamp,
        "exp": stamp + lifetime,
        "aud": "appstoreconnect-v1",
    }
    if kind == "individual":
        payload["sub"] = "user"
    else:
        if not issuer_id:
            raise ValueError("팀 키에는 발급자 ID 가 필요합니다.")
        payload["iss"] = issuer_id

    signing_input = (
        b64u(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64u(json.dumps(payload, separators=(",", ":")).encode())
    ).encode()
    return signing_input.decode() + "." + b64u(sign_es256(key_path, signing_input))


# ──────────────────────────────── 통신 ────────────────────────────────


class CredentialError(RuntimeError):
    """키가 거부됨. 시크릿을 손봐야 한다."""


def request_json(
    method: str,
    url: str,
    token: str,
    body: dict | None = None,
    timeout: int = 60,
) -> tuple[int, dict]:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            payload = json.loads(raw) if raw else {}
        except ValueError:
            payload = {"raw": raw.decode("utf-8", "replace")}
        return error.code, payload


def describe_errors(payload: dict) -> str:
    errors = payload.get("errors") or []
    lines = []
    for error in errors:
        title = error.get("title", "error")
        detail = error.get("detail", "")
        code = error.get("code", "")
        lines.append(f"{title} [{code}] {detail}".strip())
    if not lines and payload.get("raw"):
        lines.append(str(payload["raw"])[:400])
    return " / ".join(lines) or json.dumps(payload)[:300]


class Asc:
    """토큰을 스스로 갱신하는 얇은 클라이언트."""

    def __init__(self, key_path: str, key_id: str, issuer_id: str | None,
                 kind: str = "team") -> None:
        self.key_path = key_path
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.kind = kind
        self._token: str | None = None
        self._issued_at = 0.0

    def token(self) -> str:
        if self._token is None or time.time() - self._issued_at > 600:
            self._token = make_token(self.key_path, self.key_id, self.issuer_id, self.kind)
            self._issued_at = time.time()
        return self._token

    def call(self, method: str, path: str, body: dict | None = None) -> dict:
        status, payload = request_json(method, API + path, self.token(), body)
        if status in (401, 403):
            raise CredentialError(f"HTTP {status}: {describe_errors(payload)}")
        if not 200 <= status < 300:
            raise RuntimeError(f"HTTP {status}: {describe_errors(payload)}")
        return payload


# ────────────────────────────── 단계별 동작 ──────────────────────────────


def find_app(client: Asc, bundle_id: str) -> str:
    payload = client.call("GET", f"/v1/apps?filter[bundleId]={bundle_id}&limit=1")
    data = payload.get("data") or []
    if not data:
        raise LookupError(
            f"App Store Connect 에 '{bundle_id}' 앱 레코드가 없습니다. "
            "내 앱 → 새 앱 에서 먼저 만들어 주세요."
        )
    return data[0]["id"]


def create_build_upload(client: Asc, app_id: str, version: str, build: str) -> str:
    body = {
        "data": {
            "type": "buildUploads",
            "attributes": {
                "cfBundleShortVersionString": version,
                "cfBundleVersion": build,
                "platform": "IOS",
            },
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    payload = client.call("POST", "/v1/buildUploads", body)
    return payload["data"]["id"]


def create_build_upload_file(
    client: Asc, upload_id: str, file_name: str, file_size: int
) -> tuple[str, list[dict]]:
    body = {
        "data": {
            "type": "buildUploadFiles",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size,
                "uti": "com.apple.ipa",
            },
            "relationships": {
                "buildUpload": {"data": {"type": "buildUploads", "id": upload_id}}
            },
        }
    }
    payload = client.call("POST", "/v1/buildUploadFiles", body)
    attributes = payload["data"]["attributes"]
    operations = attributes.get("uploadOperations") or []
    if not operations:
        raise RuntimeError("업로드 조각(uploadOperations)을 받지 못했습니다.")
    return payload["data"]["id"], operations


def put_operations(ipa_path: str, operations: list[dict]) -> None:
    size = os.path.getsize(ipa_path)
    with open(ipa_path, "rb") as handle:
        for number, operation in enumerate(operations, start=1):
            offset = int(operation["offset"])
            length = int(operation["length"])
            handle.seek(offset)
            chunk = handle.read(length)
            if len(chunk) != length:
                raise RuntimeError(
                    f"조각 {number}: {length}바이트를 읽어야 하는데 {len(chunk)}바이트만 읽었습니다."
                )
            headers = {
                header["name"]: header["value"]
                for header in operation.get("requestHeaders") or []
            }
            request = urllib.request.Request(
                operation["url"], data=chunk, method=operation.get("method", "PUT"),
                headers=headers,
            )
            with urllib.request.urlopen(request, timeout=600) as response:
                if not 200 <= response.status < 300:
                    raise RuntimeError(f"조각 {number}: HTTP {response.status}")
            percent = min(100, round(offset + length) * 100 // max(1, size))
            print(f"  조각 {number}/{len(operations)} · {percent}%", flush=True)


def finish_file(client: Asc, upload_id: str, file_id: str) -> None:
    body = {
        "data": {
            "type": "buildUploadFiles",
            "id": file_id,
            "attributes": {"uploaded": True},
        }
    }
    client.call("PATCH", f"/v1/buildUploadFiles/{file_id}", body)


def upload_state(attributes: dict) -> tuple[str, list[dict]]:
    """`buildUploads` 의 state 를 읽는다.

    API 가 이 값을 문자열로 줄 때와 `{state: ..., errors: [...]}` 객체로 줄 때가
    있어 둘 다 받는다. 한쪽만 가정하면 업로드가 **끝난 뒤에** 형식 때문에
    실패로 보인다.
    """
    raw = attributes.get("state")
    if isinstance(raw, dict):
        return str(raw.get("state", "UNKNOWN")), raw.get("errors") or []
    if isinstance(raw, str):
        return raw, attributes.get("errors") or []
    return "UNKNOWN", []


def wait_for_upload(client: Asc, upload_id: str, timeout: int = 1800) -> dict:
    deadline = time.time() + timeout
    state = "UNKNOWN"
    while time.time() < deadline:
        payload = client.call("GET", f"/v1/buildUploads/{upload_id}")
        attributes = payload["data"]["attributes"]
        state, errors = upload_state(attributes)
        print(f"  상태: {state}", flush=True)
        if state in ("COMPLETE", "SUCCEEDED"):
            return attributes
        if state in ("FAILED", "FAILED_VALIDATION") or errors:
            detail = " / ".join(
                f"{item.get('code', '')} {item.get('description', '')}".strip()
                for item in errors
            )
            raise RuntimeError(f"처리에 실패했습니다({state}). {detail}")
        time.sleep(20)
    raise RuntimeError(f"{timeout}초 안에 처리가 끝나지 않았습니다(마지막 상태 {state}).")


# ─────────────────────────────── CLI ───────────────────────────────


def check_credentials(key_path: str, key_id: str, issuer_id: str | None,
                      bundle_id: str) -> tuple[Asc, str]:
    """팀 키로 먼저, 안 되면 개인 키로 확인한다."""
    attempts: list[tuple[str, str | None]] = []
    if issuer_id:
        attempts.append(("team", issuer_id))
    attempts.append(("individual", None))

    last: Exception | None = None
    for kind, issuer in attempts:
        client = Asc(key_path, key_id, issuer, kind)
        try:
            app_id = find_app(client, bundle_id)
        except CredentialError as error:
            print(f"  {kind} 키로는 거부됨: {error}", flush=True)
            last = error
            continue
        except LookupError as error:
            print(f"  인증은 통과했지만 앱이 없습니다: {error}", flush=True)
            raise
        print(f"  {kind} 키 인증 통과 · 앱 ID {app_id}", flush=True)
        return client, app_id
    raise CredentialError(str(last) if last else "인증 실패")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="키와 앱만 확인")
    parser.add_argument("--upload", metavar="IPA", help="올릴 .ipa 경로")
    parser.add_argument("--key", default=os.environ.get("ASC_KEY_PATH", "AuthKey.p8"))
    parser.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID"))
    parser.add_argument("--issuer", default=os.environ.get("ASC_ISSUER_ID"))
    parser.add_argument("--bundle-id", default=os.environ.get("ASC_BUNDLE_ID", DEFAULT_BUNDLE_ID))
    parser.add_argument("--version", required=False, help="CFBundleShortVersionString")
    parser.add_argument("--build", required=False, help="CFBundleVersion")
    parser.add_argument("--wait", type=int, default=1800, help="처리 대기 한도(초)")
    args = parser.parse_args(argv)

    if not args.check and not args.upload:
        parser.error("--check 또는 --upload 중 하나가 필요합니다.")
    if not args.key_id:
        parser.error("--key-id 가 필요합니다.")
    if not os.path.exists(args.key):
        parser.error(f"키 파일이 없습니다: {args.key}")

    try:
        client, app_id = check_credentials(
            args.key, args.key_id, args.issuer, args.bundle_id
        )
    except CredentialError as error:
        print(f"키가 거부되었습니다: {error}", file=sys.stderr)
        print(
            "확인할 것: ① 키 ID 와 발급자 ID 가 같은 팀 키에서 나왔는지 "
            "② 키가 취소(revoked)되지 않았는지 "
            "③ 개인 키라면 팀 키를 새로 만들어 그 값을 쓰는지",
            file=sys.stderr,
        )
        return BAD_CREDENTIALS
    except LookupError as error:
        print(str(error), file=sys.stderr)
        return FAILED

    if args.check:
        print("자가 점검 통과")
        return OK

    ipa = args.upload
    if not os.path.exists(ipa):
        print(f"올릴 파일이 없습니다: {ipa}", file=sys.stderr)
        return FAILED
    if not args.version or not args.build:
        print("--version 과 --build 가 필요합니다.", file=sys.stderr)
        return FAILED

    size = os.path.getsize(ipa)
    print(f"업로드: {ipa} ({size / 1_048_576:.1f}MB) · {args.version}({args.build})", flush=True)
    try:
        upload_id = create_build_upload(client, app_id, args.version, args.build)
        print(f"  buildUpload {upload_id}", flush=True)
        file_id, operations = create_build_upload_file(
            client, upload_id, os.path.basename(ipa), size
        )
        print(f"  buildUploadFile {file_id} · 조각 {len(operations)}개", flush=True)
        put_operations(ipa, operations)
        finish_file(client, upload_id, file_id)
        print("  업로드 완료. 애플 처리 상태를 기다립니다.", flush=True)
        wait_for_upload(client, upload_id, args.wait)
    except CredentialError as error:
        print(f"업로드 도중 키가 거부되었습니다: {error}", file=sys.stderr)
        return BAD_CREDENTIALS
    except Exception as error:  # noqa: BLE001 - 워크플로가 원문을 남길 수 있게
        print(f"업로드 실패: {error}", file=sys.stderr)
        return FAILED

    print("App Store Connect 처리가 끝났습니다. TestFlight 에 곧 나타납니다.")
    return OK


if __name__ == "__main__":
    raise SystemExit(main())
