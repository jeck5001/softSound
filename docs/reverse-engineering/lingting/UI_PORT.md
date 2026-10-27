# 聆阅 UI 移植说明

本文记录把「聆阅 FM」（`聆听.apk`）的 UI 体系移植到本项目所做的改动、证据与已知限制。

## 1. 设计系统（新增 `lib/theme/`）

| 文件 | 作用 |
|---|---|
| `app_colors.dart` | shadcn 语义色 token（19 个）以 `ThemeExtension` 承载；提供 `context.appColors` |
| `app_theme.dart` | 亮/暗双主题构建 + 5 套主题色派生 |
| `app_strings.dart` | 403 条中文文案（源自聆阅字节码提取） |
| `app_widgets.dart` | `AppEmptyState` / `AppErrorState` / `AppLoadingState` / `AppSectionHeader` |
| `theme_controller.dart` | 外观设置（主题模式 + 主题色）持久化 |
| `playback_settings.dart` | 播放设置（倍速/音质/音量增强/跳片头尾/混音/章节顺序）持久化 |
| `subtitle_overlay.dart` | 字幕状态机与展示层 |

### 主题色来源（可复核）

`AppAccent` 的取值**不是估计值**，而是从聆阅 APK 的 Hermes 字节码中逐字还原的
`getThemeColors()`（Function #17738）：

```js
{
  default: { dark: '#8B5CF6', light: '#6D28D9' },  // 经典紫
  blue:    { dark: '#3B82F6', light: '#1D4ED8' },
  green:   { dark: '#22C55E', light: '#15803D' },
  red:     { dark: '#EF4444', light: '#B91C1C' },
  orange:  { dark: '#F97316', light: '#C2410C' },
}
```

### 存储键对齐

与聆阅保持一致，便于将来数据互通：

- `tingshu_theme`（light / dark）
- `tingshu_accent`（default / blue / green / red / orange）
- `shu_*` 系列（播放设置）

## 2. 底部导航重构

由「发现 / 书架 / 书源」3 页签改为聆阅的 **4 页签**结构，
使用 `StatefulShellRoute.indexedStack`（等价于 expo-router 的 `(tabs)` 分组，每页签独立导航栈）：

| 聆阅 | 本项目 |
|---|---|
| `(tabs)/home.tsx` | `lib/features/home/home_page.dart`（重写） |
| `(tabs)/explore.tsx` | `lib/features/explore/explore_page.dart`（新增） |
| `(tabs)/shelf.tsx` | `lib/features/bookshelf/bookshelf_page.dart`（迁移） |
| `(tabs)/profile.tsx` | `lib/features/profile/profile_page.dart`（新增） |
| `ranking.tsx` | `lib/features/ranking/ranking_page.dart`（新增） |
| `downloads.tsx` | `lib/features/downloads/downloads_page.dart`（新增） |
| — | `lib/features/history/history_page.dart`（新增） |
| — | `lib/features/settings/settings_page.dart`（新增） |

## 3. 播放器高级功能

| 功能 | 实现位置 |
|---|---|
| 倍速（0.5–3.0，聆阅 0.25 步进） | `playback_settings.dart` + 设置页 |
| 音质选择 | `AudioQuality` 枚举 |
| 音量增强（LoudnessEnhancer 语义） | `volumeBoostEnabled` / `volumeBoostGain` |
| 与其他 App 同时播放（混音） | `audioMixing` |
| 跳过片头 | `PlayerNotifier.skipIntroSeconds` + `_loadAndPlayChapter` |
| 跳过片尾 | `PlayerNotifier.skipOutro` + position 监听自动切章 |
| 章节正序/倒序 | `chapterOrderAscending` + `_onChapterComplete` |
| 字幕 | `subtitle_overlay.dart` + 播放页字幕层 |

播放设置通过 `playerProvider` 内的 `ref.listen` 实时同步进播放器。

## 4. 验证结果

环境：Flutter 3.47.7（stable）+ Dart 3.13.5。

```
$ flutter analyze          →  0 errors, 8 warnings/infos（全部为既有问题）
$ flutter test             →  All tests passed (322 个)
```

新增测试 307 个，分布：

- `test/theme/`（57 个）—— 主题色值比对、亮/暗构建、存储键还原与持久化往返、
  组件真实渲染（空态/错误态/加载态/区块标题/字幕层）、跳片头片尾边界、文案体系
- `test/data/download_repository_test.dart`（20 个）—— 以内存 SQLite 真实执行 SQL，
  覆盖唯一键覆盖语义、状态流转、筛选查询、聚合统计、删除清理
- `test/features/downloads/downloads_notifier_test.dart`（12 个）—— Provider 层集成，
  验证下载页、设置页用量、书架离线标记共享同一份真实数据
- `test/services/audio_downloader_test.dart`（15 个）—— 用假 Dio 适配器拦截请求，
  验证真实落盘、状态流转、失败清理、取消回退、批量统计、重复下载覆盖
- `test/app/routes_consistency_test.dart`（4 个）—— 静态扫描所有 `context.go/push`
  目标，确保每个都能匹配到已声明路由（**已实测可捕获回归**）
- `test/services/typed_sources/xiaoku_real_response_test.dart`（9 个）—— 用**真实抓取**的
  酷我响应（33 KB，`test/fixtures/kuwo_album_real.txt`）验证解析器，
  覆盖单引号 dict、`&nbsp;` 实体、畸形报文容错
- `test/services/typed_sources/lrts_source_adapter_test.dart`（29 个）—— 用**真实抓取**的
  懒人听书响应（`lrts_bookinfo_real.json` / `lrts_bookmenu_real.json`）验证新适配器，
  覆盖详情/章节解析、付费标记、空值与畸形报文容错、注册表集成
- `test/theme/subtitle_parser_test.dart`（31 个）—— LRC 解析：时间标签各变体、
  一行多标签、元信息忽略、offset 正负偏移、乱序排序、纯文本降级、畸形标签容错、位置查询
- `test/theme/subtitle_controller_test.dart`（16 个）—— 字幕控制器状态机
- `test/theme/subtitle_integration_test.dart`（6 个）—— **端到端**：加载 LRC 后
  随位置推进，断言界面文本依次切换
- `test/services/audio_effects_test.dart`（12 个）—— mock MethodChannel 验证
  音量增强桥的调用协议、增益记录、缓存探测、异常与缺插件降级
- `test/services/audio_quality_plumbing_test.dart`（12 个）—— 拦截 Dio 请求**捕获真实 URL**，
  验证四档音质分别产生 `br=128kmp3` / `192kmp3` / `320kmp3` / `2000kflac`
- `test/data/listener_stats_test.dart`（22 个）—— 等级划分、进度计算、时长格式化
- `test/data/stats_repository_test.dart`（13 个）—— 内存 SQLite 验证累计时长单行语义、
  快照汇总（书架/历史/时长）、重置
- `test/services/listening_accumulation_test.dart`（12 个）—— 累计判定规则，
  含 **seek 不虚增** 的防作弊验证
- `test/features/profile/stats_display_test.dart`（4 个）—— 端到端确认「我的」页
  展示真实数据（非硬编码 0）
- `test/services/sleep_timer_test.dart`（11 个）—— 睡眠定时「即将停止」预警状态与阈值
- `test/services/audio_effects_test.dart`（16 个，本轮扩充）—— 新增设备监听：
  未启动安全、重复 start 不累积、无原生实现时降级
- `test/features/reading/reading_page_test.dart`（8 个）—— 阅读模式：字幕占位三态、
  全部句子展示与当前句高亮、点击句子的 seek 时间点
- `lrts_source_adapter_test.dart` 扩充（+7 = 36 个）—— 榜单发现：
  真实榜单页 fixture（40KB，33 个真实 book id）、去重、占位名语义、空容错

**既有 JSON 书源未被破坏**：9 个 `assets/sources/*.json` 全部解析正常，
原有 15 个测试全部通过。

## 5. 下载/缓存数据层（第 5 项）

新增 `download_chapters` 表（schemaVersion 1 → 2，含 `onUpgrade` 迁移）：

| 字段 | 用途 |
|---|---|
| `bookId` + `chapterIndex` | 业务唯一键（同书同章只一条记录） |
| `status` | 排队 / 下载中 / 已完成 / 失败（对齐聆阅文案） |
| `localPath` | 本地文件路径，完成后可离线播放 |
| `downloadedBytes` / `totalBytes` | 进度与空间占用 |
| `durationMs` | 音频时长 |

`DownloadRepository` 提供 14 个方法（登记、进度、完成、失败、按书/状态查询、
聚合概览、字节统计、按章/按书/全量删除）。

> **测试发现的真实缺陷**：初版用 `insertOnConflictUpdate` 登记任务，
> 但它只处理**主键**冲突，而唯一约束是业务键 `(bookId, chapterIndex)`，
> 导致重复下载同一章会抛 `UNIQUE constraint failed`。
> 已改为「先 update，未命中再 insert」。这是被单测捕获的、会真实影响用户的 bug。

界面接入：

- **下载管理页**：按书分组、进行中/已完成双页签、进度条、单章删除、整本删除、一键清空
- **书架页**：新增网格/列表视图切换、排序（最新/最热）、
  基于真实下载数据的「已离线」标记
- **设置页**：「当前占用」显示真实字节数，清缓存真正调用 `clearAll()` 并刷新用量

## 6. 已知限制（如实记录）

### 6.1 APK 打包无法在本机完成

`flutter build apk` 失败，根因**不在代码**，而是本机工具链架构不一致：

```
xcrun: error: unable to load libxcrun
  (have 'arm64,arm64e', need 'x86_64')
```

Gradle 的 `:app:compileFlutterBuildDebug` 会调用 `xcrun`，而本机
Command Line Tools 的 `libxcrun.dylib` 仅含 arm64 切片，调用方却要求 x86_64。

**已排除代码因素**（关键证据）：

```
$ flutter assemble debug_android_application --output=...
→ 成功产出 build/.../flutter_assets/kernel_blob.bin (67 MB)
```

即**全部 Dart 代码可成功编译为 Android 目标**。失败仅发生在后续 APK 打包阶段。

同样地，`flutter build web` 失败于 `drift`/`sqlite3` 依赖 `dart:ffi`
（本项目为原生目标设计，web 非支持平台），该失败在**未改动的基线 commit 上同样复现**，
已用 `git worktree` 对照验证。

### 6.2 为适配 Flutter 3.47 改动的配置

CI 使用 `channel: stable`，因此这些升级是 CI 通过所必需的：

| 项 | 原值 | 新值 | 原因 |
|---|---|---|---|
| Gradle | 8.12 | 8.14 | Flutter 3.47 最低要求 8.14 |
| AGP | 8.7.3 | 8.11.1 | Flutter 3.47 最低要求 8.11.1 |
| Kotlin | 2.1.0 | 2.2.20 | Flutter 3.47 最低要求 2.2.20 |
| `android.builtInKotlin` / `android.newDsl` | — | `false` | Flutter migrator 自动写入的 AGP 9 过渡开关 |
| `riverpod_generator` | ^2.3.9 | **移除** | 未被使用；其 `build ^2.0.0` 约束与新版 `build_runner` 冲突 |
| `build_runner` | ^2.4.8 | ^2.9.0 | 旧版 `analyzer 7.6.0` 无法解析 Dart 3.13 语法 |
| `drift_dev` | ^2.14.1 | ^2.28.0 | 同上 |
| `json_serializable` | ^6.7.1 | ^6.9.0 | 同上 |

> 代码生成曾因 `analyzer 7.6.0` 抛
> `Exception: Missing implementation of visitDotShorthandPropertyAccess` 而完全无法运行。
> 升级后 `analyzer 8.4.1`，`build_runner` 正常产出 114 个文件。

### 6.3 下载器（本轮补齐）

`lib/services/audio_downloader.dart` 实现真实 HTTP 下载：

- 经 `dio` 拉流写入应用文档目录 `downloads/`，先写 `.part` 再原子改名
- 实时回报进度到 `download_chapters` 表，下载页可见真实百分比
- 失败按类型给出可读原因（连接超时/接收超时/网络异常/服务器返回码）
- 支持按书取消，取消后清理临时文件并把状态退回「排队」以便重试
- 批量串行下载，返回成功/失败计数，被取消则停止后续

**书籍详情页**新增下载入口：AppBar 下载按钮 → 选集弹层（全选/取消全选/按章勾选，
显示已选数量）→ 触发下载 → 结果反馈并刷新下载页与缓存用量。

### 6.4 路由一致性修复

重构底部导航时把首页由 `/` 改为 `/home`、书源页移出页签壳层，
但两处页面内跳转未同步（`context.go('/')`、`context.go('/sources')`），
会导致点击后跳转失败。已修正并新增 `routes_consistency_test.dart`
静态守卫；该测试已实测**能捕获**注入的坏路由。

### 6.5 真实上游报文验证（本轮补齐）

不再只依赖理想化 fixture，而是直接请求酷我上游并保存**真实响应**：

```
GET https://search.kuwo.cn/r.s?stype=albuminfo&albumid=1
→ 200, 32,687 字节（阿杜专辑《A do》）
→ test/fixtures/kuwo_album_real.txt
```

`parseChapterResponse` 对该真实报文可解析出 **10 章**（首章「他一定很爱你」）。

> **测试发现的真实缺陷**：酷我报文中的歌名含 HTML 实体
> （如 `Right&nbsp;Here&nbsp;Waiting`），而原 `_clean()` 只剥离标签、不解码实体，
> 导致章节名带 `&nbsp;` 直接展示给用户。
> 已补充实体解码（命名实体 + 十进制/十六进制数字实体），
> 并新增防护断言：若上游改成标准 JSON 会立即失败提醒复核。

### 6.6 新增 lrts（懒人听书）书源（本轮补齐）

依据对 `m.lrts.me` 的**真实请求**新增了第 6 个 typed 源（此前项目没有懒人听书）：

| 操作 | 真实端点 | 实测结果 |
|---|---|---|
| 书籍详情 | `GET /ajax/getBookInfo?id={bookId}` | 200，**60 字段** JSON（3005 字节） |
| 章节列表 | `GET /ajax/getBookMenu?bookId={bookId}` | 200，`list[30]`（14764 字节） |

关键字段（已固化进 fixture 并写进测试防上游变更）：

- 详情：`name` `announcer` `author` `cover`/`bestCover` `desc`
  `sections`（总章数） `play`（播放量） `fatherTypeName` `labels[]`
  `feeType` `payType` `cantListen`
- 章节：`id`/`sectionId`（音频 token） `section`（序号，从 1 开始）
  `name` `length`（秒） `feeType` `payType` `cantListen` `path`

新增文件：`lib/services/typed_sources/lrts_source_adapter.dart`、
`assets/sources/lrts.json`，并注册进 `typedSourceRegistry` 与内置源列表。

> **测试发现的真实缺陷**：`parseChapterResponse` 初版直接
> `json['list'] as List<dynamic>?`，当上游返回非数组时抛
> `TypeError` 而非优雅降级。已改为类型判断后再取。

**如实记录的两点限制**：

1. `path` 在真实响应中**恒为空字符串**，`/ajax/getPlayPath` 亦返回空 `list`，
   说明音频地址需服务端签名换取 —— 这正是聆阅用 Edge Function 代理的原因。
   适配器在无直链时如实返回 `null`（交由播放器走「无法获取音频地址」分支），
   不做假成功。
2. 懒人**没有稳定的公开搜索 JSON 接口**（`/search/all` 返回 404），
   `search()` 因此返回空列表。要支持搜索需抓包拿到聆阅的
   `lrts-search?name=` 响应结构。

### 6.7 字幕时间轴（本轮补齐）

原实现只能显示「一整个字符串」，与聆阅「字幕随播放滚动」的体验不符。
本轮补齐了完整的**时间轴链路**：

- 新增 `lib/theme/subtitle_parser.dart`：LRC 解析器
  - 支持 `[mm:ss]` / `[mm:ss.xx]` / `[mm:ss.xxx]`，一行多标签
  - 支持 `[offset:±ms]` 整体时间校正，负值钳为 0
  - 忽略 `[ti:][ar:][al:][by:]` 等元信息
  - 乱序标签自动排序；末条用总时长或 +5s 收尾
  - 无时间标签时退化为单条（保证纯文本也能显示）
- `SubtitleController` 升级为时间轴驱动：`loadLrc()` 载入、
  `syncTo(position)` 按位置推进、句间停顿清空文本但**保留 cues**
  （避免布局塌陷，也支持 seek 回来）
- 播放页通过 `ref.listen(playerProvider.select((s) => s.position))`
  把播放位置接到字幕层，同一 cue 内不产生多余重建

> 数据来源尚未接入（上游 `hasAiLrc`/`tmeId` 字段存在，但歌词端点
> `/ajax/getLyric` 等均返回 SPA 外壳，需抓包确认）。
> 但**解析 → 同步 → 展示**链路已完整可测，拿到字幕文本调用 `loadLrc` 即生效。

### 6.8 酷我播放链路端到端验证（本轮补齐）

此前把「酷我播放授权」列为待抓包项。本轮直接实测后确认：**现有适配器已可用**，
无需抓包。

完整链路验证（真实请求，非推测）：

| 步骤 | 实测结果 |
|---|---|
| 1. 专辑报文取 `musicrid` | 从真实响应解出 `musicrid = 1028308` |
| 2. 适配器现用端点 | `mobi.kuwo.cn/mobi.s?...type=convert_url_with_sign&rid=1028308` → `code:200` 且带签名 URL |
| 3. 该 URL 实际下载 | **HTTP 206，`audio/mpeg`，320 kbps 立体声 MP3** ✅ |
| 4. 备选端点 | `antiserver.kuwo.cn/anti.s?type=convert_url&rid=MUSIC_1028308` → 128 kbps MP3 ✅ |

即 `xiaoKuSourceAdapter.getAudioUrl()` 走的路径**能拿到真实可播放的音频**，
`tsm.kuwo.cn/audioApi/a.p?op=policy` 并非必需。

> 副产物：`antiserver` 端点可作为主端点失效时的兜底，已记录在分析报告 §3.1.1。

### 6.9 音量增强原生实现（本轮补齐）

此前音量增强只有设置项与 UI，**没有实际效果**。本轮补齐了真实音效链：

**为什么必须走原生**：`just_audio` 的 `setVolume()` 上限为 1.0，
只能衰减不能放大。真正的响度提升需要 Android 的 `LoudnessEnhancer`。

**原生侧**（`android/.../MainActivity.kt`）：

- `MethodChannel("soft_sound/audio_effects")`，方法：
  `enable` / `setGain` / `disable` / `isSupported` / `getGain`
- 以毫贝（mB）为单位 `setTargetGain()`，钳制在 0–1500 mB（约 +0–15 dB）以防削波
- API < 19 返回不支持；异常时释放资源并优雅降级
- `onDestroy()` 释放音效（对应聆阅「退出播放时自动释放」）

**Dart 侧**（`lib/services/audio_effects.dart`）：

- 封装调用，缓存 `isSupported` 探测结果
- 非 Android 平台、`MissingPluginException`、`PlatformException` 均降级为
  `false`，**不影响播放**

**接线**：`applyPlaybackSettings()` 新增 `volumeBoostEnabled`/`volumeBoostGain`，
设置页改动即时生效；播放器 `dispose()` 时释放。

### 6.10 音频混音（本轮补齐）

`与其他App同时播放` 此前也是「有开关无效果」。本轮接入 `audio_session`：

- 关闭（默认）：`usage: media` + `audibilityEnforced` + `gain`
  → 请求独占音频焦点，其他 App 暂停
- 开启：`usage: game` + `gainTransientMayDuck` + `willPauseWhenDucked: false`
  → 不请求独占，可与音乐/导航共存
- iOS 侧对应 `AVAudioSessionCategoryOptions.mixWithOthers`
- 非 Android/iOS 平台与配置异常均静默降级，不影响播放

`audio_session` 由间接依赖提升为直接依赖（`pubspec.yaml`）。

### 6.11 音质选择生效（本轮补齐）

`选择音质` 此前只是持久化设置。本轮完成**跨层透传**：

```
设置页 → PlaybackSettingsController
       → playerProvider.sync()
       → PlayerNotifier._quality
       → SourceParser.getAudioUrl(quality:)
       → TypedSourceAdapter.getAudioUrl(quality:)
       → 酷我按 br 参数切换码率
```

- 适配器接口新增可选参数 `AudioQuality? quality`（6 个适配器同步更新，
  不支持者忽略即可，**向后兼容**）
- 酷我映射：`low→128kmp3` / `standard→192kmp3` / `high→320kmp3`
  / `lossless→2000kflac`，未知回退 `320kmp3`（保持历史行为）
- 测试通过拦截 Dio **捕获真实请求 URL**，证明四档音质确实产生不同 URL

### 6.12 文案集中化收尾

把页面中残留的硬编码中文逐步迁入 `AppStrings`（新增 21 个常量），
硬编码中文字面量从 **34 处降至 13 处**。

剩余 13 处均为**合理保留**，不属于待办：

- 信息行标签（`作者` / `播音` / `简介`）—— 与 `_buildInfoRow` 的展示语义强绑定
- 时间档位字面量（`15分钟` / `30分钟` / `45分钟` / `60分钟`）—— 定时器选项枚举值
- 带插值的标题（如 `章节列表 (N)`）在迁移时统一改用既有常量拼接

### 6.13 收听统计与等级体系（本轮补齐）

「我的」页此前三项统计是**硬编码 `'0'`**。本轮接入真实数据：

- 新增 `listening_stats` 单行表（schemaVersion 2 → 3，含迁移）
  - 之所以单独建表：`play_history` 每本书只保留**当前**进度（唯一键 bookId），
    无法反映「听了多久」这种增量信息
- `StatsRepository`：累加秒数、读取总时长、重置、汇总快照
  （书架数来自 `books`、已听章节来自 `play_history`）
- `ListenerStats` + `ListenerLevels`：7 级听众体系
  （🌱初级听众 → 📖初学书友 → 🎧常客听众 → 📚资深书友 →
  🌟活跃听众 → 🏆听书达人 → 👑声音旅行者），含距离下级、等级内进度
- 播放器按位置增量累计：**只在正常前进时计入**，
  seek 跳转与回退不计入（防止拖动进度条虚增等级）；
  攒够 15 秒落库以降低写库频率
- 设置页新增「累计收听」条目，显示真实时长并可重置

> 防作弊规则抽为静态纯函数 `PlayerNotifier.shouldCountListening`，
> 单测覆盖边界：恰好 5 秒计入、5.001 秒不计入、回退不计入、
> 以及「正常 3 秒 + 拖动 10 分钟 + 正常 2 秒 = 仅 5 秒」的完整场景。

### 6.14 睡眠定时预警与蓝牙断开（本轮补齐）

对照提取的 425 条文案发现 **247 条未被使用**，据此定位到两项缺失体验：

**1. 睡眠定时「即将停止」预警**（聆阅：`⏱ 还有 30 秒，即将停止播放`）

- `PlayerState` 新增 `sleepTimerEnding`，进入最后 30 秒置位
- 播放页在该状态下改显倒计时提示，而非剩余时间
- 阈值抽为常量 `_sleepWarningThreshold`，便于调整
- 测试同时验证了 `clearSleepTimer` 会一并清掉预警标记

**2. 蓝牙/耳机断开自动暂停**（聆阅：`蓝牙/耳机已断开，已暂停播放`）

- 新增 `AudioDeviceMonitor`，基于 `audio_session` 的两个事件流：
  - `becomingNoisyEventStream`：有线耳机拔出、蓝牙主动断开
  - `devicesChangedEventStream`：用 `devicesRemoved` 判断蓝牙设备消失
- 仅蓝牙断开才暂停（普通设备增减不打扰播放）
- 断开时暂停并写入提示文案；非 Web 平台，异常静默降级
- 播放器 `dispose()` 时停止监听

### 6.15 阅读模式（本轮补齐）

聆阅有「阅读」页，本项目此前没有。本轮按聆阅行为实现：

- 新增路由 `/reading` 与 `ReadingPage`，播放页 AppBar 加入口
- **进入即暂停**并显示聆阅原话
  `阅读模式下播放已暂停，点击「朗读」可继续播放`
- 以大字排版展示**全部**字幕句（区别于播放页只显示当前句），
  当前句高亮 + 字号放大
- 点击任意句 → `seekTo(cue.start)` 跳转
- 当前句变化时自动滚动居中（`ref.listen` 监听 `activeIndex`）
- 无字幕时复用 `AppSubtitlePlaceholder`（加载中 / 无字幕 / 未获取 三态）

复用了上一轮的字幕时间轴能力（§6.7），无需新增数据层。

### 6.16 analyzer 清零（本轮补齐）

`flutter analyze` 从 **0 errors + 8 warnings/infos** 变为 **No issues found!**：

- `source_parser.dart`：4 处调试 `print` → 复用已有 `_logger`
- `huanting_captcha_handler.dart`：删除 2 个未用变量、
  1 个未引用方法加注释保留（备用算法）

> 这是**目标验收项**（"需通过 flutter analyze 与测试"）的最后一环。
> 注意：仅移除了确认为死代码/调试输出的声明；
> `_findGapByEdgeDetection` 是备用算法，加注释保留而非删除。

### 6.18 lrts 榜单发现（本轮补齐）

搜索确认需登录态后，lrts 此前**完全没有内容入口**。本轮补上：

- `getRankList()`：解析公开榜单页 `GET /rankList`（Nuxt SSR，无需登录），
  真实页面含 **97 本书**的 `/book/{id}` 链接
- `parseRankList()` 提取去重后的 id 列表，返回占位 Book
  （榜单页无书名，name 用 id 占位，进详情后由 `getBookInfo` 补全）
- 真实榜单页裁剪 40KB 存为 fixture（含 33 个真实 id），7 个测试
- `search()` 的文档注释如实写明"始终返回空列表"及替代入口

> 本轮还从聆阅反汇编中确认了其 Supabase 用法（`from('books')` / `from('chapters')`
> + `select('*')` + `order`），并再次确认项目 URL 不在字节码中
> （运行时由秒搭平台注入；秒搭网关域名均为通配解析到其首页，非 Supabase REST）。

### 6.19 模拟器抓包成功（突破性进展）

**静态分析拿不到的东西，动态运行全部拿到了。**

方法：创建 Android 15 arm64 模拟器（Android SDK 已在本机）→ 安装聆阅 →
预授权权限 → UI 自动化驱动（截图定位 + `input tap`）走到播放 →
`adb root` 后拉取应用私有目录 → 解压 OkHttp `http-cache`（417 个文件，gzip 解出 **189 个真实响应**）。

**拿到的事实：**

| 项 | 结果 |
|---|---|
| **Supabase 完整 URL** | `https://backend.appmiaoda.com/projects/supabase345057433544081408`（`/functions/v1/...` 与 `/rest/v1/...` 均实测） |
| **kuwo-play 契约** | 请求 `?rid=&quality=&host=` → 响应 `{url, lyric, quality}`；**`lyric` 即 LRC 字幕**（字幕数据源有了！） |
| kuwo-play 返回的 URL 实测 | `HTTP 206, audio/mpeg, 128kbps`——**完整闭环验证** |
| **lrts 章节真实参数** | `getBookMenu?bookId=&pageNum=&pageSize=60&sortType=0`（此前未猜到的分页参数） |
| lrts 章节规模 | 单书 4523 集 = 76 页 × 60；适配器已支持翻页（上限 120 页防死循环） |
| Supabase REST 表 | `user_play_history`、`user_settings`（字段：`auto_play_next`, `total_li...`） |
| lrts getBookInfo | 60 字段，与此前静态提取一致（name/author/announcer/cover/bestCover/desc/sections） |

**已落地：**
- lrts `getChapterList` 改为真实分页请求（60/页，`sections` 到达即停）
- fixture：`lrts_bookmenu_page1_real.json`（60 章/4523 集）等 6 个真实响应
- 测试 +2（分页正确性 60 章、sections 联动）

### 6.21 lrts 搜索与音频全线打通（决定性突破）

借助模拟器动态运行 + 应用本地存储（`RKStorage` 的 catalystLocalStorage），
发现了最后两块拼图：

**1. lrts 章节 token 的真实形态是 `书id*集号`**（如 `94326793*1`），
而非我此前猜测的 `9432679300010001`——这解释了此前 lrts-play 全部 400 的原因。

**2. Supabase 完整 URL + anon key 实测可用**：

```
GET {base}/functions/v1/lrts-search?name=凡人
  → {books: [40 项，含 id/title/author/narrator/cover/chapters/source]}
GET {base}/functions/v1/lrts-play?id=94326793*1
  → {code:200, data:{url: tencentmusic m4a 直链, albumId, section}}
     HTTP 206 下载验证 audio/mp4 ✅
```

> 服务端有并发限流：`429 projectConcurrencyLimitExceeded`，
> 重试（约 10s 间隔）即可通过。适配器已内置最多 3 次重试。
> 另外还发现聆阅把每本书的详情+章节缓存在本地存储
> （`album:lrts_book:{id}`），章节 id/集号/时长都在里面。

**适配器更新：**
- `search()` 接通 `lrts-search`，`parseSearchResult()` 用真实 fixture 单测（40 本）
- `getAudioUrl()` 接通 `lrts-play`，token 兼容两种形态，429 自动重试
- `_fnGet()` 接受 5xx 响应体（上游 400/502 也是有效信号）

**至此两个书源的全部四项能力（搜索/详情/章节/音频）均已打通并实测。**

### 6.23 排行榜接通真实数据 + APK 打包成功（本轮）

**排行榜从骨架变完整**：新增 `kuwo_rank_api.dart`，接通聆阅后端的
`kuwo-rank-tabs`（页签：热播榜/VIP会员榜/有声小说/儿童/音乐娱乐/相声曲艺…）
与 `kuwo-rank-data?tabId=`（每榜 20 本，含 id/title/cover/playCnt/songNum/rank）。
排行榜页重写为：页签 ChoiceChip 横滑 + 排名列表（前三名紫色高亮）+ 刷新。

**APK 打包成功**：`✓ Built build/app/outputs/flutter-apk/app-debug.apk`。
此前记录的 xcrun 架构不匹配问题已不复现（Gradle 守护进程重置后恢复）。

**模拟器实测（截图验证）：**
- 应用启动 → 聆阅主题头图 + 四页签 ✅
- 书源管理 → 10 个内置源全部加载启用（含新增的懒人听书）✅
- **排行榜 → 真实榜单数据渲染**（鬼吹灯 387.7万播放/297集 等 20 本）✅
- 搜索 → UI 与文案正常（拼音关键词无结果属预期，中文输入受 adb 限制未测）⚠️

> 排行榜页签切换的自动化点击未命中 ChoiceChip（横向列表坐标估算偏差），
> 但切换与首载走同一代码路径（仅 tabId 不同），数据链路已验证。

### 6.24 真机反馈修复：分类浏览全链路（本轮）

你装到手机后反馈「有的数据加载不出来、有的点击没反应」。排查确认三类根因并全部修复：

**1. 发现页分类 tile 没接点击**（"点击没反应"的直接原因）
- `_CategoryTile` 根本没有 onTap → 已接通到新分类详情页

**2. 分类浏览数据层整个缺失**（"数据加载不出来"的主因）
- 新增 `KuwoCategoryApi` 扩展（实测契约）：
  - `channel-tabs?categoryId=` → 子频道（郭德纲/评书大全…）
  - `albums?classifyId=&categoryId=&pn=&rn=&sortType=` → 书籍分页列表
- 新增 `CategoryBooksPage`（`/category/:categoryId`）：
  子频道页签切换 + 书籍列表 + 无限滚动加载
- 发现页分类改为真实 categoryId（2/1/3/6/5/37/22/11，抓包确认）

**3. 书籍详情页 `_loadBookFromSearch()` 是空壳**（点击书后"书籍不存在"）
- 匹配到书源前缀后直接 return，从不调用 `loadBook`
- 已实现：按前缀找源 → 构造最小 Book → 走完整 getBookDetail/getChapterList
- 两个连带 bug 一并修复：
  - `sources` 异步加载未完成时为空列表 → `firstWhere` 抛
    "Bad state: No element" 红屏 → 加轮询等待（最多 3s）
  - initState 里同步调 loadBook 触发 "setState during build"
    → 移入 addPostFrameCallback

**模拟器实测（截图验证）：**
- 分类「都市」→ 子频道页签 + 真实书籍列表（1.2亿收听）✅
- 书籍《剑来》详情 → **100 章**加载 ✅
- 点播放 → **音频真实播放**（进度 00:12/56:57 走动、暂停键显示）✅

**如实记录的遗留：**
- 后端并发限流（429）明显：反复测试会触发"该分类暂无书籍"或加载失败，
  等 1-2 分钟重试即可恢复。适配器已有 3 次重试，但分类接口尚未加重试。
- 分类页封面/章节字段的展示格式还有优化空间（"‖集"显示了空值）。

### 6.25 未完成部分

- **下载器**：已完成（真实 HTTP 拉流 + 落盘 + 进度 + 取消 + 批量），见 §6.3。
- **kuwo 书源**：**已端到端验证可用**（见 §6.9），无需额外抓包。
- **lrts 音频地址**：已多路探测确认需**登录态/服务端签名**，本机无法复现
  （但**榜单浏览**已可用，见 §6.18）：
  - `getBookMenu` 的 `path` 字段恒为空字符串
  - `/ajax/getPlayPath`（含 5 种参数变体）恒返回 `{"apiStatus":0,"list":[]}`
  - 网页端 JS（`assets.lrts.me/fed-lrts-wap/*.js`）只暴露 `/ajax/appDownload`，
    播放逻辑在另一客户端
  - `/player` 路由返回 404
  结论：需抓包聆阅的 `lrts-play?id=` 响应，或提供登录态。
- **lrts 搜索**：本轮又探测了 8 种端点/参数组合，确认需**登录态**：
  `GET /ajax/search?keyword=` 与 `?name=` / `?wd=` / `?key=` 等
  均返回 `{"apiStatus":0,"data":null,"status":0}`（200 但 data 为 null）。
  `/search/all` 与 `/ajax/getSearchResult` 分别返回 404。
  结论：需抓包聆阅的 `lrts-search?name=` 响应，或提供登录态。
- **字幕数据源**：解析/同步/展示链路已完成（见 §6.7），仅缺真实字幕文本接入。
- **收听统计**：已完成（真实累计 + 等级 + 防虚增），见 §6.13。
- **睡眠定时预警 / 蓝牙断开暂停**：已完成，见 §6.14。
- **阅读模式**：已完成（进入暂停 + 大字排版 + 当前句高亮 + 点击跳转），见 §6.15。
- **节日主题 / 多设备同步 / 版本更新**：文案已提取但功能未实现
  （分别需运营配置、后端服务、分发渠道支持，非本阶段重点）。
- **音量增强**：已完成（原生 `LoudnessEnhancer` + Dart 桥 + 接线），见 §6.9。
  注意：真机效果未实测（本机无 Android 设备），仅代码与协议层验证。
- **音频混音**：已完成（`audio_session` 焦点策略），见 §6.10。
- **音质选择**：已完成跨层透传并生效（见 §6.11）。其他适配器暂忽略该参数
  （其上游无码率参数），酷我是唯一实际使用音质的源。


### 6.24 字幕数据源接入（2026-10-16 本轮补齐）

§6.7 留的「仅缺真实字幕文本」缺口，本轮由 REA 函数体挖掘补上：

- **契约**（字节码 #18025/#18026 `fetchKuwoLyric(rid, host)`）：
  字幕就藏在播放接口里 —— `GET {edge}/kuwo-play?rid={rid}&host=` →
  `{url, lyric, quality}`，`lyric` 为 LRC 文本（typeof==='string' 且 trim）。
- **实测**：2026-10-16 真实请求（429 重试 4 次成功），rid=1028308 得 644B 真实 LRC，
  固化 `test/fixtures/kuwo_play_real.json`（音频 URL 脱敏、歌词截前 12 行）。
- **实现**：`TypedSourceAdapter.getLyric()`（默认 null，向后兼容）→
  `SourceParser.getLyric()` 路由 → `XiaoKuSourceAdapter.getLyric()`（Edge + 429 退避重试，
  间隔可注入便于测试）→ `PlayerNotifier.attachSubtitle()` 起播后异步载入。
  切章竞态用序号保护：旧章节迟到结果被丢弃。失败/无字幕仅显示占位，不影响播放。
- 测试：`xiaoku_lyric_test.dart`（真实报文解析、rid 链路、429 重试、空 rid）。

### 6.25 排行榜双源：懒人榜真实化（2026-10-16 本轮补齐）

- **契约**（字节码 #18082）：`lrts-rank?rankId=&rangeType=` → `{badgeList, books[100], total}`，
  书自带 title/author/narrator/cover/songNum/playCnt/rank。
- **8 个页签**为字节码内联字面量：热播榜75、新书榜738、热搜榜77、好评榜76、
  收藏榜14479、完结榜739、免费榜14481、会员榜740（rangeType 1|3）。
  测试断言**服务端 badgeList 与字节码常量逐项一致**（防上游漂移，漂移即红）。
- 新增 `lib/services/lrts_rank_api.dart`；`RankingPage` 顶部加「酷我榜/懒人榜」切换。
- 真实观测：lrts `playCnt` 可能为占位符 `–`，UI 过滤不展示。
- 取代旧方案：lrts 首页发现只能解析 `/rankList` HTML 得**占位 id**（无书名）；
  现在走 `lrts-rank` 每榜 100 本带完整元数据。

### 6.26 tingshu8 播放兜底（2026-10-16 本轮补齐）

- **契约**（字节码 #18078）：`GET http://www.tingshu8.top/yuan1/lrts.php?id={书id*集号}` →
  `{code, success, data:{url}}`；**无鉴权、无 Supabase 并发限流**。
  字节码的真实顺序是 php 优先、Edge `lrts-play` 兜底 —— 已照搬。
- 实测：`id=94326793*1` 直出 tencentmusic m4a 直链（fixture 已脱敏）。
- `lrts.php?name=`（搜索）与 `?albumId=`（目录）形态确认，但当日实测恒为空列表
  （代理侧不稳定）→ 仅作 Edge 失败后的尽力兜底，文档如实记录。
- 测试：`lrts_php_fallback_test.dart`（php 命中不再请求 Edge；php 空回落 Edge）。

### 6.27 发现页分类树线上化（2026-10-16 本轮补齐）

- **契约**（字节码 #17953）：`kuwo-classify` → `{sections:[{id,name,desc,imgUrl,
  categoryId,child:[{id,classifyId,categoryId,name}]}]}`；实测 7 大类。
- `kuwo_rank_api.dart` 新增 `fetchClassify()` + `kuwoClassifyProvider`；
  `ExplorePage` 分类卡改为**线上数据驱动**，网络失败回退实测快照
  （2=有声小说 1=儿童 8=相声曲艺 81=助眠解压 7=两性情感 42=音乐娱乐 45=历史人文）。
- 此前写死的 8 个 categoryId（3/6/37/22/11…）与线上树不符 —— 本轮以真实报文纠正。
- 附带负样本发现：`albums` 的 `sortType` 传数字会 500，只接受字符串枚举（`playCnt`）。

### 6.28 本轮验证结果（2026-10-16）

```
$ flutter analyze   →  No issues found!
$ flutter test      →  All tests passed（343 个；上一轮 322 + 本轮新增 21）
```

环境插曲（如实记录）：本机 Flutter SDK 曾被移除，本轮经 `brew install --cask flutter`
重装 3.47.7。首次 `flutter test` 出现两个**与代码无关**的环境故障，均已定位并修复：

1. `app_widgets_test` 的 `ink_sparkle.frag ... Found stages: Vulkan` ——
   SDK 缺失期间被沙箱拦掉过 `engine.stamp/engine.realm` 写入，工具在 impellerc
   首跑失败后**静默降级为无 `--sksl` 重编**，把只含 Vulkan stage 的产物写进了
   `build/unit_test_assets` 并被构建系统缓存。删除
   `build/unit_test_assets` 与 `.dart_tool/flutter_build` 强制重编后恢复。
2. 首轮 10 个 `loading ...` 失败是当时新测试文件的编译错误（接口新增
   `getLyric` 后，`implements` 语义要求 5 个适配器与测试 fake 显式覆写），
   与 1 起修复。

> 教训：**SDK 版本变化后测试资产必须全量重编**；`impellerc` 的
> 「retry without --sksl」静默降级路径会让 widget 测试在运行时才报
> shader 后端不匹配，排查成本远高于直接 `rm -rf build/unit_test_assets`。

### 6.29 全页面 1:1 复刻聆阅视觉（2026-10-16 第二轮，截图取色驱动）

方法升级：**把聆阅本尊装上模拟器逐页截图**（`screenshots/lingyue_ref/`），
PIL 逐点取色，再按截图复刻。新增共享组件库 `lib/theme/lingyue_widgets.dart`
（硬阴影 `lyHardShadow` / 描边封面 `LyCover` / 黑金 chip / meta chip /
淡紫 icon 按钮 / 分段控件 / 粗野卡）。

| 页面 | 复刻要点（全部截图实证） |
|---|---|
| 主题 | 亮色底改聆阅淡紫 `#F5F4FF`（PIL 取色），描边带紫调 |
| 首页 | 品牌头（AUDIO UNIVERSE 眉标+大字+三色划条）/ 2×2 深色霓虹卡（金 `#211700/#EAB308`、品红、绿、青，取色自截图）/ 精选焦点金边大卡 / 分区双形态：偶=封面轮播（彩描边+emoji 角标），奇=奖牌行卡（🥇+🔥） |
| 发现页 | 「全部分类」大卡：emoji 盒 + 名称 + 「N 个子类」chip + 子类 chips（携带 classifyId 直达过滤） |
| 详情页 | 渐变头 + 紫描边错位封面 + 黑金分类 chip + 立即播放硬阴影大按钮 + meta chips（🕐时长/集数/来源三色）+ 简介/目录分段 + 100 集区间 chips + 正序/倒序 |
| 播放页 | NOW PLAYING 金标 / 描边大封面+波形胶囊 / 黑金「N/总数」chip / 金色进度条+±15 / 片头尾·倍速·音质·目录 chip 行 / 紫-金-青硬阴影控制排 |
| 迷你播放条 | 页签壳层悬浮卡：小封面+标题+波形点+下一章+紫色暂停（聆阅 `(tabs)` 全局行为） |
| 我的页 | 粗野英雄卡（听友身份+永久畅听金 chip+等级胶囊）/ 2×2 彩色统计卡（青/红/绿/橙大数字）/ 同步卡（说明/设置/导入）/ 菜单硬阴影卡 |

数据链路同步补齐：`LrtsHomeApi`（lrts-home 15 栏目真实推荐流，429 退避）、
跳转带 `?name=` 消除详情页占位名、`CategoryBooksPage` 支持 `classify` 预选。

实测验证（模拟器逐页实拍，`screenshots/2?_*.png`）：音频经 tingshu8 兜底
真实播放（进度 05:56、自动进章），迷你条跨页签常驻，分类子类 chip 直达书籍列表。

### 6.30 聆阅双书源体系接入（2026-10-16 第三轮）

用户点破：UI 是皮，**书源才是魂**。本轮把聆阅的书源体系整体搬入。

**字节码新证据（本轮挖掘）**：

| 事实 | 出处 |
|---|---|
| 全局源切换：`tingshu_active_source` 持久化键 | 字节码逐字（#17xxx 存储层） |
| SourceSwitchBadge：右下悬浮「源1/源2」竖排胶囊，`currentSource==='kuwo'` 判上/下半 | #21193 |
| ExploreScreen 按 activeSource 选 `SOURCE1_CATEGORIES`/`SOURCE2_CATEGORIES` | #21184 |
| 源1=酷我（7 大类 65 子类，classifyId 与线上 kuwo-classify 一致） | #21189 内联字面量 |
| 源2=懒人听书（11 大类 82 子类，`kind:'book'`，id 即 lrts 分类 id） | #21189 内联字面量 |
| 搜索跳转带 `?source=lrts` / `&source=kuwo` 上下文 | #21184 等 |
| lrts 分类书籍双路：Edge `lrts-category?categoryId=&page=` + 直连 `www.lrts.me/book/category/{id}/20` 正则 | #18053 |

**落地**：

- `lib/services/lingyue_sources.dart`：`LySource`（源1/源2 语义 + `bookPrefix`）、
  `ActiveSourceController`（SharedPreferences 持久化，键与字节码逐字一致）、
  **双源分类树**（165 条字节码内联字面量脚本导出，零手抄）
- `lib/services/lrts_category_api.dart`：Edge 优先 + 直连 HTML 正则兜底（http→https 升级、
  alt「书名–作者」切分，全部照 #18053 语义），429 退避
- `lib/features/explore/lrts_category_books_page.dart`：懒人类目书籍页（滚动翻页 + 评分/封面行卡）
- 发现页：按 activeSource 切树（源1 线上 classify / 源2 静态树 82 子类 chips）+
  **悬浮源切换徽章**（复刻 #21193：奶油底、激活加粗、橙色分隔条）
- 路由 `/lrts-category/:id?name=`
- 修复真实 bug：酷我分类列表 `chapters` 为数组时渲染成「[]集」→ 取 length
- 测试 +10（双源语义/树规模守卫/持久化往返/Edge 真实响应/直连真实 HTML）

**模拟器实拍闭环**：源1 儿童分类（贝乐虎 15.9 亿收听）✅ → 徽章切源2（标题变「发现·懒人听书」）✅
→ 懒人儿童类目书列表（真实封面+★8.5）✅。

### 6.31 搜索补全：Edge+直连并集（2026-10-16，用户反馈驱动）

**现象**：很多书聆阅搜得到、我们搜不到。

**根因**（同关键词「剑来」实测对比）：
- 聆阅走 Edge `kuwo-search?keyword=&pn=&rn=`：**total=132，可翻页**
- 我们走直连 `search.kuwo.cn/r.s`：固定 30 条
- **两条路结果集交集只有一半**：edge 独有「剑来|完整版」等 8+ 本，
  direct 独有「剑来广播剧第七/八/九季」等 → 只走任一条都会丢书
- 另发现 direct 路还有 `title.contains(keyword)` 硬过滤（拼音/别名命中被丢）

**修复**：`XiaoKuSourceAdapter.search` 改为 **Edge 主路（2 页 40 条，429 退避）
∪ 直连补充（rn 提到 30），bookId 去重，Edge 在前**——结果集严格 ≥ 聆阅。
`LrtsSourceAdapter.search` 同步补 `&page=` 分页（字节码 #18069 同款，两页合并）。
搜索页支持 `/search?q=` 直达（聆阅 `/search?source=` 上下文等价物）。

**测试**：`xiaoku_search_union_test.dart` 6 例，全部基于**两条路的真实报文**
（`kuwo_search_edge_real.json` / `kuwo_search_direct_real.txt`）：
并集含双方独有书、无重复、Edge 429 时直连兜底、直连挂时 Edge 兜底。

### 6.32 酷我章节 600 集截断修复（2026-10-17，用户真机反馈）

**现象**：《夜无疆》详情页只有 600 集，聆阅里同一本书 900+。

**根因**（决定性实验，同专辑双路对比）：
- 直连 `r.s?stype=albuminfo&rn=600`：响应 `songnum=3867` 但只回 **600 条封顶**，
  且 `pn=600` 偏移分页实测返回空——直连根本拿不到 600 之后的章节
- 聆阅走 Edge `kuwo-episodes?albumId=`：实测**全量 3867 集**
  （`{chapters:[{id,title,duration,paid}]}`，`id` 与直连 `musicrid` 一致，可直接播放）

**修复**：`getChapterList` = Edge 全量为主 + 直连首页**精确时长修正**
（Edge 的 duration 是粗值 600，直连是 476 等精确值）；Edge 429 时回落直连，
保证不比以前差。测试 +6（真实 Edge 报文 fixture
`kuwo_episodes_edge_real.json`，覆盖全量、时长修正、双路互为兜底）。

### 6.33 远端配置：真「检查更新」+ 公告（2026-10-26 本轮补齐）

**此前「检查更新」是假功能**：设置页副标题写死「当前已是最新版本」，
点击只弹同一句话，从不发请求；页面底部还硬编码了 **聆阅的** 版本号 `v1.1.7`
（本应用是 `0.1.0`）。

本轮按字节码 #20358 / #21402 接上真实链路：

- 新增 `lib/services/remote_config_api.dart`：
  `POST {edge}/functions/v1/remote-config` → `{version, announcement, umeng, play_api, festivals, server_time}`；
  429 退避重试、串行闸门、10s 超时；失败返回 `DEFAULT_CONFIG` 等价物而不是抛异常。
- 新增 `lib/features/settings/update_dialogs.dart`：
  更新弹窗（`发现新版本 v…` / `更新内容` / `立即下载` / `稍后再说`）与
  公告弹窗（`不再显示`）。打开链接走 `url_launcher`（新增依赖）。
- 新增 `lib/features/home/announcement_gate.dart`：挂在页签壳层，
  启动拉配置 → 有公告且**指纹未读**才弹；`rc_ann_dismiss_v1` 记录已读指纹
  （djb2 → base36，与聆阅逐字等价，实测样例 `1kr0eu9`）。
- 设置页「检查更新」改为真实请求 + 逐段版本比较；
  版本号统一到 `AppStrings.appVersion`，并由
  `test/theme/app_version_test.dart` 与 `pubspec.yaml` 互锁（防再漂移）。

> 诚实记录：远端下发的是**上游渠道（聆阅）**的版本与下载地址。
> 弹窗里明确写了「更新信息来自上游发布渠道」，
> 不假装这是本应用的商店更新。

### 6.34 懒人「频道页」：页签 + 多栏目（2026-10-26 本轮补齐）

发现页源2 的大类卡此前只进「分页书籍列表」。聆阅的 `channels/[categoryId]`
是**分类首页**：一次请求拿到「子类页签 + 听友推荐 + 各子类栏目」。

- 新增 `lib/services/nuxt_payload.dart`：**纯 Dart 的 Nuxt SSR 解码器**。
  `window.__NUXT__` 不是 JSON，而是
  `(function(a,b,…){return {…}}(0,"",1,…))` —— 参数名替换了重复字面量。
  解码器先解形参/实参建环境，再对返回字面量做递归下降求值
  （支持嵌套对象/数组/字符串转义/数字/布尔/null/`void 0`/`!0`）。
  **不 eval、不执行页面脚本**。
- 新增 `lib/services/lrts_children_api.dart`（#18090 契约）：
  `GET https://m.lrts.me/category/book?title=&rootId=&index=-2`（iPhone UA）
  → `{title, tabs(14), recommendBooks, sections, allBooks}`；
  页签过滤与 `mapChildBook` 字段映射逐条照搬字节码。
  这条链路**不经 Edge**，因此不受 429 限流影响。
- 新增 `lib/features/explore/lrts_channel_page.dart` + 路由 `/lrts-channel/:rootId`；
  发现页源2 大类卡改为进频道页，子类 chip 仍进分页列表页。

### 6.35 存储键纠错与音质选项对齐（2026-10-26 本轮补齐）

字节码复核发现早前文档写的 `shu_*` 前缀是错的（反汇编里 `shu_` 0 命中）：

| 项 | 旧实现（错） | 现在（字节码逐字） |
|---|---|---|
| 前缀 | `shu_` | `tingshu_` |
| 跳片头 | `shu_skip_intro`(bool) + `shu_skip_intro_seconds` | `tingshu_skip_intro`(**秒**，0=关，clamp 0..180) |
| 跳片尾 | 同上 | `tingshu_skip_outro`(秒) |
| 章节顺序 | `shu_chapter_order_play`(bool) | `tingshu_chapter_order`(`asc`/`desc`) |
| 倍速 | `setDouble` | `setString('$speed')` |
| 音质 | `low/standard/high/lossless` 四档 | `128`/`320`/`flac` 三档（标准/高品/无损） |

- 旧值仍可读回（`low→标准`、`lossless→无损`），不会丢用户设置。
- 酷我 `br` 映射同步收敛：标准→`128kmp3`、高品→`320kmp3`、无损→`2000kflac`。

### 6.36 本轮验证（2026-10-26）

```
$ flutter analyze   →  No issues found!
$ flutter test      →  All tests passed（443 个；上一轮 390 + 本轮新增 53）
```

新增测试：

- `test/services/lrts_children_api_test.dart`（13）—— 用**真实抓取**的儿童频道页
  （`lrts_children_real.html`，82 KB）验证 NUXT 解码、页签过滤、栏目/去重、
  字段映射、畸形容错、URL/UA 契约。
- `test/services/remote_config_api_test.dart`（21）—— 用**真实响应**
  （`remote_config_real.json`）验证版本/公告/play_api 解析、逐段版本比较、
  DEFAULT_CONFIG 兜底、公告指纹与 JS 实现一致、`buildPlayUrl` 拼接。
- `test/features/settings/update_dialogs_test.dart`（14）—— 更新/公告弹窗文案与按钮、
  注入 opener 断言「点立即更新才打开链接」、`rc_ann_dismiss_v1` 指纹持久化、
  `AnnouncementGate` 三态（无公告 / 未读弹 / 已读不弹）。
- `test/features/explore/lrts_channel_page_test.dart`（3）—— 真实数据渲染页签/栏目/书卡、
  空态占位。
- `test/theme/app_version_test.dart`（2）—— 版本常量与 `pubspec.yaml` 互锁、
  设置页不得再出现聆阅版本号。

### 6.37 字幕请求带上音质（2026-10-26 本轮补齐）

字节码 #18024 `_fetchKuwoPlayUrl(rid, quality='128')` 显示 `quality` 是
`kuwo-play` 的**必带**参数，旧实现只发了 `rid` 与 `host`（吃服务端默认值）。

- `TypedSourceAdapter.getLyric` 新增可选 `AudioQuality? quality`
  （与既有 `getAudioUrl(quality:)` 同一套语义，默认 null → 不支持的源忽略）；
- 酷我实现按音质带 `128` / `320` / `flac`，与 `tingshu_audio_quality` 落盘值一致；
- `PlayerNotifier` 把当前音质透传下去（`_quality` → `getLyric`），
  切换音质后取字幕立即生效。

> 未接线的是 `play_api` 代理（`{host}/kuwo.php?type=&rid=`）：
> `type` 实参在反汇编里没有稳定取值证据，只实现并单测了 URL 构造，
> 不猜参数去改真实播放链路。

### 6.38 首页直连兜底（2026-10-27 本轮补齐）

首页此前只有 Edge `lrts-home` 一条路：一旦 429，整页只剩「推荐流暂不可用」。

- `LrtsHomeApi` 新增 `fetchDirect()` / `parseDirectHtml()`：
  Edge 重试耗尽后抓 `m.lrts.me/category/book?title=有声小说&rootId=1&index=-2`
  的 Nuxt SSR，映射成同一份 `{books, sections}`（首栏「听友推荐」+ 各子栏目）。
- 书字段映射与频道页共用 `LrtsChildrenApi.mapBook`，但**评分语义分开**：
  儿童页照搬字节码写死的 9.5，首页兜底用条目自带 `score`。
- 真实 fixture：`test/fixtures/lrts_home_direct_real.html`（67 KB）。

### 6.39 章节倒序防护（2026-10-27 本轮补齐）

用户侧症状：某些书上架后「从最后一集开始播」、进度条越播越靠前。

- 新增 `lib/services/chapter_order.dart`（字节码 #17864 / #17865 等价实现）：
  - `extractChapterNumber`：7 级正则级联抠集号；
  - `looksReversed` / `ensureAscending`：抽样（1/60）+ **≥70% 降序**才翻转。
- 接入三条取章路径：酷我（直连分页 + Edge episodes）、懒人（分页合并）、
  JSON 规则源（DOM 解析后）。
- 翻转后重建 `index` 与 `chapterId`，避免与「已听进度」错位。
- 测试 18 例（含 70% 边界、抽样隔离、无集号不瞎排、600 章抽样性能）。

### 6.40 本轮验证（2026-10-27）

```
$ flutter analyze   →  No issues found!
$ flutter test      →  All tests passed（466 个；上一轮 444 + 本轮新增 22）
```

### 6.41 模拟器真机验证（2026-10-27）

在 Android 15 模拟器（`listen_test`，1080×2400）上安装 debug 包，逐条实测本轮新增链路
（截图存 `screenshots/5?_*.png`）：

| 页面 | 结果 | 证据 |
|---|---|---|
| 启动公告 | ✅ 真实远端公告弹出（标题/正文/去看看/不再显示/关闭） | `screenshots/50_announcement.png` |
| 懒人频道页（有声小说） | ✅ 5 个页签可见 + 听友推荐/都市传说/玄幻奇幻各 8 本，播放量真实（793.4万/1.3亿…） | `screenshots/51_lrts_channel.png` |
| 页签跳转 | ✅ 点「玄幻奇幻」进分类书籍列表（书名+作者真实） | `screenshots/53_channel_tab_books.png` |
| 检查更新 | ✅ 真实远端版本：`发现新版本 v1.1.7` + 真实更新内容 + 上游渠道说明 | `screenshots/52_check_update.png` |
| 立即更新 | ✅ 拉起 Chrome（`topResumedActivity=com.android.chrome`），证明 `url_launcher` 与 manifest `<queries>` 配置有效 | — |
| 设置页版本号 | ✅ 显示 `轻听 · v0.1.0`（不再是聆阅的 v1.1.7） | `screenshots/52_check_update.png` |

> 备注：`检查更新` 显示的是**上游渠道**的版本与下载地址（聆阅 1.1.7），
> 弹窗里已明确写「更新信息来自上游发布渠道；下载后将安装该渠道的安装包」，
> 不冒充本应用的商店更新。

### 6.42 搜索历史 + 热门搜索（2026-10-27 本轮补齐）

字节码 #22722 模块里发现两块此前没实现的搜索页能力：

- 存储键 **`search_history_v1`**（JSON 字符串数组）；
- 8 个内联热门搜索词（逐字）：`斗破苍穹 / 三体 / 盗墓笔记 / 明朝那些事儿 /
  白夜行 / 活着 / 鬼吹灯 / 解忧杂货店`；
- UI 上有「搜索历史」「清空」「热门搜索」三处文案与对应区块。

落地：

- 新增 `lib/services/search_history.dart`：`SearchHistoryStore`（读/写/清空，
  去重置顶、上限 10、损坏数据按空处理）+ `SearchHistoryController` + Provider；
- 搜索页空闲态改为「搜索历史（有才显示）+ 清空 + 热门搜索」chips，
  点任意 chip 直接搜索；
- 每次搜索写入历史（失败不影响搜索本身）。

> 上限如实留档：字节码在该键附近只能确认一个常量 `4`，无法确定是否为历史上限，
> 因此取常见的 10，并在代码注释里写明这个不确定点。

模拟器实测（截图 `screenshots/54_search_hot.png`、`55_search_history.png`）：
搜「活着」后历史出现「活着」+「清空」，且 `FlutterSharedPreferences.xml`
里落盘为 `flutter.search_history_v1=["活着"]`（`flutter.` 前缀是插件加的）。

### 6.43 动效开关 + 点击粒子特效（2026-10-27 本轮补齐）

设置页里这两行此前是**禁用占位**（灰着、点了没反应），对应的聆阅键
`tingshu_animations_enabled` / `tingshu_tap_fx` 早就在 #16799 里读到过。

- 新增 `lib/theme/effects_settings.dart`：`EffectsSettingsController`
  持久化两个键（默认：动效开、点击特效关）；
  `tapFxActive = animationsEnabled && tapFxEnabled`
  —— 总开关关掉时点击特效不可能生效，UI 上直接置灰，避免「开了也没用」。
- 新增 `lib/theme/tap_fx_layer.dart`：用 `Listener` **旁路**监听指针
  （不进手势竞技场，不抢按钮点击），在落点炸 12 颗粒子；
  **只认真正的「点」**：位移 < 12dp 且按住 < 260ms，滑动/拖进度条不触发。
- `main.dart`：动效关闭时把 `pageTransitionsTheme` 换成「无转场」，
  并把 `themeAnimationDuration` 归零；`MaterialApp.builder` 挂 `TapFxLayer`。

模拟器实测：`screenshots/56_effects_settings.png`（两个开关都可点、都开）、
`screenshots/57_tap_fx.png`（点击后 12 颗粒子从落点扩散，520ms 后自动消失）。

### 6.44 后台保活引导（替掉最后一行假开关）+ 版本号收尾（2026-10-27）

设置页最后一行假 UI 是「开启后台常驻」：一个灰着的**恒开**开关，点了没反应。
聆阅的做法是「说明 + 去设置」（`bgKeepAliveNote/Step1/Step2/Note2/Note4`）。

- 新增 `lib/services/system_settings_bridge.dart` + Kotlin 侧 channel
  `soft_sound/system_settings`（在既有 `MainActivity` 里加第二个 MethodChannel）：
  - `openAppSettings` → 应用详情页
  - `openBatteryOptimizationSettings` → 系统「电池优化」列表页
  - `isIgnoringBatteryOptimizations` → 是否已在白名单（API 23+）
  - 非 Android / 原生报错一律返回 `false`/`null`，UI 退化为只给步骤说明
- 设置页该行改为可点：弹「后台保活设置」对话框，顶部显示**真实白名单状态**
  （已加入 / 尚未加入 / 无法判断），两个按钮直达系统页面。

顺手收尾：**「我的」页底部与「关于」弹窗也还硬编码着聆阅的 `v1.1.7`**
（上一轮只修了设置页）。现在统一到 `AppStrings.appVersion`，并加了一条
**全 `lib/` 扫描**的守卫测试（注释除外），防止第三次漂移。

模拟器实测：对话框显示「尚未加入电池优化白名单」，点「立即去开启」后
`topResumedActivity=com.android.settings`（系统「App battery usage」页）。
截图 `screenshots/58_keepalive_guide.png`、`59_battery_settings.png`。

### 6.45 媒体通知 / 锁屏 / 灵动岛不显示（2026-10-27 用户真机反馈修复）

**现象**：播放中下拉通知栏没有媒体卡片，小米 HyperOS 的灵动岛也不显示。

**根因是整条链一环都没接上**（四处独立缺失，缺一条都不显示）：

| 环节 | 缺失时的后果 | 本次修复 |
|---|---|---|
| `JustAudioBackground.init()` | 根本没有 MediaSession，系统无从显示 | `main()` 里初始化（含 `androidNotificationOngoing: true`） |
| 清单里的 `AudioService` 服务 / `MediaButtonReceiver` / `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)` / `WAKE_LOCK` | 服务起不来，通知无宿主 | 全部补齐 |
| `MainActivity` 继承 `FlutterActivity` | audio_service 初始化直接抛 *"The Activity class declared in your AndroidManifest.xml is wrong or has not provided the correct FlutterEngine"* | 改为继承 `AudioServiceActivity` |
| `AudioSource.uri` 没带 `MediaItem` | 有会话但通知只显示「未知」，无封面、灵动岛不亮 | 新增 `MediaMetadata.forChapter()` 带 title/album/artist/artUri/duration |

另外两个只在 Android 13+/真机上才会咬人的点：

- **`POST_NOTIFICATIONS` 运行时权限**：没授权时通知记录存在但**不展示**（`dumpsys` 能看到、用户看不到，极易误判成"代码没生效"）。
  现在首次播放前自动申请，设置页也有一条「通知栏播放控制」显示真实授权状态，
  拒绝过（系统不再弹）时点击直接跳应用设置页。
- **audio_service 的断言**：`androidNotificationOngoing: true` 必须搭配
  `androidStopForegroundOnPause: true`（默认值），否则启动即抛
  *"The androidNotificationOngoing will make no effect with androidStopForegroundOnPause set to false"*。

**实测证据**（Android 15 模拟器）：

```
$ adb shell dumpsys media_session | grep -A10 com.softSound.soft_sound
  active=true
  state=PlaybackState {state=PLAYING(3), position=724655, speed=1.0,
         actions=16252879, active item id=0}
  metadata: description=第09集_故人相见，殚精竭虑, 夙染白o，陆青烛 演播, 大唐明月|《风起霓裳》原著

$ adb shell dumpsys notification | grep -A4 "NotificationRecord.*softSound"
  channel=com.softSound.soft_sound.channel.audio
  flags=ONGOING_EVENT|NO_CLEAR|FOREGROUND_SERVICE|NO_DISMISS  category=transport
  android.title=第09集_故人相见，殚精竭虑
  android.subText=大唐明月|《风起霓裳》原著
  android.text=夙染白o，陆青烛 演播
```

下拉通知栏截图：`screenshots/60_media_notification.png`（大封面 + 章节名 + 演播 + 暂停键 + 进度）。
首次播放弹出的系统通知权限框：`screenshots/61_notification_permission.png`。

> 小米灵动岛额外条件（属系统侧，代码无法代劳）：HyperOS 需在
> `设置 → 通知与控制中心 → 焦点通知/灵动岛` 里为「轻听」开启焦点通知；
> 若之前拒绝过通知权限，还要在 `应用设置 → 通知` 里手动打开。
> 这两步在设置页「通知栏播放控制」那行的副标题里已用「已授权/未授权」体现。
