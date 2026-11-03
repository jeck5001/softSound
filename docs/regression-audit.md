# 历史修复回归审计

每轮大改动后跑一次，确认**已修好的 bug 没有悄悄回来**。

## 为什么需要这份清单

用户反馈过「以前修好的 bug 又回来了」。那次核查发现：
- 修复代码**一个都没丢**
- 但新改动**毒化了老路径**（给底层加重试，与分页重试叠加成 9 次/页）
- 且老修复**只在理想条件下有效**（进度只靠 30 秒定时器）

所以审计不能只 grep 关键字，要看**行为是否仍然成立**。

## 清单（21 条）

| # | 历史修复 | 当前证据 | 守卫测试 |
|---|---|---|---|
| 1 | 通知栏有上一章/下一章 | `controlsFor` = [prev, play/pause, next]，`androidCompactActionIndices: [0,1,2]` | `media_metadata_test` |
| 2 | 小米灵动岛显示 | `AudioService.init` 已 await + 前台服务 | 同上 |
| 3 | 重启后「上次播放」保留 | `LastPlayedService.load()` + `SessionRestorer.restoreOnce()` | `last_played_service_test` + `resume_wiring_test` |
| 4 | 播放按钮状态正确 | `PlayerState.showPauseIcon`（`isPlaying && !isCompleted`） | `play_button_state_test` |
| 5 | 首播有声音 | `bool? _audioMixing` + `_ensureAudioSession()` 在两条起播路径都调用 | `first_play_audio_test` |
| 6 | 音量可控（关到 0 能静音） | `AndroidAudioFlags.none`，无 `setVolume()` | `first_play_audio_test`（反向断言） |
| 7 | 封面不丢 | `_keepIfEmpty` + `initialCover` + 榜单带 cover 参数 | `cover_passing_test` |
| 8 | 目录分段 | `ChapterSegments`（100 集/段），播放页+详情页共用 | `chapter_segments_test` |
| 9 | 目录数量正确 | `chapterCount` 比对 + 缺页告警 | `catalog_completeness_test` |
| 10 | 章节更新可获取 | `_refreshChaptersIfGrown()` + 详情页 `RefreshIndicator` | `chapter_update_test` |
| 11 | 搜索不全并发（防 429） | `SearchNotifier.maxConcurrent = 3` | `search_*_test` |
| 12 | 占位书名不入库 | `isPlaceholderBook()` 过滤 | `first_play_audio_test` |
| 13 | 排行榜一直加载不出来 | `EdgeGate` 串行 300ms + 有上限重试 | `edge_gate_test` |
| 14 | 酷我章节取全量 | `kuwo` 分页循环 | `kuwo_*_test` |
| 15 | 懒人详情不再卡占位名 | 去掉 `?? book`，失败报「书源暂时不可用」 | `lrts_source_failure_test` |
| 16 | 公告弹窗已移除 | 无 `AnnouncementGate` / `remote_config_api` | — |
| 17 | 自更新可用 | `kUpdateManifestUrl` 用 `refs/heads` 形式 | `app_updater_test` |
| 18 | 进度不丢（切后台/暂停即存） | `WidgetsBindingObserver` + `pause()` 落盘 | `progress_persistence_test` |
| 19 | 重试不叠加 | `_get` 内无重试循环 | `lrts_source_failure_test` |
| 20 | 正式签名 | `CN=QingTing`，keystore 不进仓库 | — |
| 21 | 版本号三处一致 | pubspec / appVersion / kCurrentVersionCode | `app_updater_test` |

## 审计脚本

```bash
# 静态：关键字是否还在
/tmp/audit.sh

# 行为：全部守卫测试
flutter test

# 关键：本次改动是否毒化了老路径
# 逐条对照上表"守卫测试"列，确认对应测试仍存在且通过
```

## 三个易误判的"假警报"

审计时遇到过这些，都是**正常演进**，不要当成丢失：

1. **`audibilityEnforced` 出现在代码里** → 只在**注释**里（警示不要用）。
   测试已改为反向断言。
2. **函数名找不到** → 恢复逻辑叫 `SessionRestorer.restoreOnce()` 不是
   `restoreLastPlayed`；`maxConcurrent` 在 `search_page.dart` 不在 service。
3. **`just_audio_background` / `tag:` 消失** → 这是**架构升级**：
   改用 `audio_service` 的 `publishChapter()`（红线 3 明确要求）。

## 判定标准

- 修复的**行为**仍成立 → 通过（即使实现方式变了）
- 修复的**行为**不成立 → 失败，必须修
- 仅实现细节变化但行为等价 → 通过，更新本文档的"当前证据"列
