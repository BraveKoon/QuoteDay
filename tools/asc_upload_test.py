#!/usr/bin/env python3
"""`tools/asc_upload.py` 자체 점검.

네트워크 없이 돌아간다. 키는 그때그때 openssl 로 만든다.

    python3 tools/asc_upload_test.py
"""

from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import asc_upload  # noqa: E402


def make_key(directory: str, name: str = "AuthKey_TEST.p8") -> str:
    """애플이 주는 것과 같은 PKCS#8(`BEGIN PRIVATE KEY`) EC 키."""
    raw = os.path.join(directory, "_raw.pem")
    path = os.path.join(directory, name)
    subprocess.run(
        ["openssl", "ecparam", "-genkey", "-name", "prime256v1", "-noout", "-out", raw],
        check=True,
    )
    subprocess.run(
        ["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", raw, "-out", path],
        check=True,
    )
    os.unlink(raw)
    return path


def public_key(key_path: str) -> str:
    result = subprocess.run(
        ["openssl", "pkey", "-in", key_path, "-pubout"], capture_output=True, check=True
    )
    return result.stdout.decode()


def split_token(token: str) -> tuple[dict, dict, bytes]:
    header, payload, signature = token.split(".")
    pad = lambda text: text + "=" * (-len(text) % 4)  # noqa: E731
    return (
        json.loads(base64.urlsafe_b64decode(pad(header))),
        json.loads(base64.urlsafe_b64decode(pad(payload))),
        base64.urlsafe_b64decode(pad(signature)),
    )


def raw_to_der(raw: bytes) -> bytes:
    def integer(chunk: bytes) -> bytes:
        chunk = chunk.lstrip(b"\x00") or b"\x00"
        if chunk[0] & 0x80:
            chunk = b"\x00" + chunk
        return b"\x02" + bytes([len(chunk)]) + chunk

    body = integer(raw[:32]) + integer(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


class TokenTests(unittest.TestCase):
    def test_team_token_has_issuer_and_valid_signature(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            key = make_key(directory)
            token = asc_upload.make_token(
                key, "ABC1234567", "69a6de7b-1111-2222-3333-444455556666", now=1_700_000_000
            )
            header, payload, signature = split_token(token)
            self.assertEqual(header["alg"], "ES256")
            self.assertEqual(header["kid"], "ABC1234567")
            self.assertEqual(payload["iss"], "69a6de7b-1111-2222-3333-444455556666")
            self.assertEqual(payload["aud"], "appstoreconnect-v1")
            self.assertEqual(payload["iat"], 1_700_000_000)
            self.assertEqual(payload["exp"], 1_700_000_900)
            self.assertNotIn("sub", payload)

            signing_input, _, _ = token.rpartition(".")
            with tempfile.NamedTemporaryFile(delete=False) as message:
                message.write(signing_input.encode())
                message_path = message.name
            der_path = message_path + ".der"
            with open(der_path, "wb") as handle:
                handle.write(raw_to_der(signature))
            public_path = key + ".pub"
            with open(public_path, "w", encoding="utf-8") as handle:
                handle.write(public_key(key))
            try:
                verified = subprocess.run(
                    ["openssl", "dgst", "-sha256", "-verify", public_path,
                     "-signature", der_path, message_path],
                    capture_output=True, text=True,
                )
                self.assertEqual(verified.returncode, 0, verified.stdout + verified.stderr)
            finally:
                os.unlink(message_path)
                os.unlink(der_path)
                os.unlink(public_path)

    def test_individual_token_uses_sub_user(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            key = make_key(directory)
            token = asc_upload.make_token(key, "ABC1234567", None, kind="individual")
            _, payload, _ = split_token(token)
            self.assertEqual(payload["sub"], "user")
            self.assertNotIn("iss", payload)

    def test_team_token_without_issuer_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            key = make_key(directory)
            with self.assertRaises(ValueError):
                asc_upload.make_token(key, "ABC1234567", None)


class DerTests(unittest.TestCase):
    def test_raw_signature_is_64_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            key = make_key(directory)
            raw = asc_upload.sign_es256(key, b"hello")
            self.assertEqual(len(raw), 64)

    def test_short_integers_are_left_padded(self) -> None:
        der = bytes.fromhex("3006020101020102")
        expected = b"\x00" * 31 + b"\x01" + b"\x00" * 31 + b"\x02"
        self.assertEqual(asc_upload.der_signature_to_raw(der), expected)

    def test_leading_zero_padding_is_stripped(self) -> None:
        # 0x00 0x80.. 은 DER 이 부호를 살리려고 넣은 0 이다. 떼고 32바이트로 맞춘다.
        r = b"\x00" + b"\x80" + b"\x00" * 30
        s = b"\x00" * 32
        body = bytes([0x02, len(r)]) + r + bytes([0x02, len(s)]) + s
        der = b"\x30" + bytes([len(body)]) + body
        raw = asc_upload.der_signature_to_raw(der)
        self.assertEqual(len(raw), 64)
        # 맨 앞 0 은 부호용이라 떼고, 32바이트로 맞추느라 0 하나가 다시 붙는다.
        self.assertEqual(raw[:3], b"\x00\x80\x00")
        self.assertEqual(raw[32:], b"\x00" * 32)

    def test_long_form_length(self) -> None:
        r = b"\x11" * 32
        s = b"\x22" * 32
        body = b"\x02\x20" + r + b"\x02\x20" + s
        der = b"\x30\x81" + bytes([len(body)]) + body
        self.assertEqual(asc_upload.der_signature_to_raw(der), r + s)

    def test_garbage_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            asc_upload.der_signature_to_raw(b"\x31\x00")


class UploadTests(unittest.TestCase):
    """조각 업로드가 오프셋·길이·헤더를 그대로 지키는지."""

    def setUp(self) -> None:
        self.directory = tempfile.mkdtemp()
        self.ipa = os.path.join(self.directory, "QuoteDay.ipa")
        with open(self.ipa, "wb") as handle:
            handle.write(bytes(range(256)) * 4)

    def test_chunks_cover_the_whole_file(self) -> None:
        seen: list[tuple[int, bytes, dict]] = []

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

        def fake_urlopen(request, timeout=0):
            seen.append((len(request.data), request.data, dict(request.headers)))
            return Response()

        original = asc_upload.urllib.request.urlopen
        asc_upload.urllib.request.urlopen = fake_urlopen
        try:
            operations = [
                {"method": "PUT", "url": "https://example.invalid/0", "length": 400,
                 "offset": 0, "requestHeaders": [{"name": "X-Test", "value": "a"}]},
                {"method": "PUT", "url": "https://example.invalid/1", "length": 624,
                 "offset": 400, "requestHeaders": []},
            ]
            asc_upload.put_operations(self.ipa, operations)
        finally:
            asc_upload.urllib.request.urlopen = original

        self.assertEqual(len(seen), 2)
        self.assertEqual(seen[0][0], 400)
        self.assertEqual(seen[1][0], 624)
        with open(self.ipa, "rb") as handle:
            self.assertEqual(seen[0][1] + seen[1][1], handle.read())
        headers = {key.lower(): value for key, value in seen[0][2].items()}
        self.assertEqual(headers.get("x-test"), "a")

    def test_short_read_is_an_error(self) -> None:
        operations = [{"method": "PUT", "url": "https://example.invalid/0",
                       "length": 9999, "offset": 0, "requestHeaders": []}]
        with self.assertRaises(RuntimeError):
            asc_upload.put_operations(self.ipa, operations)


class NextBuildNumberTests(unittest.TestCase):
    """빌드 번호는 '몇 번째 빌드인지'로 읽혀야 한다."""

    def _client_with_versions(self, versions):
        client = asc_upload.Asc("AuthKey.p8", "KEY", "ISSUER")
        def fake_call(method, path, body=None):
            self.assertEqual(method, "GET")
            self.assertIn("/v1/builds", path)
            return {"data": [{"attributes": {"version": v}} for v in versions]}
        client.call = fake_call
        return client

    def test_timestamp_builds_are_ignored(self) -> None:
        # 예전에 올린 시각 형식(202611012329)은 순번이 아니다.
        client = self._client_with_versions(["202611012329", "202611012312", "26"])
        self.assertEqual(asc_upload.sequential_builds(client, "app"), [26])
        self.assertEqual(asc_upload.next_build_number(client, "app", 27), 27)

    def test_floor_is_next_number_when_unused(self) -> None:
        client = self._client_with_versions(["26", "24"])
        self.assertEqual(asc_upload.next_build_number(client, "app", 27), 27)

    def test_running_ahead_of_the_repository(self) -> None:
        # 프로젝트 파일이 27 인데 이미 27·28 이 올라갔다면 29 를 쓴다.
        client = self._client_with_versions(["27", "28", "26"])
        self.assertEqual(asc_upload.next_build_number(client, "app", 27), 29)

    def test_no_builds_yet(self) -> None:
        client = self._client_with_versions([])
        self.assertEqual(asc_upload.next_build_number(client, "app", 27), 27)

    def test_garbage_versions_are_ignored(self) -> None:
        client = self._client_with_versions(["", "abc", "12.3", "0", "31"])
        self.assertEqual(asc_upload.sequential_builds(client, "app"), [31])


class ClientTests(unittest.TestCase):
    def setUp(self) -> None:
        # 네트워크·키 없이 클라이언트 로직만 본다.
        self._token = asc_upload.make_token
        asc_upload.make_token = lambda *a, **k: "header.payload.signature"

    def tearDown(self) -> None:
        asc_upload.make_token = self._token

    def test_credential_error_on_401(self) -> None:
        original = asc_upload.request_json
        asc_upload.request_json = lambda *a, **k: (401, {"errors": [{"title": "Unauthorized"}]})
        try:
            client = asc_upload.Asc("AuthKey.p8", "KEY", "ISSUER")
            with self.assertRaises(asc_upload.CredentialError):
                client.call("GET", "/v1/apps")
        finally:
            asc_upload.request_json = original

    def test_missing_app_record_is_a_lookup_error(self) -> None:
        original = asc_upload.request_json
        asc_upload.request_json = lambda *a, **k: (200, {"data": []})
        try:
            client = asc_upload.Asc("AuthKey.p8", "KEY", "ISSUER")
            with self.assertRaises(LookupError):
                asc_upload.find_app(client, "com.quoteday.QuoteDay")
        finally:
            asc_upload.request_json = original

    def test_state_is_read_from_both_shapes(self) -> None:
        # API 가 객체로 줄 때와 문자열로 줄 때가 있다. 둘 다 읽어야
        # 업로드가 끝난 뒤에 형식 때문에 실패로 보이지 않는다.
        self.assertEqual(
            asc_upload.upload_state({"state": {"state": "COMPLETE", "errors": []}}),
            ("COMPLETE", []),
        )
        self.assertEqual(asc_upload.upload_state({"state": "PROCESSING"}), ("PROCESSING", []))
        self.assertEqual(asc_upload.upload_state({}), ("UNKNOWN", []))

    def test_wait_gives_up_on_failed_state(self) -> None:
        original = asc_upload.request_json
        asc_upload.request_json = lambda *a, **k: (
            200,
            {"data": {"attributes": {"state": {"state": "FAILED",
                                               "errors": [{"code": "90062", "description": "duplicate"}]}}}},
        )
        try:
            client = asc_upload.Asc("AuthKey.p8", "KEY", "ISSUER")
            with self.assertRaises(RuntimeError) as caught:
                asc_upload.wait_for_upload(client, "upload-id", timeout=5)
            self.assertIn("90062", str(caught.exception))
        finally:
            asc_upload.request_json = original


if __name__ == "__main__":
    unittest.main(verbosity=2)
