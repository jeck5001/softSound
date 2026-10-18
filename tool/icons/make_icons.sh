#!/usr/bin/env bash
# 从 SVG 母版重新生成「轻听」全套启动器图标。
#
# 依赖：rsvg-convert（brew install librsvg）。CJK 字形走系统 PingFang / Hiragino。
# 用法：bash tool/icons/make_icons.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
res="$root/android/app/src/main/res"
ios="$root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

command -v rsvg-convert >/dev/null || { echo "缺少 rsvg-convert：brew install librsvg" >&2; exit 1; }

# A.svg = 整幅方形（legacy / iOS）
# A_fg.svg = 自适应前景（图形缩进中心 66% 安全区）
# A_mono.svg = Android 13+ 主题图标单色层
render() { rsvg-convert -w "$2" -h "$2" "$here/$1" -o "$3"; }

echo "▶ Android legacy 方形图标"
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:192 xxxhdpi:512; do
  n="${d%:*}"; s="${d#*:}"
  render A.svg "$s" "$res/mipmap-$n/ic_launcher.png"
  echo "  mipmap-$n/ic_launcher.png ($s)"
done

echo "▶ Android 自适应图标前景 / 单色层（108dp 画布）"
mkdir -p "$res/mipmap-anydpi-v26"
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  n="${d%:*}"; s="${d#*:}"
  render A_fg.svg   "$s" "$res/mipmap-$n/ic_launcher_foreground.png"
  render A_mono.svg "$s" "$res/mipmap-$n/ic_launcher_monochrome.png"
  echo "  mipmap-$n/ic_launcher_{foreground,monochrome}.png ($s)"
done

echo "▶ iOS AppIcon（必须无 alpha，否则 App Store 拒）"
gen_ios() { render A.svg "$2" "$ios/$1"; echo "  $1 ($2)"; }
gen_ios Icon-App-20x20@1x.png 20;   gen_ios Icon-App-20x20@2x.png 40;   gen_ios Icon-App-20x20@3x.png 60
gen_ios Icon-App-29x29@1x.png 29;   gen_ios Icon-App-29x29@2x.png 58;   gen_ios Icon-App-29x29@3x.png 87
gen_ios Icon-App-40x40@1x.png 40;   gen_ios Icon-App-40x40@2x.png 80;   gen_ios Icon-App-40x40@3x.png 120
gen_ios Icon-App-60x60@2x.png 120;  gen_ios Icon-App-60x60@3x.png 180
gen_ios Icon-App-76x76@1x.png 76;   gen_ios Icon-App-76x76@2x.png 152
gen_ios Icon-App-83.5x83.5@2x.png 167
gen_ios Icon-App-1024x1024@1x.png 1024

echo "▶ 校验 iOS 尺寸与 alpha"
python3 - "$ios" <<'PY'
import json, os, sys
from PIL import Image
d = sys.argv[1]
spec = json.load(open(os.path.join(d, "Contents.json")))
bad = []
for i in spec.get("images", []):
    fn = i.get("filename")
    if not fn:
        continue
    p = os.path.join(d, fn)
    if not os.path.exists(p):
        bad.append(f"{fn}: 缺失"); continue
    im = Image.open(p)
    exp = round(float(i["size"].split("x")[0]) * float(i["scale"].rstrip("x")))
    if im.width != exp:
        bad.append(f"{fn}: {im.width}px != {exp}px")
    if im.mode != "RGB":
        bad.append(f"{fn}: 带 alpha ({im.mode})，App Store 会拒")
print("  OK" if not bad else "\n".join(["  " + b for b in bad]))
sys.exit(1 if bad else 0)
PY

echo "✅ 完成。改了图形就重跑本脚本；Android 端 XML 见 mipmap-anydpi-v26/ic_launcher.xml"
