"""
Wordwall Unjumble 자동 풀이 프로그램
실행: python main.py
EXE 빌드: pyinstaller --onefile --windowed --name WordwallSolver main.py
"""

import sys
import time
import threading
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox

# selenium 설치 여부 체크
try:
    from selenium import webdriver
    from selenium.webdriver.chrome.service import Service
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.common.action_chains import ActionChains
    import selenium
    SELENIUM_OK = True
except ImportError:
    SELENIUM_OK = False

# ──────────────────────────────────────────────
# 브라우저에 주입할 자동 풀이 JavaScript
# ──────────────────────────────────────────────
SOLVER_JS = r"""
(function() {
  // 설정
  const DRAG_STEPS = 12;
  const STEP_DELAY = 8;
  const DROP_DELAY = 700;
  const NEXT_DELAY = 1000;
  const QUESTION_DELAY = 2500;
  const MAX_Q = __MAX_Q__;

  const CARD_SELECTORS = [
    '.tile', '[class*="tile"]', '[class*="card"]',
    '[class*="word"]', '[draggable="true"]'
  ];
  const NEXT_SELECTORS = [
    'button[class*="next"]', '[class*="nextButton"]',
    '[class*="next-button"]', 'button[aria-label*="next" i]',
    '[class*="continue"]', '[class*="Next"]'
  ];

  const log = (msg) => {
    console.log('[Unjumble] ' + msg);
    const el = document.getElementById('__unjumble_log__');
    if (el) { el.value += msg + '\n'; el.scrollTop = el.scrollHeight; }
  };

  // 로그 오버레이 생성
  const overlay = document.createElement('div');
  overlay.style.cssText = 'position:fixed;top:10px;right:10px;z-index:99999;' +
    'background:rgba(0,0,0,0.82);color:#0f0;font:12px monospace;' +
    'padding:10px;border-radius:8px;width:360px;max-height:220px;overflow:hidden;';
  overlay.innerHTML = '<div style="color:#ff0;font-weight:bold;margin-bottom:4px">🤖 Unjumble Solver</div>' +
    '<textarea id="__unjumble_log__" readonly style="width:100%;height:180px;background:transparent;' +
    'color:#0f0;border:none;resize:none;font:11px monospace;outline:none"></textarea>';
  document.body.appendChild(overlay);

  const sleep = ms => new Promise(r => setTimeout(r, ms));

  function centerOf(el) {
    const r = el.getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  }

  function pointerEv(type, x, y) {
    return new PointerEvent(type, {
      bubbles: true, cancelable: true,
      clientX: x, clientY: y,
      pointerId: 1, pointerType: 'mouse', isPrimary: true
    });
  }
  function mouseEv(type, x, y) {
    return new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, clientY: y });
  }

  function parseAnswers() {
    const selectors = [
      'meta[name="description"]',
      'meta[property="og:description"]',
      'meta[name="og:description"]',
      'meta[itemprop="description"]'
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (!el) continue;
      const content = el.getAttribute('content') || '';
      const sentences = content.split(',').map(s => s.trim()).filter(Boolean);
      if (sentences.length > 0) {
        log('메타 태그에서 ' + sentences.length + '개 문장 파싱');
        return sentences;
      }
    }
    // 페이지 내 script 태그에서 JSON 데이터 탐색
    const scripts = document.querySelectorAll('script');
    for (const sc of scripts) {
      const txt = sc.textContent;
      if (txt.includes('unjumble') || txt.includes('sentence') || txt.includes('answer')) {
        const m = txt.match(/"sentences?"\s*:\s*\[([^\]]+)\]/i) ||
                  txt.match(/"answers?"\s*:\s*\[([^\]]+)\]/i);
        if (m) {
          const arr = m[1].match(/"([^"]+)"/g);
          if (arr) {
            const sentences = arr.map(s => s.replace(/"/g,'').trim()).filter(Boolean);
            log('스크립트에서 ' + sentences.length + '개 문장 파싱');
            return sentences;
          }
        }
      }
    }
    return [];
  }

  function findCards() {
    for (const sel of CARD_SELECTORS) {
      const els = [...document.querySelectorAll(sel)].filter(el => {
        const r = el.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
      });
      if (els.length >= 2) return els;
    }
    return [];
  }

  function cardText(el) {
    return el.textContent.trim().toLowerCase();
  }

  function matchAnswer(cards, sentences) {
    const cardWords = cards.map(c => cardText(c));
    const key = [...cardWords].sort().join('|');
    for (const s of sentences) {
      const words = s.trim().split(/\s+/).map(w => w.toLowerCase());
      if ([...words].sort().join('|') === key) return words;
    }
    return null;
  }

  async function dragCard(fromEl, toEl) {
    const from = centerOf(fromEl);
    const to   = centerOf(toEl);

    fromEl.dispatchEvent(pointerEv('pointerdown', from.x, from.y));
    fromEl.dispatchEvent(mouseEv('mousedown', from.x, from.y));
    await sleep(STEP_DELAY * 3);

    for (let i = 1; i <= DRAG_STEPS; i++) {
      const t = i / DRAG_STEPS;
      const mx = from.x + (to.x - from.x) * t;
      const my = from.y + (to.y - from.y) * t;
      document.dispatchEvent(pointerEv('pointermove', mx, my));
      document.dispatchEvent(mouseEv('mousemove', mx, my));
      await sleep(STEP_DELAY);
    }

    document.dispatchEvent(pointerEv('pointerup', to.x, to.y));
    document.dispatchEvent(mouseEv('mouseup', to.x, to.y));
    await sleep(DROP_DELAY);
  }

  async function sortCards(targetOrder) {
    for (let i = 0; i < targetOrder.length; i++) {
      const cards = findCards();
      if (!cards.length) { log('정렬 중 카드 소실'); return false; }
      const words = cards.map(c => cardText(c));
      if (words[i] === targetOrder[i]) continue;
      const srcIdx = words.indexOf(targetOrder[i], i);
      if (srcIdx === -1) { log('단어 못찾음: ' + targetOrder[i]); return false; }
      log('[' + srcIdx + ']"' + targetOrder[i] + '" → [' + i + ']');
      await dragCard(cards[srcIdx], cards[i]);
    }
    return true;
  }

  async function clickNext() {
    for (const sel of NEXT_SELECTORS) {
      const btn = document.querySelector(sel);
      if (btn && btn.offsetParent !== null) {
        btn.click(); await sleep(NEXT_DELAY); return true;
      }
    }
    await sleep(QUESTION_DELAY); return false;
  }

  async function waitNewQuestion(prevWord, timeout) {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      await sleep(400);
      const cards = findCards();
      if (cards.length && cardText(cards[0]) !== prevWord) return true;
    }
    return false;
  }

  async function main() {
    log('=== 자동 풀이 시작 ===');
    const answers = parseAnswers();
    if (answers.length === 0) {
      log('정답 문장 파싱 실패! 페이지를 확인하세요.');
      return;
    }

    for (let q = 0; q < MAX_Q; q++) {
      log('── 문제 ' + (q+1) + ' / ' + MAX_Q + ' ──');
      await sleep(600);

      const cards = findCards();
      if (!cards.length) { log('카드 없음. 종료.'); break; }

      const words = cards.map(c => cardText(c));
      log('현재: ' + words.join(' / '));

      const target = matchAnswer(cards, answers);
      if (!target) {
        log('정답 매칭 실패: ' + words.sort().join(','));
        break;
      }
      log('정답: ' + target.join(' '));

      const ok = await sortCards(target);
      if (!ok) { log('정렬 실패. 종료.'); break; }

      log('문제 ' + (q+1) + ' 완료!');
      if (q < MAX_Q - 1) {
        const prev = words[0];
        await clickNext();
        await waitNewQuestion(prev, 5000);
      }
    }
    log('=== 모든 풀이 완료 ===');
  }

  main().catch(e => log('오류: ' + e.message));
})();
"""

# ──────────────────────────────────────────────
# GUI 애플리케이션
# ──────────────────────────────────────────────
class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Wordwall Unjumble Solver")
        self.resizable(False, False)
        self.configure(bg="#1e1e2e")
        self.driver = None
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        PAD = {"padx": 14, "pady": 6}
        FONT_LABEL = ("맑은 고딕", 10)
        FONT_TITLE = ("맑은 고딕", 15, "bold")
        BG = "#1e1e2e"
        FG = "#cdd6f4"
        ACCENT = "#89b4fa"
        ENTRY_BG = "#313244"

        tk.Label(self, text="🤖 Wordwall Unjumble Solver",
                 font=FONT_TITLE, bg=BG, fg=ACCENT).pack(pady=(18, 4))
        tk.Label(self, text="Wordwall Unjumble 게임을 자동으로 풀어드립니다.",
                 font=FONT_LABEL, bg=BG, fg="#a6adc8").pack(pady=(0, 10))

        # URL 입력
        frm_url = tk.Frame(self, bg=BG)
        frm_url.pack(fill="x", **PAD)
        tk.Label(frm_url, text="게임 URL:", font=FONT_LABEL, bg=BG, fg=FG, width=10,
                 anchor="w").pack(side="left")
        self.url_var = tk.StringVar(value="https://wordwall.net/play/")
        tk.Entry(frm_url, textvariable=self.url_var, font=FONT_LABEL,
                 bg=ENTRY_BG, fg=FG, insertbackground=FG, relief="flat",
                 width=44).pack(side="left", padx=(4, 0))

        # 문제 수
        frm_q = tk.Frame(self, bg=BG)
        frm_q.pack(fill="x", **PAD)
        tk.Label(frm_q, text="풀 문제 수:", font=FONT_LABEL, bg=BG, fg=FG, width=10,
                 anchor="w").pack(side="left")
        self.q_var = tk.IntVar(value=10)
        tk.Spinbox(frm_q, from_=1, to=50, textvariable=self.q_var,
                   font=FONT_LABEL, bg=ENTRY_BG, fg=FG,
                   buttonbackground=ENTRY_BG, relief="flat", width=5).pack(side="left", padx=(4,0))

        # Headless 옵션
        frm_opt = tk.Frame(self, bg=BG)
        frm_opt.pack(fill="x", **PAD)
        self.headless_var = tk.BooleanVar(value=False)
        tk.Checkbutton(frm_opt, text="창 없이 실행 (headless)",
                       variable=self.headless_var,
                       font=FONT_LABEL, bg=BG, fg=FG,
                       selectcolor=ENTRY_BG, activebackground=BG).pack(side="left")

        # 버튼
        frm_btn = tk.Frame(self, bg=BG)
        frm_btn.pack(pady=10)
        self.btn_start = tk.Button(frm_btn, text="▶  자동 풀이 시작",
                                   font=("맑은 고딕", 11, "bold"),
                                   bg=ACCENT, fg="#1e1e2e", relief="flat",
                                   padx=18, pady=6, cursor="hand2",
                                   command=self._start)
        self.btn_start.pack(side="left", padx=6)
        self.btn_stop = tk.Button(frm_btn, text="■  중지",
                                  font=("맑은 고딕", 11),
                                  bg="#f38ba8", fg="#1e1e2e", relief="flat",
                                  padx=14, pady=6, cursor="hand2",
                                  state="disabled", command=self._stop)
        self.btn_stop.pack(side="left", padx=6)

        # 진행 바
        self.progress = ttk.Progressbar(self, mode="indeterminate", length=400)
        self.progress.pack(pady=(4, 0))

        # 로그
        tk.Label(self, text="로그", font=FONT_LABEL, bg=BG, fg="#a6adc8",
                 anchor="w").pack(fill="x", padx=14)
        self.log_box = scrolledtext.ScrolledText(
            self, font=("Consolas", 9), bg="#11111b", fg="#a6e3a1",
            relief="flat", height=14, state="disabled")
        self.log_box.pack(fill="both", expand=True, padx=14, pady=(2, 14))

        # 설치 안내
        if not SELENIUM_OK:
            self._log("⚠  selenium 미설치 → 아래 명령으로 설치 후 재실행하세요:", color="#f38ba8")
            self._log("    pip install selenium webdriver-manager", color="#fab387")

    def _log(self, msg, color="#a6e3a1"):
        self.log_box.config(state="normal")
        self.log_box.insert("end", msg + "\n")
        self.log_box.see("end")
        self.log_box.config(state="disabled")

    def _start(self):
        if not SELENIUM_OK:
            messagebox.showerror("오류", "selenium 패키지가 없습니다.\n\npip install selenium webdriver-manager")
            return
        url = self.url_var.get().strip()
        if not url.startswith("http"):
            messagebox.showwarning("입력 오류", "올바른 URL을 입력하세요.")
            return
        self.btn_start.config(state="disabled")
        self.btn_stop.config(state="normal")
        self.progress.start(12)
        self._log(f"시작: {url}")
        threading.Thread(target=self._run, args=(url,), daemon=True).start()

    def _stop(self):
        self._log("사용자가 중지를 요청했습니다.")
        if self.driver:
            try: self.driver.quit()
            except: pass
            self.driver = None
        self._done()

    def _done(self):
        self.progress.stop()
        self.btn_start.config(state="normal")
        self.btn_stop.config(state="disabled")

    def _on_close(self):
        if self.driver:
            try: self.driver.quit()
            except: pass
        self.destroy()

    def _run(self, url):
        try:
            self._setup_driver()
            if not self.driver: return
            self._log("브라우저 열기...")
            self.driver.get(url)
            time.sleep(3)
            # JS 주입
            js = SOLVER_JS.replace("__MAX_Q__", str(self.q_var.get()))
            self._log("자동 풀이 스크립트 주입...")
            self.driver.execute_script(js)
            # 진행 모니터링 (브라우저 콘솔 로그 폴링)
            self._monitor_logs()
        except Exception as e:
            self.after(0, lambda: self._log(f"오류: {e}", "#f38ba8"))
        finally:
            self.after(0, self._done)

    def _setup_driver(self):
        """Chrome WebDriver 초기화 (chromedriver 자동 설치)"""
        try:
            from webdriver_manager.chrome import ChromeDriverManager
            mgr_ok = True
        except ImportError:
            mgr_ok = False

        opts = Options()
        if self.headless_var.get():
            opts.add_argument("--headless=new")
        opts.add_argument("--disable-blink-features=AutomationControlled")
        opts.add_argument("--start-maximized")
        opts.add_experimental_option("excludeSwitches", ["enable-automation"])
        opts.add_experimental_option("useAutomationExtension", False)
        # 콘솔 로그 수집
        opts.set_capability("goog:loggingPrefs", {"browser": "ALL"})

        try:
            if mgr_ok:
                self._log("ChromeDriver 자동 설치/확인 중...")
                svc = Service(ChromeDriverManager().install())
                self.driver = webdriver.Chrome(service=svc, options=opts)
            else:
                self._log("webdriver-manager 없음 → PATH의 chromedriver 사용")
                self.driver = webdriver.Chrome(options=opts)
            self._log("브라우저 초기화 완료")
        except Exception as e:
            self.after(0, lambda: messagebox.showerror(
                "드라이버 오류",
                f"ChromeDriver 초기화 실패:\n{e}\n\n"
                "해결 방법:\n"
                "1. pip install webdriver-manager\n"
                "2. Chrome 브라우저가 설치되어 있는지 확인\n"
                "3. 수동으로 chromedriver.exe를 PATH에 추가"))
            self.driver = None

    def _monitor_logs(self):
        """브라우저 콘솔 로그를 폴링해 GUI에 표시"""
        seen = set()
        while self.driver:
            try:
                logs = self.driver.get_log("browser")
                for entry in logs:
                    msg = entry.get("message", "")
                    if "[Unjumble]" in msg:
                        clean = msg.split("[Unjumble]", 1)[-1].strip().strip('"')
                        if clean not in seen:
                            seen.add(clean)
                            self.after(0, lambda m=clean: self._log(m))
                        if "완료 ===" in msg:
                            return
                time.sleep(0.8)
            except Exception:
                break

# ──────────────────────────────────────────────
# 진입점
# ──────────────────────────────────────────────
if __name__ == "__main__":
    app = App()
    app.mainloop()
