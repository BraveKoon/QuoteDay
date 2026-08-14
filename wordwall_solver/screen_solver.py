"""
Wordwall Unjumble 화면 인식 + 마우스 자동 풀이 (v2)
의존: pip install mss pillow pytesseract pyautogui opencv-python
Tesseract OCR 별도 설치: https://github.com/UB-Mannheim/tesseract/wiki
"""

import sys, os, time, threading, re
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox

# ── 의존 패키지 import ────────────────────────────────────
try:
    import mss
    import numpy as np
    import cv2
    from PIL import Image, ImageTk
    import pyautogui
    pyautogui.FAILSAFE = True  # 마우스 왼쪽상단 → 긴급 중지
    DEPS_OK = True
    MISSING = ""
except ImportError as _e:
    DEPS_OK = False
    MISSING = str(_e)

try:
    import pytesseract
    for _p in [
        r"C:\Program Files\Tesseract-OCR\tesseract.exe",
        r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
    ]:
        if os.path.exists(_p):
            pytesseract.pytesseract.tesseract_cmd = _p
            break
    OCR_OK = True
except ImportError:
    OCR_OK = False

# ──────────────────────────────────────────────────────────
# 설정 상수
# ──────────────────────────────────────────────────────────
CFG = dict(
    DRAG_DURATION   = 0.4,   # 카드 드래그 시간(초)
    AFTER_DROP      = 0.7,   # 드래그 후 대기(초)
    AFTER_QUESTION  = 2.5,   # 새 문제 로드 대기(초)
    CAPTURE_FPS     = 3,     # 변화 감지 캡처 FPS
    CHANGE_THRESH   = 25,    # 화면 변화 감지 임계값
    # 카드 흰색 탐지 HSV 범위 (Wordwall 카드: 밝은 흰/회색)
    WHITE_V_MIN     = 170,   # Value 최솟값 (밝기)
    WHITE_S_MAX     = 70,    # Saturation 최댓값 (채도 낮음=흰색)
    CARD_MIN_W      = 35,    # 카드 최소 너비(px, 캡처 기준)
    CARD_MIN_H      = 20,    # 카드 최소 높이(px)
    CARD_MAX_RATIO  = 7.0,   # 가로:세로 최대 비율
    # 디버그: 탐지된 카드 이미지를 저장할지 여부
    DEBUG_SAVE      = True,
    DEBUG_DIR       = os.path.expanduser("~/Desktop/ww_debug"),
)

# ──────────────────────────────────────────────────────────
# 카드 탐지 (흰색 마스크 기반 - Wordwall 특화)
# ──────────────────────────────────────────────────────────

def detect_cards(img_bgr, debug_prefix=None):
    """
    카드 탐지 - 두 가지 스타일 자동 감지:
      A) 흰 배경 + 파란 카드 (새 스타일)  ← 현재 게임
      B) 갈색 코르크 + 흰 카드 (이전 스타일)
    반환: [(x, y, w, h, text), ...] 좌→우 정렬
    """
    h_img, w_img = img_bgr.shape[:2]
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)

    # ── 스타일 A: 파란/어두운 카드 마스크 ────────────────
    # Wordwall 파란 카드: H=200~230, S=30~100, V=60~130
    lower_blue = np.array([95,  25,  50])
    upper_blue = np.array([135, 120, 160])
    mask_blue = cv2.inRange(hsv, lower_blue, upper_blue)

    # ── 스타일 B: 흰색 카드 마스크 ───────────────────────
    lower_white = np.array([0,  0,   CFG["WHITE_V_MIN"]])
    upper_white = np.array([180, CFG["WHITE_S_MAX"], 255])
    mask_white = cv2.inRange(hsv, lower_white, upper_white)

    # 어떤 스타일인지 자동 판별 (더 많은 픽셀을 커버하는 마스크 선택)
    score_blue  = cv2.countNonZero(mask_blue)
    score_white = cv2.countNonZero(mask_white)

    # 흰 배경 화면은 white 픽셀이 압도적으로 많으므로
    # blue 마스크가 일정 이상 검출될 때만 스타일 A로 판단
    if score_blue > 500:
        mask = mask_blue
        card_style = "파란카드"
    else:
        mask = mask_white
        card_style = "흰카드"

    # 모폴로지: 작은 노이즈 제거 후 카드 내부 채우기
    k_open  = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    k_close = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN,  k_open)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, k_close)

    if debug_prefix and CFG["DEBUG_SAVE"]:
        os.makedirs(CFG["DEBUG_DIR"], exist_ok=True)
        cv2.imwrite(os.path.join(CFG["DEBUG_DIR"], f"{debug_prefix}_mask.png"), mask)
        cv2.imwrite(os.path.join(CFG["DEBUG_DIR"], f"{debug_prefix}_raw.png"), img_bgr)

    # ── 윤곽선 탐지 ──────────────────────────────────────
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    cards = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if w < CFG["CARD_MIN_W"] or h < CFG["CARD_MIN_H"]: continue
        if w / max(h, 1) > CFG["CARD_MAX_RATIO"]: continue
        if w > w_img * 0.85 or h > h_img * 0.85: continue  # 너무 크면 제외

        # ── 카드 영역 OCR ────────────────────────────────
        text = ocr_card(img_bgr, x, y, w, h)
        text = fix_ocr_word(text) if text else None
        if text:
            cards.append((x, y, w, h, text))

    # 좌→우 정렬, 겹침 제거
    cards.sort(key=lambda c: c[0])
    cards = remove_overlapping(cards)

    # ── 크기 기반 필터: 카드들의 중간값 높이로 노이즈 제거 ──
    cards = filter_by_size(cards)

    if debug_prefix and CFG["DEBUG_SAVE"]:
        vis = img_bgr.copy()
        for (x, y, w, h, t) in cards:
            cv2.rectangle(vis, (x, y), (x+w, y+h), (0, 255, 0), 2)
            cv2.putText(vis, t, (x, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0,255,0), 2)
        cv2.imwrite(os.path.join(CFG["DEBUG_DIR"], f"{debug_prefix}_detected.png"), vis)

    return cards


def ocr_card(img_bgr, x, y, w, h, debug_path=None):
    """
    카드 영역 OCR.
    Wordwall 카드: 흰 배경 + 진한 남색 텍스트
    여러 전처리 방식을 시도해 가장 신뢰도 높은 단어를 반환.
    """
    pad = 12
    h_img, w_img = img_bgr.shape[:2]
    x1 = max(0, x - pad); y1 = max(0, y - pad)
    x2 = min(w_img, x + w + pad); y2 = min(h_img, y + h + pad)
    roi = img_bgr[y1:y2, x1:x2]

    WHITELIST = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'- "

    def tess(img_gray, psm):
        # 4배 확대 후 흰 여백 추가
        big = cv2.resize(img_gray, None, fx=4, fy=4, interpolation=cv2.INTER_LANCZOS4)
        bordered = cv2.copyMakeBorder(big, 30, 30, 30, 30, cv2.BORDER_CONSTANT, value=255)
        cfg = f"--psm {psm} --oem 3 -c tessedit_char_whitelist={WHITELIST}"
        t = pytesseract.image_to_string(bordered, lang="eng", config=cfg)
        t = re.sub(r"[^A-Za-z'\- ]+", "", t).strip()
        tokens = t.split()
        return tokens[0] if tokens else ""

    candidates = []
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)

    # ── 카드 스타일 자동 감지 ────────────────────────────
    # 파란 카드: 평균 밝기가 낮고 채도 높음 → 흰 텍스트 추출
    # 흰 카드: 평균 밝기가 높음 → 어두운 텍스트 추출
    mean_v = np.mean(gray)
    is_dark_card = mean_v < 140   # 파란/어두운 카드

    # ── 전처리 1: Otsu 이진화 ────────────────────────────
    _, bin1 = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # 파란 카드 → 반전해서 흰 텍스트를 검정으로
    if is_dark_card:
        bin1 = cv2.bitwise_not(bin1)
    elif np.mean(bin1) < 127:
        bin1 = cv2.bitwise_not(bin1)

    # ── 전처리 2: 파란카드 전용 - 밝은 픽셀(흰 텍스트) 추출 ──
    if is_dark_card:
        # 밝기 임계 200 이상 → 흰 텍스트
        _, bin2 = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    else:
        # 흰카드: 파란 채널에서 어두운 텍스트 추출
        b_ch = roi[:, :, 0]
        _, bin2 = cv2.threshold(b_ch, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        if np.mean(bin2) < 127:
            bin2 = cv2.bitwise_not(bin2)

    # ── 전처리 3: CLAHE + 적응형 임계값 ─────────────────
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(4, 4))
    gray_c = clahe.apply(gray)
    bin3 = cv2.adaptiveThreshold(gray_c, 255,
                                  cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                  cv2.THRESH_BINARY, 21, 8)
    if is_dark_card:
        bin3 = cv2.bitwise_not(bin3)

    if debug_path:
        cv2.imwrite(debug_path + "_bin1.png", bin1)
        cv2.imwrite(debug_path + "_bin2.png", bin2)
        cv2.imwrite(debug_path + "_bin3.png", bin3)

    # 각 전처리 × 각 PSM 조합 시도
    for binary in (bin1, bin2, bin3):
        for psm in (8, 7, 6):
            word = tess(binary, psm)
            if len(word) >= 1:
                candidates.append(word)

    if not candidates:
        return None

    # 가장 많이 나온 결과 반환 (다수결)
    from collections import Counter
    best = Counter(candidates).most_common(1)[0][0]
    return best


def filter_by_size(cards):
    """
    카드들의 높이 중간값을 기준으로 너무 작은 것(노이즈) 제거.
    실제 단어 카드는 서로 비슷한 크기여야 함.
    """
    if len(cards) < 2:
        return cards
    heights = sorted([c[3] for c in cards])
    median_h = heights[len(heights) // 2]
    # 중간값의 50% 미만인 카드는 노이즈로 제거
    filtered = [c for c in cards if c[3] >= median_h * 0.5]
    return filtered


def remove_overlapping(cards, iou_thr=0.4):
    """겹치는 카드 제거 (큰 것 유지)"""
    result, used = [], [False] * len(cards)
    for i, ci in enumerate(cards):
        if used[i]: continue
        xi1, yi1, wi, hi, _ = ci
        for j in range(i+1, len(cards)):
            if used[j]: continue
            xj1, yj1, wj, hj, _ = cards[j]
            ix = max(0, min(xi1+wi, xj1+wj) - max(xi1, xj1))
            iy = max(0, min(yi1+hi, yj1+hj) - max(yi1, yj1))
            inter = ix * iy
            union = wi*hi + wj*hj - inter
            if union > 0 and inter/union > iou_thr:
                if wi*hi < wj*hj: used[i] = True; break
                else: used[j] = True
        if not used[i]: result.append(ci)
    return result


def fix_ocr_word(word):
    """
    흔한 OCR 오인식 교정.
    - 단일 글자: O→I, l→I, 0→I
    - 어포스트로피/특수문자 제거 후 재시도
    - 공백/특수문자만 남은 경우 None 반환
    """
    # 특수문자만 있는 단어 제거
    clean = re.sub(r"[^A-Za-z]", "", word)
    if not clean:
        return None

    # 단일 글자 교정
    if len(clean) == 1:
        mapping = {"O": "I", "o": "I", "l": "I", "0": "I", "1": "I", "|": "I"}
        clean = mapping.get(clean, clean)

    # 어포스트로피가 끝에 붙은 경우 제거 (got' → got)
    clean = clean.rstrip("'")

    return clean if clean else None


def match_answer(card_words, sentences):
    """
    카드 단어 multiset ↔ 정답 문장 multiset 매칭.
    OCR 오차를 고려해 퍼지 매칭도 병행.
    """
    def normalize(w):
        return re.sub(r"[^a-z]", "", w.lower())

    card_keys = sorted(normalize(w) for w in card_words)

    # 1차: 완전 일치
    for sent in sentences:
        words = sent.strip().split()
        if sorted(normalize(w) for w in words) == card_keys:
            return [w.lower() for w in words]

    # 2차: 단어 수가 같고, 각 단어가 포함 관계인 문장 (OCR 일부 누락 대비)
    n = len(card_words)
    for sent in sentences:
        words = sent.strip().split()
        if len(words) != n:
            continue
        sent_keys = sorted(normalize(w) for w in words)
        # 카드 단어가 정답 단어에 포함되거나 정답 단어가 카드 단어에 포함
        matches = 0
        for ck in card_keys:
            for sk in sent_keys:
                if ck in sk or sk in ck:
                    matches += 1
                    break
        if matches == n:
            return [w.lower() for w in words]

    return None


# ──────────────────────────────────────────────────────────
# 영역 선택 오버레이
# ──────────────────────────────────────────────────────────
class RegionSelector(tk.Toplevel):
    def __init__(self, master, callback):
        super().__init__(master)
        self.callback = callback
        self.attributes("-fullscreen", True)
        self.attributes("-alpha", 0.28)
        self.attributes("-topmost", True)
        self.configure(bg="black", cursor="crosshair")
        self.canvas = tk.Canvas(self, bg="black", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        tk.Label(self.canvas,
                 text="드래그하여 카드 영역 선택  (ESC = 취소)",
                 font=("맑은 고딕", 18, "bold"), bg="black", fg="white"
                 ).place(relx=0.5, rely=0.05, anchor="center")
        self.rect_id = None
        self.sx = self.sy = 0
        self.canvas.bind("<ButtonPress-1>",   self._start)
        self.canvas.bind("<B1-Motion>",       self._drag)
        self.canvas.bind("<ButtonRelease-1>", self._end)
        self.bind("<Escape>", lambda e: self.destroy())

    def _start(self, e):
        self.sx, self.sy = e.x_root, e.y_root
        if self.rect_id: self.canvas.delete(self.rect_id)

    def _drag(self, e):
        if self.rect_id: self.canvas.delete(self.rect_id)
        ox, oy = self.winfo_rootx(), self.winfo_rooty()
        self.rect_id = self.canvas.create_rectangle(
            self.sx - ox, self.sy - oy, e.x, e.y,
            outline="#89b4fa", width=3, fill="#89b4fa", stipple="gray25")

    def _end(self, e):
        x1, y1 = min(self.sx, e.x_root), min(self.sy, e.y_root)
        x2, y2 = max(self.sx, e.x_root), max(self.sy, e.y_root)
        self.destroy()
        if x2-x1 > 30 and y2-y1 > 30:
            self.callback({"left": x1, "top": y1, "width": x2-x1, "height": y2-y1})


# ──────────────────────────────────────────────────────────
# 풀이 엔진
# ──────────────────────────────────────────────────────────
class SolverEngine:
    def __init__(self, region, sentences, max_q, log_fn):
        self.region    = region
        self.sentences = sentences
        self.max_q     = max_q
        self.log       = log_fn
        self._stop     = False
        self._prev_gray = None

    def stop(self): self._stop = True

    def run(self):
        self.log("=== 화면 인식 풀이 시작 ===")
        self.log(f"캡처 영역: {self.region}")
        self.log("긴급 중지: 마우스를 화면 왼쪽 상단으로 이동")
        if CFG["DEBUG_SAVE"]:
            self.log(f"디버그 이미지 → {CFG['DEBUG_DIR']}")

        with mss.mss() as sct:
            for q in range(self.max_q):
                if self._stop: break
                self.log(f"\n── 문제 {q+1} / {self.max_q} ──")

                # 새 문제 대기
                if q > 0:
                    self.log("새 문제 대기 중...")
                    self._wait_change(sct)
                    time.sleep(CFG["AFTER_QUESTION"])

                # 카드 탐지 (최대 3회 재시도)
                cards = []
                for attempt in range(3):
                    frame = self._capture(sct)
                    prefix = f"q{q+1}_try{attempt+1}"
                    cards = detect_cards(frame, debug_prefix=prefix)
                    self.log(f"  탐지 시도 {attempt+1}: {[c[4] for c in cards]}")
                    if len(cards) >= 2:
                        break
                    time.sleep(0.8)

                if len(cards) < 2:
                    self.log("카드 탐지 실패. 종료.")
                    break

                words = [c[4] for c in cards]
                self.log(f"탐지된 단어: {words}")

                # 정답 매칭
                target = match_answer(words, self.sentences)
                if not target:
                    self.log(f"정답 매칭 실패: {sorted(words)}")
                    self.log("→ 정답 문장 목록을 확인하거나, 디버그 이미지를 보세요.")
                    break
                self.log(f"정답 순서: {target}")

                # 드래그 정렬
                if not self._sort_cards(sct, target):
                    break
                self.log(f"문제 {q+1} 완료!")

        self.log("\n=== 풀이 종료 ===")

    # ── 캡처 ──────────────────────────────────────────────
    def _capture(self, sct):
        shot = sct.grab(self.region)
        img  = np.array(shot)
        return cv2.cvtColor(img, cv2.COLOR_BGRA2BGR)

    # ── 화면 변화 감지 ────────────────────────────────────
    def _wait_change(self, sct, timeout=8.0):
        end = time.time() + timeout
        while time.time() < end:
            if self._stop: return
            frame = self._capture(sct)
            gray  = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            if self._prev_gray is not None:
                diff = cv2.absdiff(self._prev_gray, gray)
                if diff.mean() > CFG["CHANGE_THRESH"]:
                    self._prev_gray = gray; return
            self._prev_gray = gray
            time.sleep(1.0 / CFG["CAPTURE_FPS"])

    # ── selection-sort 드래그 ─────────────────────────────
    def _sort_cards(self, sct, target):
        for i in range(len(target)):
            if self._stop: return False

            # 매번 화면 재캡처
            frame = self._capture(sct)
            self._prev_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            cards = detect_cards(frame)

            if not cards:
                self.log("드래그 중 카드 소실"); return False

            words = [c[4].lower().strip("'-") for c in cards]
            tgt_w = target[i].lower().strip("'-")

            if words[i] == tgt_w: continue  # 이미 제자리

            # 목표 단어 위치 탐색
            src_idx = next((j for j in range(i, len(words)) if words[j] == tgt_w), None)
            if src_idx is None:
                self.log(f"'{target[i]}' 카드 없음"); return False

            r = self.region
            def scr(card):
                x, y, w, h, _ = card
                return (r["left"] + x + w//2, r["top"] + y + h//2)

            fp, tp = scr(cards[src_idx]), scr(cards[i])
            self.log(f"  [{src_idx}]'{target[i]}' → [{i}]  {fp}→{tp}")

            try:
                pyautogui.moveTo(fp[0], fp[1], duration=0.12)
                pyautogui.mouseDown(button="left")
                time.sleep(0.1)
                pyautogui.moveTo(tp[0], tp[1],
                                 duration=CFG["DRAG_DURATION"],
                                 tween=pyautogui.easeInOutQuad)
                time.sleep(0.06)
                pyautogui.mouseUp(button="left")
            except pyautogui.FailSafeException:
                self.log("긴급 중지!"); return False

            time.sleep(CFG["AFTER_DROP"])
        return True


# ──────────────────────────────────────────────────────────
# GUI
# ──────────────────────────────────────────────────────────
class App(tk.Tk):
    BG, FG      = "#1e1e2e", "#cdd6f4"
    ACCENT      = "#89b4fa"
    GREEN, RED  = "#a6e3a1", "#f38ba8"
    ENTRY       = "#313244"

    def __init__(self):
        super().__init__()
        self.title("Wordwall Unjumble - 화면 인식 풀이 v2")
        self.configure(bg=self.BG)
        self.resizable(False, False)
        self.region = None
        self.engine = None
        self._build()
        self._check_deps()
        self.protocol("WM_DELETE_WINDOW", self._quit)

    def _build(self):
        F  = ("맑은 고딕", 10)
        FB = ("맑은 고딕", 11, "bold")

        tk.Label(self, text="🖥️  Wordwall 화면 인식 자동 풀이",
                 font=("맑은 고딕", 14, "bold"), bg=self.BG, fg=self.ACCENT
                 ).pack(pady=(14, 2))
        tk.Label(self, text="화면을 실시간으로 읽어 마우스를 자동으로 움직입니다.",
                 font=F, bg=self.BG, fg="#a6adc8").pack(pady=(0, 8))

        # ① 영역 선택
        f1 = tk.LabelFrame(self, text=" ① 카드 영역 선택 ",
                            font=F, bg=self.BG, fg=self.ACCENT, bd=1)
        f1.pack(fill="x", padx=14, pady=3)
        self.region_lbl = tk.Label(f1, text="❌ 미선택",
                                   font=F, bg=self.BG, fg=self.RED)
        self.region_lbl.pack(side="left", padx=10, pady=6)
        tk.Button(f1, text="화면에서 영역 드래그",
                  font=FB, bg=self.ACCENT, fg=self.BG, relief="flat",
                  padx=10, pady=3, cursor="hand2",
                  command=self._select_region).pack(side="right", padx=10, pady=6)

        # ② 정답 문장
        f2 = tk.LabelFrame(self, text=" ② 정답 문장 (쉼표 구분) ",
                            font=F, bg=self.BG, fg=self.ACCENT, bd=1)
        f2.pack(fill="x", padx=14, pady=3)
        tk.Label(f2, text="예) I got nothing to lose, It is not easy to walk a dog",
                 font=("맑은 고딕", 8), bg=self.BG, fg="#6c7086").pack(anchor="w", padx=8)
        self.sentences_text = tk.Text(f2, font=("Consolas", 9),
                                      bg=self.ENTRY, fg=self.FG,
                                      insertbackground=self.FG,
                                      relief="flat", height=4, wrap="word")
        self.sentences_text.pack(fill="x", padx=8, pady=(2, 8))

        # ③ 설정
        f3 = tk.LabelFrame(self, text=" ③ 설정 ",
                            font=F, bg=self.BG, fg=self.ACCENT, bd=1)
        f3.pack(fill="x", padx=14, pady=3)
        inn = tk.Frame(f3, bg=self.BG)
        inn.pack(fill="x", padx=8, pady=6)

        tk.Label(inn, text="문제 수:", font=F, bg=self.BG, fg=self.FG).pack(side="left")
        self.q_var = tk.IntVar(value=10)
        tk.Spinbox(inn, from_=1, to=50, textvariable=self.q_var,
                   font=F, bg=self.ENTRY, fg=self.FG,
                   buttonbackground=self.ENTRY, relief="flat", width=5
                   ).pack(side="left", padx=(4, 16))

        tk.Label(inn, text="드래그 속도(초):", font=F, bg=self.BG, fg=self.FG).pack(side="left")
        self.speed_var = tk.DoubleVar(value=0.4)
        tk.Spinbox(inn, from_=0.1, to=2.0, increment=0.1,
                   textvariable=self.speed_var, format="%.1f",
                   font=F, bg=self.ENTRY, fg=self.FG,
                   buttonbackground=self.ENTRY, relief="flat", width=5
                   ).pack(side="left", padx=(4, 16))

        self.debug_var = tk.BooleanVar(value=True)
        tk.Checkbutton(inn, text="디버그 이미지 저장",
                       variable=self.debug_var,
                       font=F, bg=self.BG, fg=self.FG,
                       selectcolor=self.ENTRY, activebackground=self.BG
                       ).pack(side="left")

        # HSV 슬라이더 (카드 밝기 임계 조정)
        f4 = tk.LabelFrame(self, text=" 카드 인식 감도 (밝기 임계, 낮출수록 더 많이 탐지) ",
                            font=F, bg=self.BG, fg=self.ACCENT, bd=1)
        f4.pack(fill="x", padx=14, pady=3)
        sl_frm = tk.Frame(f4, bg=self.BG)
        sl_frm.pack(fill="x", padx=8, pady=4)
        tk.Label(sl_frm, text="밝기 최소값:", font=F, bg=self.BG, fg=self.FG).pack(side="left")
        self.v_min_var = tk.IntVar(value=170)
        self.v_min_lbl = tk.Label(sl_frm, text="170", font=F, bg=self.BG, fg=self.ACCENT, width=4)
        self.v_min_lbl.pack(side="right", padx=4)
        sl = tk.Scale(sl_frm, from_=80, to=240, orient="horizontal",
                      variable=self.v_min_var, bg=self.BG, fg=self.FG,
                      troughcolor=self.ENTRY, highlightthickness=0, length=300,
                      command=lambda v: self.v_min_lbl.config(text=v))
        sl.pack(side="left", padx=4)

        # 테스트 버튼
        ft = tk.Frame(self, bg=self.BG)
        ft.pack(fill="x", padx=14, pady=(0,2))
        tk.Button(ft, text="🔍 지금 화면 테스트 (카드 탐지 확인)",
                  font=F, bg="#45475a", fg=self.FG, relief="flat",
                  padx=8, pady=3, cursor="hand2",
                  command=self._test_capture).pack(side="left")
        tk.Label(ft, text="← 풀이 전 카드가 잘 인식되는지 확인하세요",
                 font=("맑은 고딕", 8), bg=self.BG, fg="#6c7086").pack(side="left", padx=8)

        # 버튼
        fb = tk.Frame(self, bg=self.BG)
        fb.pack(pady=8)
        self.btn_start = tk.Button(fb, text="▶  자동 풀이 시작",
                                   font=FB, bg=self.ACCENT, fg=self.BG,
                                   relief="flat", padx=16, pady=6, cursor="hand2",
                                   command=self._start)
        self.btn_start.pack(side="left", padx=6)
        self.btn_stop = tk.Button(fb, text="■  중지",
                                  font=FB, bg=self.RED, fg=self.BG,
                                  relief="flat", padx=14, pady=6, cursor="hand2",
                                  state="disabled", command=self._stop)
        self.btn_stop.pack(side="left", padx=6)

        # 진행 바
        self.bar = ttk.Progressbar(self, mode="indeterminate", length=480)
        self.bar.pack(pady=(0, 4))

        # 로그
        tk.Label(self, text="로그  (마우스 왼쪽 상단 모서리 = 긴급 중지)",
                 font=("맑은 고딕", 8), bg=self.BG, fg="#6c7086").pack(anchor="w", padx=14)
        self.log_box = scrolledtext.ScrolledText(
            self, font=("Consolas", 9), bg="#11111b", fg=self.GREEN,
            relief="flat", height=11, state="disabled")
        self.log_box.pack(fill="both", expand=True, padx=14, pady=(0, 14))

    def _check_deps(self):
        if not DEPS_OK:
            self._log(f"⚠ 패키지 미설치: {MISSING}", self.RED)
            self._log("pip install mss pillow pytesseract pyautogui opencv-python")
        if not OCR_OK:
            self._log("⚠ pytesseract 미설치", self.RED)
        if OCR_OK and DEPS_OK:
            try:
                pytesseract.get_tesseract_version()
                self._log("✓ Tesseract OCR 감지 완료")
            except Exception:
                self._log("⚠ Tesseract 바이너리 없음 → https://github.com/UB-Mannheim/tesseract/wiki", self.RED)

    def _test_capture(self):
        """지금 즉시 캡처 → 카드 탐지 → 결과 팝업"""
        if not self.region:
            messagebox.showwarning("영역 없음", "① 먼저 카드 영역을 드래그로 선택하세요."); return
        if not DEPS_OK or not OCR_OK:
            messagebox.showerror("오류", "패키지 설치 필요"); return

        CFG["WHITE_V_MIN"] = self.v_min_var.get()
        CFG["DEBUG_SAVE"]  = self.debug_var.get()

        self._log("테스트 캡처 중...")
        with mss.mss() as sct:
            shot = sct.grab(self.region)
            frame = cv2.cvtColor(np.array(shot), cv2.COLOR_BGRA2BGR)

        cards = detect_cards(frame, debug_prefix="test")
        words = [c[4] for c in cards]
        self._log(f"탐지 결과: {words}")

        # 결과 시각화 (카드 박스 표시 후 팝업)
        vis = frame.copy()
        for (x, y, w, h, t) in cards:
            cv2.rectangle(vis, (x, y), (x+w, y+h), (0, 255, 80), 3)
            cv2.putText(vis, t, (x+4, y+h+22),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 80), 2)

        # tkinter 팝업으로 이미지 표시
        pil_img = Image.fromarray(cv2.cvtColor(vis, cv2.COLOR_BGR2RGB))
        # 팝업 크기 제한
        max_w, max_h = 900, 500
        pil_img.thumbnail((max_w, max_h), Image.LANCZOS)

        popup = tk.Toplevel(self)
        popup.title(f"탐지 결과: {words}")
        popup.configure(bg=self.BG)
        tk_img = ImageTk.PhotoImage(pil_img)
        lbl = tk.Label(popup, image=tk_img, bg=self.BG)
        lbl.image = tk_img
        lbl.pack(padx=10, pady=10)

        result_txt = "  /  ".join(words) if words else "탐지된 카드 없음"
        tk.Label(popup, text=f"탐지 단어: {result_txt}",
                 font=("맑은 고딕", 11, "bold"), bg=self.BG,
                 fg=self.GREEN if words else self.RED).pack(pady=(0, 6))

        if CFG["DEBUG_SAVE"]:
            tk.Label(popup, text=f"디버그 이미지: {CFG['DEBUG_DIR']}",
                     font=("맑은 고딕", 8), bg=self.BG, fg="#6c7086").pack(pady=(0, 8))

        # 밝기 임계 조정 힌트
        if len(words) < 2:
            tk.Label(popup,
                     text="카드가 적게 탐지됐다면: '밝기 임계값' 슬라이더를 낮춰보세요.",
                     font=("맑은 고딕", 9), bg=self.BG, fg="#fab387").pack(pady=(0,8))

    def _select_region(self):
        self.withdraw()
        time.sleep(0.25)
        def on_sel(r):
            self.deiconify()
            self.region = r
            self.region_lbl.config(
                text=f"✓ ({r['left']},{r['top']})  {r['width']}×{r['height']}px",
                fg=self.GREEN)
            self._log(f"영역 선택: {r}")
        def on_cancel(): self.deiconify()
        sel = RegionSelector(self, on_sel)
        sel.protocol("WM_DELETE_WINDOW", on_cancel)

    def _log(self, msg, color=None):
        self.log_box.config(state="normal")
        tag = f"t{abs(hash(color or ''))}"
        self.log_box.tag_config(tag, foreground=color or self.GREEN)
        self.log_box.insert("end", msg + "\n", tag)
        self.log_box.see("end")
        self.log_box.config(state="disabled")

    def _start(self):
        if not DEPS_OK or not OCR_OK:
            messagebox.showerror("오류", "패키지 설치 필요. 로그 확인."); return
        if not self.region:
            messagebox.showwarning("영역 없음", "① 카드 영역을 먼저 드래그로 선택하세요."); return
        raw = self.sentences_text.get("1.0", "end").strip()
        if not raw:
            messagebox.showwarning("문장 없음", "② 정답 문장을 입력하세요."); return

        sentences = [s.strip() for s in raw.split(",") if s.strip()]
        self._log(f"정답 문장 {len(sentences)}개 등록")

        CFG["DRAG_DURATION"] = self.speed_var.get()
        CFG["WHITE_V_MIN"]   = self.v_min_var.get()
        CFG["DEBUG_SAVE"]    = self.debug_var.get()

        self.btn_start.config(state="disabled")
        self.btn_stop.config(state="normal")
        self.bar.start(12)

        self.engine = SolverEngine(
            region=self.region,
            sentences=sentences,
            max_q=self.q_var.get(),
            log_fn=lambda m: self.after(0, lambda msg=m: self._log(msg))
        )
        threading.Thread(target=self._run_engine, daemon=True).start()

    def _run_engine(self):
        try:
            self.engine.run()
        except Exception as e:
            self.after(0, lambda: self._log(f"오류: {e}", self.RED))
        finally:
            self.after(0, self._done)

    def _stop(self):
        if self.engine: self.engine.stop()
        self._log("중지 요청...")

    def _done(self):
        self.bar.stop()
        self.btn_start.config(state="normal")
        self.btn_stop.config(state="disabled")

    def _quit(self):
        if self.engine: self.engine.stop()
        self.destroy()


# ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    App().mainloop()
