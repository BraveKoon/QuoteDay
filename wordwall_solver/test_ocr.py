"""
OCR 테스트 스크립트 - 스크린샷 파일로 카드 탐지 확인
사용: python test_ocr.py <이미지파일.png>
"""
import sys, os
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

# Tesseract 경로 설정
import pytesseract
for _p in [
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
]:
    if os.path.exists(_p):
        pytesseract.pytesseract.tesseract_cmd = _p
        break

from screen_solver import detect_cards, CFG

def test_image(path):
    print(f"이미지 로드: {path}")
    img = cv2.imread(path)
    if img is None:
        print("이미지를 읽을 수 없습니다!")
        return

    print(f"이미지 크기: {img.shape[1]}x{img.shape[0]}")

    # 다양한 밝기 임계값으로 시도
    for v_min in [140, 160, 170, 185, 200]:
        CFG["WHITE_V_MIN"] = v_min
        CFG["DEBUG_SAVE"] = True
        CFG["DEBUG_DIR"] = os.path.expanduser(f"~/Desktop/ww_debug/vmin{v_min}")

        cards = detect_cards(img, debug_prefix=f"test_vmin{v_min}")
        words = [c[4] for c in cards]
        print(f"  V_MIN={v_min}: {len(cards)}개 탐지 → {words}")

    print(f"\n디버그 이미지 저장됨: ~/Desktop/ww_debug/")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # 스크린샷 직접 찍어서 테스트
        print("사용법: python test_ocr.py <이미지.png>")
        print("또는 게임 화면을 스크린샷 찍어서 경로를 인자로 주세요.")
        print("\n현재 화면 캡처로 테스트하려면 Enter...")
        input()
        import mss
        with mss.mss() as sct:
            shot = sct.grab(sct.monitors[1])
            img_arr = np.array(shot)
            img = cv2.cvtColor(img_arr, cv2.COLOR_BGRA2BGR)
            cv2.imwrite("test_capture.png", img)
            print("test_capture.png 저장됨")
            CFG["DEBUG_SAVE"] = True
            CFG["DEBUG_DIR"] = os.path.expanduser("~/Desktop/ww_debug/fullscreen")
            cards = detect_cards(img, debug_prefix="fullscreen")
            print(f"탐지: {[c[4] for c in cards]}")
    else:
        test_image(sys.argv[1])
