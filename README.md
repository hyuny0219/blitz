# BLITZ ⚡

아이들을 위한 아레나 FPS (Godot 4.6). 로블록스 라이벌 스타일의 5선승 듀얼 + 카운터스트라이크식 무기.

## 플레이
- 웹(폰/PC): https://hyuny0219.github.io/blitz/
- 폰은 가로로 돌려서 플레이

## 내용
- 모드: 1v1 / 2v2 / 3v3 / 5v5 듀얼(5점 선승), 개인전(15킬), 건게임
- 무기: AK-47, M4A4, MP5-SD, P90, Nova, SSG 08, AWP / Glock-18, USP-S, Desert Eagle / 나이프 / HE·섬광·연막
- 캐릭터 8명, 맵 6개, 봇 난이도 3단계, 열쇠로 무기·캐릭터 해금

## 개발
- 엔진: Godot 4.6.2 (GL Compatibility, Web 내보내기)
- `scripts/` 전부 GDScript, 맵·캐릭터·무기 모델은 코드로 생성
- 아트(텍스처·키아트·3D 캐릭터)는 Higgsfield로 생성
- 웹 빌드: `godot --headless --export-release "Web" export/web/index.html`
- 디버그: `godot -- --autoplay --botplayer --mode=duel3 --map=dust` (봇끼리 자동 대전)
