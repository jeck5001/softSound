# CLAUDE.md — 轻听（soft_sound）

跨平台听书 App，UI 与功能对齐「聆阅 FM」（`聆听.apk`）的 Flutter 重写版。

## 红线（改了就会出事）

1. **`tingshu_*` 存储键名与取值不可改**：必须与聆阅字节码逐字一致
   （如 `tingshu_shelf_view` 的取值 `grid`/`list`）。改名会导致读不到
   用户已有存档。新键的取值来源必须在 `docs/reverse-engineering/lingting/`
   里有字节码出处。
2. **不要用 `isPlaying` 决定播放按钮图标**：用 `PlayerState.showPauseIcon`
   （`isPlaying && !isCompleted`）。`just_audio` 在章节播完 / 音频被打断后
   `playing` 仍为 `true`，只看 `isPlaying` 会出现「显示暂停键但没声音」。
3. **`MediaItem` 必须用 `audio_service` 的类型**，不要引回
   `just_audio_background`：后者的控制项写死为「播放/暂停 + 停止」，
   没有上一章/下一章，通知栏会少按钮。
4. **不要 `await` 缺失地初始化 `AudioService`**：必须 `await AudioService.init(...)`
   完成后再播，否则首次 `setAudioSource` 会赶在服务就绪前 → 首播没声音。
5. **书籍名占位串「加载书籍信息…」不可落库**：入库前过 `_isRealBook()`。
6. **上游返回的作者字段带前缀**：展示前过 `SearchRelevance.cleanAuthor()`
   （上游有 `作者：邵雪城` 这种，直接拼会显示成 `作者: 作者：邵雪城`）。
7. **搜索请求不要全并发**：Edge 函数有**项目级并发限制**
   （429 `projectConcurrencyLimitExceeded`），全并发反而更慢。
   用 `SearchNotifier.maxConcurrent`（3 路）+ 单源超时。

## 常用命令

```bash
flutter analyze                    # 必须 0 issue
flutter test                       # 基线 599 用例全过
flutter build apk --debug          # 真机验证用（~193MB，支持 run-as 看 DB）
flutter build apk --release        # 出包（~71MB）
```

产物 `build/app/outputs/flutter-apk/app-release.apk`。
**注意：release 目前仍用 debug 签名**（`android/app/build.gradle.kts` 有 TODO）。

## 模拟器（真机验证）

AVD `listen_test`（Android 15，1080×2400）。**必须带 DNS**，否则
`m.lrts.me` 解析失败：

```bash
/opt/homebrew/share/android-commandlinetools/emulator/emulator -avd listen_test \
  -no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect \
  -dns-server 8.8.8.8,1.1.1.1
```

- `adb` 在 `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`
- 底部导航 y≈2210：首页 x≈135 / 发现 x≈405 / 书架 x≈675 / 我的 x≈945
- 调试包的 DB：`/data/data/com.softSound.soft_sound/app_flutter/soft_sound.db`
  （`run-as com.softSound.soft_sound sqlite3 …`；**release 包 run-as 会失败**）
- 偏好文件：`/data/data/com.softSound.soft_sound/shared_prefs/FlutterSharedPreferences.xml`
  （键带 `flutter.` 前缀，如 `flutter.tingshu_shelf_view`）
- 媒体会话断言：`adb shell dumpsys media_session`；通知动作数：
  `adb shell dumpsys notification --noredact | grep softSound`
- 切章/播放手势：`adb shell cmd media_session dispatch next|play|pause|fast-forward`

> 模拟器 CDN 单章加载常需 40–60 秒，且跑久了 `system_server` 会 ANR。
> 需要"播完一章"这类长链路验证时，用 `dispatch fast-forward` 把进度推到章末。

## 架构约定

- 状态：**Riverpod**（`StateNotifierProvider` / `Provider`）
- 路由：**go_router**（`lib/app/routes.dart`）
- 网络：**Dio**；书源适配器在 `lib/services/typed_sources/`
- 存储：**drift (SQLite)**，仓库层在 `lib/data/repositories/`
- 播放：`just_audio` + **`audio_service`**（自定义 `LingtingAudioHandler`）
- 文案：集中在 `lib/theme/app_strings.dart`，**不硬编码中文**

### 书源（2 个，都经 Supabase Edge 代理）

| 源 | 前缀 | 特点 |
|---|---|---|
| 懒人听书 | `lrts-*` | Edge 搜索接口 `/lrts-search` **服务端已坏**（返回 `{"error":"html is not defined"}`），代码里记住不可用 10 分钟并走 PHP 兜底 |
| 酷我 | `kuwo-*` | 播放地址走 `kuwo-play?rid=&quality=&host=`，`quality` 必带（默认 `'128'`） |

Edge 请求经 `EdgeGate` 串行化（300ms 间隔）避免 429。

## 文档索引

| 文档 | 内容 |
|---|---|
| `docs/reverse-engineering/lingting/UI_PORT.md` | **主文档**：逐条移植记录 + 每次用户反馈的根因与实测（§6.x 按时间累积） |
| `docs/reverse-engineering/lingting/README.md` | 逆向方法（hermes-dec 反汇编）、已确认的端点与存储契约 |
| `docs/reverse-engineering/lingting/hermes-strings.txt` | 从字节码提取的全部内联字符串（16,028 条） |
| `docs/superpowers/specs/2026-10-13-lingting-apk-rea-analysis.md` | 完整分析报告（书源、端点、主题） |
| `docs/superpowers/specs/2026-10-13-base-apk-rea-analysis.md` | 基础 APK 分析 |

反汇编产物在 `/tmp/hasm_out`（50.9MB，22,819 函数）；
`/tmp/fn.sh <fn#>` 导出函数体，`/tmp/fn_index.tsv` 是行号→函数号索引。

## 排查"用户反馈"类问题的顺序

用户报的是**现象**，根因常在状态语义而非 UI。按这个顺序查：

1. `flutter analyze` + `flutter test` 确认基线没坏
2. 看代码里该状态的**来源**是否等于用户感知（例：`isPlaying` ≠ 在出声）
3. 到字节码里找聆阅的**真实契约**（键名、取值、调用序列），不要凭感觉设计
4. 真机/模拟器上取**可复现的证据**（`dumpsys`、DB、截图），不是"看起来好了"
5. 无法验证的部分**如实写进文档**，不要含糊过去
