@echo off
chcp 65001 > nul
echo 필요 패키지 설치 확인 중...
pip install selenium webdriver-manager -q
python main.py
