#!/usr/bin/env python3
"""CI 가 자동 서명하며 쌓은 **"Created via API" 개발 인증서**만 지운다.

GitHub 의 macOS 러너는 매번 새 기계라 키체인에 인증서가 없다. 자동 서명(`-allowProvisioningUpdates`)이
실행마다 개발 인증서를 하나씩 새로 만들었고, 계정 한도에 걸려 TestFlight 업로드가 막혔다
(`Your account has reached the maximum number of certificates`).

**지우는 것은 아주 좁다.**

- 종류가 `DEVELOPMENT` 인 것만. (`IOS_DEVELOPMENT` · 배포 인증서는 건드리지 않는다.)
- 이름이 정확히 `Created via API` 인 것만. 사람이 만든 인증서(`우진 전`, `JIN HO JEON`)는 이름이 달라 빠진다.
- 기본은 **목록만 보여 준다.** `--apply` 를 줘야 지운다.
- `--expect N` 을 주면 지울 대상이 정확히 N 개일 때만 지운다. 그 사이 사람이 만든 것이 같은
  이름으로 섞였거나 개수가 달라졌으면 아무것도 지우지 않고 멈춘다.

지운 인증서로 서명된 것(이미 올라간 빌드·Xcode Cloud 빌드)은 영향을 받지 않는다. 개발 인증서는
기기에 직접 설치하는 개발용 빌드에만 쓰이고, Xcode Cloud 는 Apple 이 관리하는 인증서를 쓴다.

    python3 tools/asc_revoke_api_certs.py --key AuthKey.p8 --key-id XXXX --issuer YYYY            # 목록만
    python3 tools/asc_revoke_api_certs.py ... --apply --expect 11                                 # 지우기
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_signing_report import listing  # noqa: E402
from asc_upload import Asc, CredentialError  # noqa: E402

TARGET_TYPE = "DEVELOPMENT"
TARGET_NAME = "Created via API"


def label(cert: dict) -> str:
    a = cert["attributes"]
    return (f"{a.get('certificateType', '?'):<16} 만료 {str(a.get('expirationDate', '?'))[:10]}  "
            f"{a.get('displayName', a.get('name', '?'))}  [{cert['id'][:6]}…]")


def select(certificates: list[dict]) -> tuple[list[dict], list[dict]]:
    """(지울 것, 남길 것)."""
    doomed: list[dict] = []
    kept: list[dict] = []
    for cert in certificates:
        a = cert["attributes"]
        name = a.get("displayName") or a.get("name")
        if a.get("certificateType") == TARGET_TYPE and name == TARGET_NAME:
            doomed.append(cert)
        else:
            kept.append(cert)
    return doomed, kept


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--key", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer", required=True)
    parser.add_argument("--apply", action="store_true", help="실제로 지운다. 없으면 목록만 보여 준다.")
    parser.add_argument("--expect", type=int, help="지울 대상이 정확히 이 개수일 때만 지운다.")
    args = parser.parse_args()

    client = Asc(args.key, args.key_id, args.issuer, "team")
    try:
        certificates = listing(client, "/v1/certificates?limit=200")
    except CredentialError as error:
        print(f"인증 실패: {error}")
        return 2

    doomed, kept = select(certificates)
    print(f"인증서 {len(certificates)}개 중 지울 것 {len(doomed)}개, 남길 것 {len(kept)}개\n")
    print("== 지울 것 ==")
    for cert in doomed:
        print("  " + label(cert))
    print("\n== 남길 것 ==")
    for cert in kept:
        print("  " + label(cert))

    if not args.apply:
        print("\n목록만 보여 주었다. 지우지 않았다. (--apply 를 주면 지운다)")
        return 0

    if args.expect is None:
        print("\n--apply 에는 --expect N 이 함께 필요하다. 아무것도 지우지 않았다.")
        return 2
    if len(doomed) != args.expect:
        print(f"\n지울 대상이 {len(doomed)}개인데 {args.expect}개를 기대했다. 아무것도 지우지 않았다.")
        return 2
    if not doomed:
        print("\n지울 것이 없다.")
        return 0

    failures = 0
    for cert in doomed:
        try:
            client.call("DELETE", f"/v1/certificates/{cert['id']}")
            print(f"  지움  [{cert['id'][:6]}…]")
        except Exception as error:  # noqa: BLE001 — 하나가 실패해도 나머지는 계속한다.
            failures += 1
            print(f"  실패  [{cert['id'][:6]}…] {error}")
    print(f"\n지운 것 {len(doomed) - failures}개, 실패 {failures}개")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
