@echo off
chcp 65001 > nul
echo ================================================
echo  Wordwall Unjumble Solver - 빌드 스크립트
echo ================================================
echo.

echo [1/3] 필요 패키지 설치 중...
pip install selenium webdriver-manager pyinstaller
if errorlevel 1 (
    echo 패키지 설치 실패!
    pause
    exit /b 1
)

echo.
echo [2/3] EXE 빌드 중 (약 1~2분 소요)...
pyinstaller --onefile --windowed ^
    --name "WordwallSolver" ^
    --add-data "." ^
    main.py

if errorlevel 1 (
    echo EXE 빌드 실패!
    pause
    exit /b 1
)

echo.
echo [3/3] 완료!
echo EXE 파일 위치: dist\WordwallSolver.exe
echo.
pause
