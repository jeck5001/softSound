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
8. **音频属性 flags 只能是 `AndroidAudioFlags.none`**：绝不能设
   `audibilityEnforced`（= `AUDIO_FLAG_AUDIBILITY_ENFORCED`，紧急广播专用）。
   它会**忽略用户的音量与静音设置** → 用户反馈「音量关到 0 还出声、关不掉」。
   也不要自己调 `_player.setVolume()`，音量归系统管。
9. **部分更新不要用 `Value(x)` 无条件覆盖**：`touchPlayedBook` 这类"只刷新
   元数据"的写入必须用 `_keepIfEmpty()`（空值 → `Value.absent()`）。
   否则上游只给部分字段时（如榜单跳转没有 cover），会把库里更完整的数据
   **擦成 null**，而且是永久的。
10. **不要用 UI 进度条判断"有没有声音"**：`just_audio` 的 `positionStream`
   是本地按时间插值算的，进度条会走不代表平台层在出声。要看
   `adb shell dumpsys media.audio_flinger` 里本进程有没有 `A` 状态的 track。
   起播前必须走 `_ensureAudioSession()`（`configure` + `setActive`）——
   `just_audio` 在 `setActive` 失败时会**静默不动**，不报错也不打日志。

11. **弹窗里需要可变状态时，用独立 `StatefulWidget`，不要用 `StatefulBuilder`**：
    配合 `await showDialog` 时，外层 builder 重跑会把局部变量重置回初始值
    （表现为「点了没反应」）。另外 `TextEditingController.dispose()` **不能**
    紧跟 `await showDialog` —— 退场动画期间 `TextField` 还在树上，
    会触发 `_dependents.isEmpty` 断言红屏。
12. **章节目录必须分段**：一本有声书动辄上千集（793 / 4715）。
    统一用 `ChapterSegments`（100 集一段），播放页与详情页共用，
    且打开时自动落在当前章所在段。

13. **章节列表是实时拉的、会过期**：不要用「进入播放时」的 `chapters.length`
    判断"是否最后一章"。`nextChapter()` 到末尾必须先 `_refreshChaptersIfGrown()`；
    刷新只增不减（上游删章/改序会打乱播放位置）。

14. **分页拉取失败不能 `break` 就完事**：章节列表要连拉近百页
    （5795 集 = 97 页），任一页 429/超时就会**静默丢掉后半段**，
    用户只看到「目录数量不对」。必须重试 + 退避，并把
    `chapterCount`（上游声明总数）与实际列表比对，缺了就显式告警。

15. **绝不能复用聆阅的 `remote-config` 做更新**：它的 `download_url` 指向
    聆阅作者网盘、`version_name` 是聆阅的 `1.1.7`。对本应用而言意味着
    「永远提示有新版本」+「点下载装成聆阅、把本应用替换掉」。
    自更新只用 `kUpdateManifestUrl`（`lib/services/app_updater.dart`）。
16. **版本号三处必须一致**：`pubspec.yaml` 的 `version: x.y.z+N`、
    `AppStrings.appVersion`、`kCurrentVersionCode`。由
    `test/services/app_updater_test.dart` 强制校验。

## 常用命令

```bash
flutter analyze                    # 必须 0 issue
flutter test                       # 基线 660 用例全过
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
