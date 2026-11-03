#!/usr/bin/env python3
"""App Store Connect 에 등록된 **서명 상태**를 읽어 보여 준다. 읽기 전용이다.

TestFlight 의 아카이브가 `No profiles for ... were found` 로 끊길 때, 코드는
멀쩡한데 Apple 계정 쪽이 어떤 상태인지 CI 밖에서는 볼 수 없다. 이 스크립트는 이미
CI 가 쓰는 API 키로 인증서·프로파일·앱 ID 를 **조회만** 한다. 만들지도 지우지도
않는다 — 계정의 인증서를 CI 가 마음대로 지우게 하는 것은 되돌릴 수 없는 일이라서다.

    python3 tools/asc_signing_report.py --key AuthKey.p8 --key-id XXXX --issuer YYYY

무엇을 보여 주나

1. 인증서 — 종류·만료일·누가 만들었는지. 배포 인증서 개수 한도에 걸렸는지 가늠한다.
2. 앱 ID — 앱·위젯 번들 ID 가 등록되어 있는지, 켜 둔 기능(iCloud·App Group 등).
3. 프로파일 — 상태(ACTIVE/INVALID)·종류. 무효인 것이 있으면 자동 서명이 새로 만들다 막힌다.

키의 비밀 값은 출력하지 않는다.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_upload import Asc, CredentialError  # noqa: E402

BUNDLE_IDS = ("com.quoteday.QuoteDay", "com.quoteday.QuoteDay.Widget")


def listing(client: Asc, path: str) -> list[dict]:
    """페이지를 넘기며 끝까지 읽는다. (`next` 링크를 따라간다)"""
    items: list[dict] = []
    url = path
    while url:
        payload = client.call("GET", url)
        items.extend(payload.get("data", []))
        link = (payload.get("links") or {}).get("next")
        url = link.split("api.appstoreconnect.apple.com", 1)[-1] if link else ""
    return items


def section(title: str) -> None:
    print(f"\n== {title} ==")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer", required=True)
    args = parser.parse_args()

    client = Asc(args.key, args.key_id, args.issuer, "team")

    try:
        certificates = listing(client, "/v1/certificates?limit=200")
    except CredentialError as error:
        print(f"인증 실패: {error}")
        return 2

    section(f"인증서 {len(certificates)}개")
    by_type: dict[str, int] = {}
    for cert in certificates:
        a = cert["attributes"]
        kind = a.get("certificateType", "?")
        by_type[kind] = by_type.get(kind, 0) + 1
        print(f"  {kind:<26} 만료 {str(a.get('expirationDate', '?'))[:10]}  "
              f"{a.get('displayName', a.get('name', '?'))}  [{cert['id'][:6]}…]")
    print("  종류별:", ", ".join(f"{k} {v}" for k, v in sorted(by_type.items())) or "없음")

    section("앱 ID")
    for identifier in BUNDLE_IDS:
        found = listing(client, f"/v1/bundleIds?filter[identifier]={identifier}&limit=10")
        exact = [b for b in found if b["attributes"].get("identifier") == identifier]
        if not exact:
            print(f"  {identifier}: **등록되어 있지 않음**")
            continue
        bundle = exact[0]
        caps = listing(client, f"/v1/bundleIds/{bundle['id']}/bundleIdCapabilities")
        names = sorted(c["attributes"].get("capabilityType", "?") for c in caps)
        print(f"  {identifier}: 등록됨 · 기능 {len(names)}개")
        print("     " + (", ".join(names) or "(없음)"))

    devices = listing(client, "/v1/devices?limit=200")
    section(f"등록된 기기 {len(devices)}개")
    for device in devices:
        a = device["attributes"]
        print(f"  {a.get('platform', '?'):<6} {a.get('status', '?'):<9} {a.get('deviceType', '?'):<12} "
              f"{a.get('name', '?')}")
    if not devices:
        print("  없음 — 개발용 프로파일은 기기가 하나도 없으면 만들어지지 않는다")

    profiles = listing(client, "/v1/profiles?limit=200")
    section(f"프로파일 {len(profiles)}개")
    if not profiles:
        print("  없음 (클라우드 관리 서명은 목록에 보이지 않을 수 있다)")
    for profile in profiles:
        a = profile["attributes"]
        print(f"  {a.get('profileState', '?'):<8} {a.get('profileType', '?'):<22} "
              f"만료 {str(a.get('expirationDate', '?'))[:10]}  {a.get('name', '?')}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
