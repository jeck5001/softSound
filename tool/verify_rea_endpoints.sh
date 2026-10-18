#!/usr/bin/env bash
# REA 动态验证：从聆阅 Hermes 字节码新挖出的端点契约（2026-10-16）
# 逐个真实请求并把响应体存到 test/fixtures/rea_verify/ 供固化为回归 fixture。
set -u
B="https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1"
K="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc"
OUT="/tmp/rea_verify"
mkdir -p "$OUT"

say(){ echo; echo "===== $1"; }
# supabase edge fn GET（apikey+Bearer），429 重试最多 3 次
g(){ local url="$1" name="$2" code
  for i in 1 2 3; do
    code=$(curl -sS -m 25 -H "apikey: $K" -H "Authorization: Bearer $K" "$url" -o "$OUT/$name" -w "%{http_code}")
    if [ "$code" != "429" ]; then break; fi
    echo "  429 限流，第 $i 次重试（等 11s）"; sleep 11
  done
  echo "GET $name -> HTTP $code $(wc -c < "$OUT/$name")B"
  head -c 230 "$OUT/$name" | tr '\n' ' '; echo
}
# 直连 GET（无鉴权）
p(){ local url="$1" name="$2"
  local code; code=$(curl -sS -m 25 -H "User-Agent: Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36" "$url" -o "$OUT/$name" -w "%{http_code}")
  echo "GET $name -> HTTP $code $(wc -c < "$OUT/$name")B"
  head -c 230 "$OUT/$name" | tr '\n' ' '; echo
}

say "A. tingshu8 兜底代理（无 key 无 429）—— 字节码 #18064/#18078/#17910"
p "http://www.tingshu8.top/yuan1/lrts.php?name=%E5%87%A1%E4%BA%BA" "php_search.json"
sleep 2
p "http://www.tingshu8.top/yuan1/lrts.php?id=94326793*1" "php_play.json"
sleep 2
p "http://www.tingshu8.top/yuan1/lrts.php?albumId=94326793" "php_album.json"

say "B. lrts-rank 榜单（字节码 #18082：rankId=75 热播榜, rangeType=1）"
g "$B/lrts-rank?rankId=75&rangeType=1" "lrts_rank_75.json"

say "C. kuwo-classify（字节码 #17953 -> sections/categories）"
g "$B/kuwo-classify" "kuwo_classify.json"

say "D. kuwo-albums 分类浏览（#17963：玄幻奇幻 classifyId=1548, categoryId=2, pn/rn）"
g "$B/kuwo-albums?classifyId=1548&pn=1&rn=20&categoryId=2&sortType=1" "kuwo_albums_1548.json"

say "E. lrts-home 首页（#18036 edge -> sections[books]）"
g "$B/lrts-home" "lrts_home.json"

say "F. lrts-category 懒儿童话分类（#18053 直连 www.lrts.me/book/category/{id}/20）"
p "https://www.lrts.me/book/category/63/20" "lrts_cat_direct_63.html"
sleep 2
g "$B/lrts-category?categoryId=63" "lrts_category_63.json"

say "G. kuwo-play 播放+字幕（#18026 fetchKuwoLyric：rid=1028308, host=）"
g "$B/kuwo-play?rid=1028308&host=" "kuwo_play_rid.json"

say "H. kuwo-channel-tabs（#17969：categoryId=2 -> tabs）"
g "$B/kuwo-channel-tabs?categoryId=2" "kuwo_channel_tabs_2.json"

say "完成。产物目录：$OUT"
ls -la "$OUT"
