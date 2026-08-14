"""
제공된 스크린샷 이미지로 OCR 직접 테스트
"""
import os, sys, re
import cv2
import numpy as np

import pytesseract
for _p in [
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
]:
    if os.path.exists(_p):
        pytesseract.pytesseract.tesseract_cmd = _p
        break

IMG_PATH = sys.argv[1] if len(sys.argv) > 1 else "test_game.png"
DEBUG_DIR = os.path.expanduser("~/Desktop/ww_debug")
os.makedirs(DEBUG_DIR, exist_ok=True)

img = cv2.imread(IMG_PATH)
if img is None:
    print(f"이미지 없음: {IMG_PATH}")
    sys.exit(1)

print(f"이미지: {img.shape[1]}x{img.shape[0]}")
hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

# 여러 임계값 시도
for v_min in [150, 160, 170, 180, 190]:
    lower = np.array([0, 0, v_min])
    upper = np.array([180, 80, 255])
    mask = cv2.inRange(hsv, lower, upper)

    # 모폴로지
    k1 = cv2.getStructuringElement(cv2.MORPH_RECT, (5,5))
    k2 = cv2.getStructuringElement(cv2.MORPH_RECT, (18,18))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN,  k1)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, k2)

    cv2.imwrite(os.path.join(DEBUG_DIR, f"mask_v{v_min}.png"), mask)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    vis = img.copy()
    words = []

    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if w < 40 or h < 20: continue
        if w/max(h,1) > 8: continue
        if w > img.shape[1]*0.85: continue

        # OCR
        pad = 6
        roi = img[max(0,y-pad):min(img.shape[0],y+h+pad),
                  max(0,x-pad):min(img.shape[1],x+w+pad)]
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(3.0, (4,4))
        gray = clahe.apply(gray)
        big  = cv2.resize(gray, None, fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
        _, binary = cv2.threshold(big, 0, 255, cv2.THRESH_BINARY+cv2.THRESH_OTSU)
        if np.mean(binary) < 127:
            binary = cv2.bitwise_not(binary)

        t = pytesseract.image_to_string(
            binary, lang="eng",
            config="--psm 8 --oem 3 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'-"
        ).strip()
        t = re.sub(r"[^A-Za-z'\-]+","",t).strip()
        if t:
            words.append((x, t))
            cv2.rectangle(vis, (x,y),(x+w,y+h),(0,255,0),2)
            cv2.putText(vis, t, (x, y-6), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,0), 2)

    words.sort(key=lambda w: w[0])
    result = [w[1] for w in words]
    print(f"V_MIN={v_min}: {result}")
    cv2.imwrite(os.path.join(DEBUG_DIR, f"detect_v{v_min}.png"), vis)

print(f"\n디버그 이미지: {DEBUG_DIR}")
