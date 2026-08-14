@echo off
chcp 65001 > nul
echo ================================================
echo  Wordwall 화면인식 풀이 - 빌드 스크립트
echo ================================================
echo.

echo [1/3] 필요 패키지 설치 중...
pip install mss pillow pytesseract pyautogui opencv-python pyinstaller
if errorlevel 1 ( echo 설치 실패! & pause & exit /b 1 )

echo.
echo [2/3] EXE 빌드 중 (약 2~3분)...
pyinstaller --onefile --windowed ^
    --name "WordwallScreenSolver" ^
    --hidden-import="PIL._tkinter_finder" ^
    --hidden-import="cv2" ^
    screen_solver.py

if errorlevel 1 ( echo 빌드 실패! & pause & exit /b 1 )

echo.
echo [3/3] 완료!
echo EXE: dist\WordwallScreenSolver.exe
echo.
echo ★ 실행 전 Tesseract OCR 설치 필요:
echo   https://github.com/UB-Mannheim/tesseract/wiki
echo.
pause
