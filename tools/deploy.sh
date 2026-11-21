#!/bin/bash
# 웹 빌드 + gh-pages 배포. 캐시 때문에 옛 버전이 뜨지 않도록 pck에 버전 쿼리를 붙인다.
set -e
cd "$(dirname "$0")/.."
VER=$(TZ=Asia/Seoul date +%m%d.%H%M)
printf 'class_name BuildInfo\nextends RefCounted\nconst VERSION := "%s"\n' "$VER" > scripts/build_info.gd
godot --headless --import >/dev/null 2>&1 || true
rm -rf export/web && mkdir -p export/web
godot --headless --export-release "Web" export/web/index.html 2>&1 | grep -E "ERROR" || true
# pck 를 버전별 파일명으로 바꿔 캐시를 피한다
mv export/web/index.pck "export/web/index-$VER.pck"
python3 - "$VER" <<'PY'
import sys,re
v=sys.argv[1]; p='export/web/index.html'; s=open(p).read()
s=s.replace('"executable":"index"','"executable":"index","mainPack":"index-%s.pck"'%v,1)
s=s.replace('"index.pck":','"index-%s.pck":'%v,1)
open(p,'w').write(s)
PY
PAGES=${PAGES_DIR:-/tmp/pages}
if [ ! -d "$PAGES/.git" ]; then
  rm -rf "$PAGES"; git clone -q --depth 1 -b gh-pages https://github.com/hyuny0219/blitz "$PAGES"
fi
rm -f "$PAGES"/index*
cp export/web/* "$PAGES"/
cd "$PAGES"
git add -A
git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit -q -m "웹 빌드 $VER

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01U4aB6GTpoX8QqyVPzD1QvV"
git push -q origin gh-pages
echo "deployed $VER"
