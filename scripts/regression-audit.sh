#!/bin/bash
# 逐条核查历史 fix 是否仍在代码中
cd "$(dirname "$0")/.."
pass=0; fail=0
chk() {  # $1=描述 $2=文件 $3=模式
  if grep -q "$3" "$2" 2>/dev/null; then
    echo "  OK   $1"; pass=$((pass+1))
  else
    echo "  LOST $1  <-- [$2] 找不到 $3"; fail=$((fail+1))
  fi
}

echo "== 1. 通知栏上一章/下一章 + 灵动岛 =="
chk "androidCompactActionIndices" lib/services/lingting_audio_handler.dart "androidCompactActionIndices"
chk "skipToNext 控制项" lib/services/lingting_audio_handler.dart "MediaControl.skipToNext"
chk "AudioService.init 已 await" lib/main.dart "await AudioService.init"

echo "== 2. 重启后上次播放 =="
chk "lastPlayedService 存在" lib/services/last_played_service.dart "class LastPlayedService"
chk "读取上次播放（不只写）" lib/services/last_played_service.dart "restoreOnce"
chk "order by lastPlayTime" lib/data/repositories/book_repository.dart "lastPlayTime"

echo "== 3. 播放按钮状态 =="
chk "showPauseIcon 定义" lib/services/player_service.dart "showPauseIcon"
echo "== 4. 首播有声音 =="
chk "音频会话配置门控（nullable）" lib/services/player_service.dart "bool? _audioMixing"
chk "_ensureAudioSession" lib/services/player_service.dart "_ensureAudioSession"

echo "== 5. 音量可控 =="
chk "flags 为 none（不设 audibilityEnforced）" lib/services/audio_effects.dart "AndroidAudioFlags.none"
# 注意：audibilityEnforced **允许出现在注释里**（作为警示），只禁止真正赋值。
if grep -v '^\s*//' lib/services/audio_effects.dart 2>/dev/null | grep -q "AndroidAudioFlags.audibilityEnforced"; then
  echo "  FAIL 代码里又set了 audibilityEnforced！"; fail=$((fail+1))
else
  echo "  OK   代码未使用 audibilityEnforced（仅注释提及）"; pass=$((pass+1))
fi

echo "== 6. 封面传递 =="
chk "榜单带 cover 参数" lib/features/ranking/ranking_page.dart "cover="
chk "_keepIfEmpty" lib/data/repositories/book_repository.dart "_keepIfEmpty"
chk "initialCover" lib/features/book_detail/book_detail_page.dart "initialCover"

echo "== 7. 目录分段 =="
chk "ChapterSegments" lib/services/chapter_segments.dart "class ChapterSegments"
chk "播放页用分段" lib/features/player/player_page.dart "ChapterSegments"

echo "== 8. 章节更新 =="
chk "refreshChapters" lib/services/player_service.dart "refreshChapters"
chk "_refreshChaptersIfGrown" lib/services/player_service.dart "_refreshChaptersIfGrown"
chk "详情页下拉刷新" lib/features/book_detail/book_detail_page.dart "RefreshIndicator"

echo "== 9. 搜索相关性/并发 =="
chk "maxConcurrent" lib/features/search/search_page.dart "maxConcurrent"

echo "== 10. 占位书名不落库 =="
chk "isPlaceholderBook" lib/services/player_service.dart "isPlaceholderBook"

echo
echo "通过 $pass 项，丢失 $fail 项"
