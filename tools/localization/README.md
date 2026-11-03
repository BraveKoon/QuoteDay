# 번역 사전을 만드는 도구

앱은 네 가지 언어로 동작한다 — 한국어(원본), English, 简体中文, 繁體中文.
이 폴더에는 그중 **번체 사전을 만드는 스크립트**와, 사전을 다루는 규칙이 들어 있다.

## 왜 번체를 따로 쓰지 않는가

같은 문장을 두 언어로 손수 관리하면 반드시 어긋난다. 한쪽만 고치는 실수는 눈에
띄지 않고, 그 문장은 몇 달 동안 화면에 남는다. 그래서 **간체가 원본, 번체는 결과**다.

```
App/Resources/zh-Hans.lproj/Localizable.strings      ← 손으로 고치는 곳
            │  build_traditional.py (OpenCC s2twp)
            ▼
App/Resources/zh-Hant.lproj/Localizable.strings      ← 손대지 않는 곳
```

`zh-Hant` 파일 머리말에도 같은 말이 적혀 있다. 번체 문구를 고치고 싶으면
간체를 고친다.

## 변환하는 파일

| 간체 (원본) | 번체 (결과) |
|---|---|
| `App/Resources/zh-Hans.lproj/Localizable.strings` | `zh-Hant.lproj/Localizable.strings` |
| `App/Resources/zh-Hans.lproj/InfoPlist.strings` | `zh-Hant.lproj/InfoPlist.strings` |
| `docs/PRIVACY.zh-Hans.md` | `docs/PRIVACY.zh-Hant.md` |

`InfoPlist.strings` 는 사진·캘린더 권한 안내다. 앱이 고른 언어가 아니라 **시스템 언어**를
따라 읽히므로, 파일이 없으면 영어·중국어 기기에서도 한국어로 나온다.

문서는 OpenCC 가 못 바꾸는 대만 낱말(`識別符號`→識別碼, `許可權`→權限, `賬號`→帳號 …)을
`DOCUMENT_FIXES` 로 고친다. **문서에만 적용한다** — 앱 화면 사전은 이미 `日程·日曆·應用` 으로
통일되어 있어서, 거기까지 바꾸는 것은 보정표가 아니라 앱 전체의 용어 결정이다.

## 명령

```bash
pip install opencc-python-reimplemented          # 한 번만

python tools/localization/build_traditional.py          # 새로 만든다
python tools/localization/build_traditional.py --check  # 최신인지만 확인 (CI 용)
```

`--check` 는 파일을 쓰지 않고, 지금 파일이 간체에서 다시 만든 결과와 같은지만 본다.
간체를 고치고 번체를 다시 만들지 않으면 실패한다.

## OpenCC 를 `s2t` 가 아니라 `s2twp` 로 쓰는 이유

`s2t` 는 글자만 바꾼다. 그러면 대만 사용자에게 어색한 낱말이 남는다.

| 간체 | s2t | s2twp (이 스크립트) |
|---|---|---|
| 软件 | 軟件 | **軟體** |
| 信息 | 信息 | **資訊** |
| 默认 | 默認 | **預設** |
| 网络 | 網絡 | **網路** |

`OVERRIDES` 는 OpenCC 가 다룰 수 없는 몇몇 문구를 직접 정하는 자리다.

## 사전 파일의 규칙

- 키는 **한국어 원문**이다. 화면 문구는 `Text("설정")` 처럼 소스에 있는 한국어가
  그대로 키가 되고, 데이터는 `quote.<slug>.text` 처럼 내용을 가리키는 이름을 쓴다.
- 값이 비면 안 되고, 자리표시자(`%@`, `%d`, `%.1f`)의 개수가 키와 같아야 한다.
  `python tools/check_localization.py` 가 이 둘을 모두 검사한다.
- 사전에 없는 키는 한국어 원문으로 되돌아간다. 화면이 비거나 키 이름이 드러나지는
  않지만, 그 문장은 번역되지 않은 것이므로 검사기는 실패로 본다.
