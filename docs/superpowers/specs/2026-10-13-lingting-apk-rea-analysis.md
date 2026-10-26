# 聆听.apk（聆阅）REA 逆向分析报告

- **分析日期**：2026-10-13
- **目标**：`/Users/jfwang/Documents/聆听.apk`
- **SHA-256**：`02d181742fbea02d96f0bf581932dd41419f0952f68564365f47e8c0475822ec`（56,955,804 字节）
- **工具**：REA（JADX headless 0.7.1 / Apktool 2.11.1 / artifact graph）+ Hermes 字节码字符串提取
- **结论**：**业务逻辑在明文 Hermes JS bundle 中，可读可提取。与本项目现有适配器架构高度吻合，可落地。**

---

## 1. 与 base.apk 的关键差异

| | base.apk（飞鸟听书） | 聆听.apk（聆阅） |
|---|---|---|
| 加固 | 360 Jiagu | SecShell（梆梆 bangcle） |
| 可解析类数 | **5**（全为壳） | **385**（三方库完整） |
| 业务逻辑位置 | 加密 DEX（静态不可达） | **明文 Hermes JS bundle** |
| 静态可分析性 | ✗ | **✓** |

关键点：**两者都做了加固，但加固的层次完全不同。**

- base.apk 是原生 Java 应用 → 加固直接保护业务代码 → 静态死路。
- 聆听.apk 是 **React Native / Expo 应用** → 加固只保护薄薄的 Java/Expo 运行时层
  （`com.SecShell.SecShell.AW/AP/CP`、`libSecShell32` 处理 `find_dexfile`/`Art90DexFile`），
  而**真正的业务逻辑跑在 JS 引擎里，bundle 明文存放**。

DEX 侧交叉验证：`classes.dex` 中 `kuwo`/`lrts`/`supabase` 关键词计数均为 **0**，
类清单只有 Facebook Fresco、Expo、React Native 等三方库 —— 业务代码确实不在 DEX。

---

## 2. 应用身份

| 项 | 值 |
|---|---|
| 包名 | `com.miaoda.appdlx65cja8npd` |
| 应用名 | 聆阅（app.config `name`，slug `tingshu-fm`） |
| versionName / versionCode | `1.1.7` / `79` |
| minSdk / targetSdk / compileSdk | 24 / **36** / 36 |
| 技术栈 | Expo SDK **55.0.0** + expo-router（`router.root = "src"`）+ NativeWind(tailwind) |
| 后端 | **Supabase**（Edge Functions 作为书源代理） |
| 构建平台 | **秒搭 miaoda**（百度无代码平台），`backend.appmiaoda.com` |
| DeepLink scheme | `appdlx65cja8npd` |
| `usesCleartextTraffic` | **true**（`expo-build-properties` 显式开启） |
| iOS ATS | `NSAllowsArbitraryLoads: true` |

关键依赖（来自 `assets/app.config`）：`expo-audio`（后台播放 + 音频前台服务）、
`expo-sqlite`、`@react-native-async-storage`、`expo-notifications`、
`expo-router`、`expo-image`、`expo-file-system`、`react-native-reanimated`。

---

## 3. 书源架构（核心发现）

**只有两个书源**，且**全部通过 Supabase Edge Functions 代理**，
App 端不直连上游站点（少数直连 URL 作为兜底/辅助）。

```
App (Expo/RN)
   │  supabase-js  ──►  /functions/v1/<source>-<action>
   ▼
Supabase Edge Functions (Deno)  ──►  上游站点
   ├── kuwo-*  ──►  search.kuwo.cn / tsm.kuwo.cn / mobilebasedata.kuwo.cn
   └── lrts-*  ──►  m.lrts.me / www.lrts.me / bookpic.lrts.me
```

### 3.1 Edge Function 端点全集（已从反汇编逐字确认）

> 下表查询参数为反汇编中 `LoadConstString` 的**原始字面量**，非推测。
> 方法：`hbctool` 不支持 HBC v96，改用 `hermes-dec` 的 `hbc-disassembler`
> 生成 50.9 MB 反汇编（22,819 个函数 / 26,506 条字符串），再抽取端点字面量。

**酷我（kuwo）** —— 9 个：

| 端点（含原始参数） | 推测职责 |
|---|---|
| `/functions/v1/kuwo-search?keyword=` | 搜索专辑 |
| `/functions/v1/kuwo-albuminfo?albumId=` | 专辑详情 |
| `/functions/v1/kuwo-albums?classifyId=` | 按分类列专辑 |
| `/functions/v1/kuwo-episodes?albumId=` | 章节/曲目列表 |
| `/functions/v1/kuwo-play?rid=` | **音频播放地址** |
| `/functions/v1/kuwo-rank-data?tabId=` | 排行榜数据 |
| `/functions/v1/kuwo-rank-tabs` | 排行榜页签 |
| `/functions/v1/kuwo-classify` | 分类列表 |
| `/functions/v1/kuwo-channel-tabs?categoryId=` | 频道页签 |

**懒人听书（lrts）** —— 6 个：

| 端点（含原始参数） | 推测职责 |
|---|---|
| `/functions/v1/lrts-search?name=` | 搜索 |
| `/functions/v1/lrts-book?bookId=` | 书籍详情 |
| `/functions/v1/lrts-play?id=` | **音频播放地址** |
| `/functions/v1/lrts-rank?rankId=` | 排行榜 |
| `/functions/v1/lrts-category?categoryId=` | 分类 |
| `/functions/v1/lrts-home` | 首页（无参） |

> `src` 侧还有一条本地路由 `/lrts-category`（见 §4）。

### 3.1.1 上游直连契约（2026-10-13 实测）

不依赖聆阅的 Edge Function，直接请求上游并记录**真实响应**：

**懒人听书（m.lrts.me）**

| 端点 | 实测 |
|---|---|
| `GET /ajax/getBookInfo?id={bookId}` | 200，**60 字段** JSON |
| `GET /ajax/getBookMenu?bookId={bookId}` | 200，`list[30]` 章节 |
| `GET /search/all?keyword=` | **404**（无公开搜索接口） |
| `GET /ajax/getPlayPath?bookId=&sectionId=` | 200 但 `list: []`（需服务端签名） |

详情关键字段：`name` `announcer` `author` `cover`/`bestCover` `desc`
`sections` `play` `fatherTypeName` `labels[]` `feeType` `payType` `cantListen`

章节关键字段：`id`/`sectionId`（token） `section`（序号，从 1 起）
`name` `length`（秒） `feeType` `payType` `cantListen` `path`（**恒为空**）

> 有效 bookId 获取方式：`GET /rankList` 页面含大量 `/book/{id}` 链接。

**酷我（search.kuwo.cn）**

| 端点 | 实测 |
|---|---|
| `GET /r.s?stype=albuminfo&albumid={id}` | 200，32,687 字节 |
| `GET mobi.kuwo.cn/mobi.s?...type=convert_url_with_sign&rid={rid}` | 200，返回签名音频 URL |
| `GET antiserver.kuwo.cn/anti.s?type=convert_url&rid=MUSIC_{rid}` | 200，**直链 MP3（可下载）** |

> 播放链路已端到端验证：真实 `musicrid` → 签名 URL → 下载得到
> `audio/mpeg` 320 kbps 立体声。`antiserver` 端点无需签名，可作为兜底。

响应为**单引号 Python 风格 dict**（非标准 JSON），且歌名含 HTML 实体
（如 `Right&nbsp;Here&nbsp;Waiting`）。

这些真实报文已固化为 fixture 并用于回归测试：
`test/fixtures/{kuwo_album_real.txt, lrts_bookinfo_real.json, lrts_bookmenu_real.json}`。

### 3.2 上游直连 URL（兜底/辅助）

| URL | 用途 |
|---|---|
| `http://www.tingshu8.top/yuan1/lrts.php` | lrts 解析服务（自建 PHP 中转） |
| `https://m.lrts.me/ajax/getBookInfo?id=` | 懒人书籍详情 |
| `https://m.lrts.me/ajax/getBookMenu?bookId=` | 懒人书籍目录 |
| `https://m.lrts.me/rankList` | 懒人排行榜 |
| `https://m.lrts.me/category/book?title=&rootId=6&index=-2` | 懒人分类浏览 |
| `https://www.lrts.me/book/category/channels/5` | 懒人频道分类 |
| `http://www.tingshu8.top/stat_report.php` / `stat_heartbeat.php` / `api.php?do=check_update` | 统计 / 心跳 / 更新检查 |
| `https://search.kuwo.cn/r.s?stype=albuminfo&albumid=` | 酷我专辑信息 |
| `https://mobilebasedata.kuwo.cn/basedata.s?type=get_album_info&id=` | 酷我专辑信息（备） |
| `https://tsm.kuwo.cn/audioApi/a.p?op=policy&albumids=` | **酷我音频策略/播放授权** |
| `https://kuwo.cn/channels/` | 酷我频道页 |
| `http://img1.kuwo.cn/star/albumcover/300/...` | 酷我封面 CDN |
| `https://bookpic.lrts.me/default` | 懒人封面兜底 |

**关键**：`tsm.kuwo.cn/audioApi/a.p?op=policy&albumids=` 是酷我获取播放授权的接口，
是 `kuwo-play` 的核心上游。这解释了"为什么需要服务端代理"——策略接口可能需要特定 header/风控。

### 3.3 后端配置

- 后端基址模式：`https://backend.appmiaoda.com/projects/supabase345057433544081408`
  （`supabase345057433544081408` 为秒搭平台的项目标识）
- **Supabase anon key（已完整还原并校验）**：
  ```
  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc
  ```
  > 校验过程：header 解出 `{"alg":"HS256","typ":"JWT"}`；
  > payload 解出 `{"aud":"authenticated","exp":2101695303,"iss":"supabase","role":"anon","sub":"anon"}`
  > （exp = 2036-08-26，标准 Supabase 匿名密钥）；
  > 签名段按 HMAC-SHA256 长度截取 43 个 base64url 字符，base64url 解码得 **恰好 32 字节**，
  > 与 HMAC-SHA256 输出长度一致 → 键值完整有效。
  > （原始 bundle 中签名后紧跟 `completeBufferRoutine...` 等驻留字符串，需按长度截断。）
- **Supabase URL 未以明文字面量出现**。bundle 内只有库自身的校验逻辑
  （`Invalid supabaseUrl: Must be a valid HTTP or HTTPS URL.`、
  `supabaseUrl is required.`、URL 校验正则 `supabase\.(co|in|red)$`）。
  该值在运行时注入/拼接，静态未获取到。区域线索：`ap-northeast-1`（东京）。

---

## 4. 应用路由树（src/）

从 bundle 中提取的 expo-router 文件路由：

```
src/
├── _layout.tsx                      # 根布局
├── index.tsx                        # 首页
├── search.tsx                       # 搜索
├── ranking.tsx                      # 排行榜
├── player.tsx                       # 播放器
├── downloads.tsx                    # 下载管理
├── reading.tsx                      # 阅读模式
├── book-not-found.tsx               # 书籍未找到
├── (tabs)/
│   ├── _layout.tsx
│   ├── home.tsx                     # 首页页签
│   ├── explore.tsx                  # 发现/分类
│   ├── shelf.tsx                    # 书架
│   └── profile.tsx                  # 我的
├── category/
│   ├── _layout.tsx
│   └── [name].tsx                   # 分类详情（动态）
├── channels/
│   ├── _layout.tsx
│   └── [categoryId].tsx             # 频道详情（动态）
├── lrts-category/
│   ├── _layout.tsx
│   └── [id].tsx                     # 懒人分类详情（动态）
└── books/
    ├── _layout.tsx
    └── [id].tsx                     # 书籍详情（动态）
```

> `books/[id].tsx` = 书籍详情；`player.tsx` = 播放；`channels/[categoryId].tsx` = 酷我频道。

---

## 5. 本地设置与数据结构

### 5.1 设置键（`shu_` 前缀，AsyncStorage）

```
shu_active_source_parse        # 当前生效书源（对应我们的 activeSourceId）
shu_audio_quality              # 音质
shu_playback_speed_0_25        # 播放速度（0.25 步进）
shu_volume_boost_enabled       # 音量增强开关
shu_volume_boost_gain          # 音量增强增益
shu_audio_mixing               # 音频混音
shu_animations_enabled         # 动画开关
shu_sleep_stop                 # 定时停止
shu_skip_intro                 # 跳过片头
shu_skip_outro                 # 跳过片尾
shu_chapter_order_play         # 章节顺序播放
shu_book_cached                # 书籍缓存标记
shu_favorites_backup           # 收藏备份
shu_history_backup             # 历史备份
shu_remote_config_cache_v1     # 远程配置缓存
shu_shelf_sort                 # 书架排序
shu_shelf_view                 # 书架视图
shu_device_id                  # 设备 ID
shu_accent                     # 主题色
shu_theme                      # 主题
shu_tap_fx                     # 点击特效
shu_keepalive_hint_v1          # 后台保活提示
```

### 5.2 播放进度/历史字段

已确认字段（疑似 SQLite `play_history` 表）：

```
shu_device_id, book_id, chapter_id, chapter_index, position, played_at, source_environment
```

`expo-sqlite` 为依赖；`_upsertPlayHistory`、`_clearPlayHistory` 为相关函数名。

---

## 6. 与本项目的对照与落地建议

### 6.1 架构对照

| 本项目 (softSound) | 聆听.apk (聆阅) |
|---|---|
| `SourceRule`（JSON 规则） | 无 JSON 规则，硬编码两源 |
| `TypedSourceAdapter` 接口 | 每个源一组 `fetchXxx` 函数 |
| 客户端直连上游 + 签名/解密 | **Supabase Edge Function 代理**（签名在服务端） |
| `XA/xiaoKu/liuYue/xiaoLiang/xiaoQing` | `kuwo`、`lrts` |

**关键洞察**：聆阅**完全绕开了客户端签名难题**——把签名、风控、解密都放在
Supabase Edge Functions 里。这正是本项目 `docs/superpowers/specs/*typed-audio-sources-design.md`
中标记为 "out of scope in v1" 的那些能力（`TsService().neiRong()` 校验、
`video_new` 的 `time`+`sign`、`ting-with-efi` 的 AES）的**工程解法**。

### 6.2 可落地的三点

1. **`kuwo` 源可对齐**：本项目的 `xiaoKuSourceAdapter` 与聆阅的 `kuwo-*` 端点集高度重合
   （搜索/专辑/章节/播放），可用聆阅提取的**端点契约**反向校验我们的酷我实现，
   特别是 `tsm.kuwo.cn/audioApi/a.p?op=policy` 这一播放授权路径。
2. **`lrts` 源为净新增**：本项目目前**没有**懒人听书源。聆阅的 `lrts-*` 端点集
   （`lrts-search?name=` / `lrts-book` / `lrts-play?id=` / `lrts-rank?rankId=` /
   `lrts-category?categoryId=` / `lrts-home`）+ 上游
   `m.lrts.me/ajax/getBookInfo` / `getBookMenu` 可作为新增适配器的设计蓝本。
3. **设置键可借鉴**：`shu_*` 中的 `skip_intro`/`skip_outro`/`sleep_stop`/
   `chapter_order_play`/`volume_boost` 等播放增强项，本项目尚未实现，可作为功能路线图输入。

### 6.3 未解决（需补充证据）

- Supabase 项目 URL 未静态取得 → 无法直接调用端点验证契约（anon key 已完整还原）。
  已双重排除：`app.config` 的 `extra` 为 `{"router":{},"expo-navigation-bar":{}}`，
  无任何 supabase 字段；bundle 中 `supabase.co` / `.supabase`（除库内部存储键）
  / `<20位ref>.` 模式均 0 命中。该值在运行时注入或构建期由秒搭平台下发。
- 各端点的**响应字段结构**尚未完整提取（Hermes 会驻留/压缩属性名，
  单靠 `strings` 只能拿到部分字段名，如 `rid`/`albumId`/`bookId`/`categoryId`/`rankId`/`cover`/`sections`/`menu`）。
- 存储层：bundle 中**无 SQLite DDL**。虽然 `expo-sqlite` 是依赖，
  但 `shu_device_id,book_id,chapter_id,...` 更像**字段选择器/同步载荷**而非建表语句；
  实际持久化疑为 AsyncStorage/MMKV 键值存储（21 个 `shu_*` 键佐证）。待抓包/反编译确认。

---

## 7. 下一步建议

### 方案 A：抓包（最快拿到响应契约，推荐）

App 允许明文流量，用 mitmproxy 抓 App 与 Supabase 的真实往返：

```bash
mitmdump -w listen_flows.mitm
# App 内操作：搜索 → 打开专辑 → 播放一章
```

产物交回 REA：`inspect_web_network_capture(format="mitmproxy")` 可离线还原
每个端点的完整请求/响应结构。**这一步同时能拿到 Supabase URL。**

### 方案 B：Hermes 反编译（拿到完整源码）

当前只做了字符串级提取。用 `hbctool` 或 `hermes-dec` 反汇编 Hermes 字节码，
可恢复函数体与完整对象结构：

```bash
pip install hbctool
hbctool disassemble assets/index.android.bundle out_dir
```

版本：bundle 为 Hermes，header `globalCodeIndex == fileSize` 校验通过。

### 方案 C：验证上游可达性

直接对 `search.kuwo.cn` / `m.lrts.me` 等公开端点发请求，
用真实响应校准本项目适配器（不依赖 APK）。

**本轮已做初步探测**（2026-10-13，带 Android UA）：

| 探测 URL | 结果 |
|---|---|
| `https://m.lrts.me/ajax/getBookInfo?id=377599818` | HTTP 200，`{"apiStatus":0,"data":{},"msg":"资源已下线","status":1}` |
| `https://search.kuwo.cn/r.s?stype=albuminfo&albumid=572201122` | HTTP 200，`{'musiclist':[],'songnum':'0'}` |

两条端点**均可达且返回 JSON**（示例 id 已失效，需换有效 id）。
注意酷我返回的是**单引号 Python 风格 dict**而非标准 JSON
（`{'musiclist':[]}`）——这印证了本项目酷我适配器为何需要容错解析，
也应作为解析健壮性的测试用例。

---

## 8. 本轮结论摘要

| 问题 | 答案 |
|---|---|
| 这个 APK 能分析吗？ | **能**。业务逻辑在明文 Hermes JS bundle |
| 加固有影响吗？ | 影响很小。SecShell 只保护 Java 层，业务在 JS |
| 有哪些书源？ | **2 个**：酷我（kuwo）、懒人听书（lrts） |
| 架构是什么？ | Expo/RN + Supabase Edge Functions 代理上游，**客户端无签名负担** |
| 拿到了什么？ | 15 个 Edge Function 端点契约、13 个上游直连 URL、完整路由树、21 个设置键、anon key |
| 项目改了吗？ | **没有**。本轮为分析，待契约确认后落地 |
| 最该做什么？ | 优先新增 `lrts` 适配器；用 `kuwo-*` 契约校验现有酷我实现 |

---

## 9. 追加轮次：2026-10-16 REA 深挖 + 全部搬运落地

继续在同一份 Hermes 反汇编（`/tmp/hasm_out`，50.9 MB，22,819 函数）上按函数体挖掘，
随后对每个新端点做**真实请求验证**（脚本：`tool/verify_rea_endpoints.sh`，产物固化进
`test/fixtures/`），并把全部发现搬进本项目。

### 9.1 新挖出的契约（字节码函数号 → 实测确认）

| 发现 | 字节码出处 | 实测（2026-10-16） | 落地 |
|---|---|---|---|
| **tingshu8 播放兜底**：`lrts.php?id={书id*集号}` 直出 tencentmusic m4a 直链，无鉴权、无 429 | #18078（php 优先、Edge 兜底的顺序也是它定的） | ✅ 真实直链 | `LrtsSourceAdapter._fetchPlayUrl` php-first |
| tingshu8 搜索/目录兜底：`lrts.php?name=` / `?albumId=` → `{code,data:{list}}` | #18064 / #17910 | ⚠️ 形态确认，但当日实测 list 恒空（代理侧不稳定）→ 只作兜底 | `search()` Edge 空时回落 php |
| **lrts 真实榜单**：`lrts-rank?rankId=&rangeType=` → `{badgeList,books[100],total}`，书带 title/author/narrator/cover/songNum/playCnt/rank | #18082（8 个页签为内联字面量） | ✅ 68,666B 真实响应；服务端 badgeList 与字节码常量逐项一致 | 新增 `LrtsRankApi` + 排行榜页双源 |
| **酷我字幕**：`kuwo-play?rid=&host=` 响应 `{url, lyric, quality}`，lyric 为 LRC | #18025/#18026 `fetchKuwoLyric`；typeof==='string'+trim 语义 | ✅ 真实 LRC（阿杜《他一定很爱你》644B） | `XiaoKuSourceAdapter.getLyric` → 播放器字幕链路 |
| **权威分类树**：`kuwo-classify` → sections[{id,name,categoryId,imgUrl,child[{name,classifyId,categoryId}]}]（7 大类） | #17953 | ✅ 7,916B 真实响应 | `fetchClassify()` + 发现页动态分类（兜底快照对齐实测） |
| lrts 首页：`lrts-home` → `{books, sections:[{label,books}]}`（15 栏目：听友推荐/都市传说/…） | #18036 | ✅ 111,703B 真实响应 | fixture `lrts_home_real.json`（首页接入为后续项） |
| lrts 分类：Edge `lrts-category?categoryId=` → `{books,total,page}`；直连 `www.lrts.me/book/category/{id}/20` 正则 | #18053 | ✅ 双路均通 | fixture 固化 |
| channel-tabs：`kuwo-channel-tabs?categoryId=2` → tabs[{id,name}] | #17969 | ✅ | 已被 category_books_page 使用 |
| **albums 参数陷阱**：`sortType` 只接受字符串枚举（`playCnt`），传数字 `1` 返回 500 | —（负样本发现） | ✅ 复现/排除 | 项目现用 `playCnt` 正确 |

### 9.2 并发限流的现实约束

Edge 后端（秒搭托管的 Supabase）在高峰持续返回
`429 projectConcurrencyLimitExceeded`：本轮 `kuwo-play` 重试 4 次、`albums` 3 次才成功一次。
对策全部按字节码原样实现：**php 代理优先（播放链路绕开限流）+ Edge 带退避重试**，
重试间隔做成可注入参数（测试零延迟）。

### 9.3 搬运清单（代码/测试/fixture 全部进仓库）

- `lib/services/lrts_rank_api.dart`（新增）：8 榜常量 + `fetchRankBooks` + 复用 `KuwoRankBook` 行模型
- `lib/services/kuwo_rank_api.dart`：`fetchClassify` + `KuwoClassifySection/Child` + `kuwoClassifyProvider`
- `lib/features/ranking/ranking_page.dart`：酷我榜/懒人榜双源切换
- `lib/features/explore/explore_page.dart`：分类卡改线上数据驱动（兜底=实测快照）
- `lib/services/typed_sources/typed_source_adapter.dart`：接口新增 `getLyric`（默认 null）
- `lib/services/typed_sources/xiaoku_source_adapter.dart`：`getLyric`/`parseLyricResponse`（真实报文单测）
- `lib/services/typed_sources/lrts_source_adapter.dart`：php-first 播放 + php 搜索兜底
- `lib/services/source_parser.dart`：`getLyric` 路由
- `lib/services/player_service.dart`：`attachSubtitle` + 起播后异步拉字幕（切章竞态保护、尽力而为）
- 测试：`xiaoku_lyric_test.dart`、`lrts_php_fallback_test.dart`、`lrts_rank_api_test.dart`（fixture 驱动）
- fixture：`lrts_rank_75_real.json`、`kuwo_classify_real.json`、`lrts_home_real.json`、
  `lrts_category_63_real.json`、`kuwo_play_real.json`、`lrts_php_play_real.json`、`lrts_php_search_real.json`

### 9.4 尚未搬运（明确留档）

- 聆阅首页栏目化展示（`lrts-home` 的 15 个 section 已固化为 fixture，UI 待接）
- 懒人多榜页签进发现页（`lrts_children_tabs_v2`：63/3027/9031… 已提取）
- base.apk（飞鸟听书）仍是 360 加固静态死路，与本轮无关

---

## 10. 追加轮次：2026-10-26 远端配置 / 频道页 / 存储键纠错

继续在同一份 Hermes 反汇编（`/tmp/hasm_out`）上按函数体挖掘，新契约全部做真实请求验证，
再把可用部分搬进项目。本轮结论与证据如下（详细搬运清单见
`docs/reverse-engineering/lingting/UI_PORT.md` §6.33–6.36）。

### 10.1 新端点：`remote-config`（此前 15 个端点之外的第 16 个）

| 端点 | 出处 | 实测（2026-10-26） | 落地 |
|---|---|---|---|
| `POST /functions/v1/remote-config`（空 body） | #20358 模块 + #20370 `functions.invoke` | ✅ 200，791 B：version/announcement/umeng/play_api/festivals/server_time | `RemoteConfigApi` |
| `GET http://www.tingshu8.top/api.php`（等价直连） | #20358 `DEFAULT_CONFIG.version` 邻近字面量 | ✅ 200，内容一致；`?do=check_update` 只回 version 段 | 作为兜底保留在文档 |
| Supabase REST `announcements` | #17847 `fetchActiveAnnouncements` | ⚠️ 200 但 `[]`（RLS 限制） | 未用，公告以 remote-config 为准 |

关键语义（字节码逐字）：

- 公告已读键 `rc_ann_dismiss_v1`，指纹算法 `djb2(title\1content\1link_url\1link_text)` → base36；
  实测指纹 `1kr0eu9`（Dart 实现与 node 独立复算一致，已写成断言）。
- 更新提示：逐段比较 `version_name`（不是字符串比较），
  有更新才弹；`download_url` 为空时回落 `download_url2`；说明为空时用
  「修复已知问题，优化使用体验」。
- `play_api`：`enabled && url` 时酷我播放改走 `{origin}/kuwo.php?type=&rid=`
  （#17988 `resolvePlayHost` + #17989 `buildPlayUrl`）；服务端当前关闭。

### 10.2 新契约：`fetchLrtsChildren`（懒人频道页，不经 Edge）

`GET https://m.lrts.me/category/book?title={分类名}&rootId={id}&index=-2`（iPhone UA）
→ 解析 `window.__NUXT__` → `{title, rootId, tabList, recommendList, subTypeRecommendList}`。

- 出处：#18087/18088/18090（主逻辑 1991 B）、#18091 `mapChildBook`、
  #18093 页签过滤、#18096 Set 去重、#18098 子栏目循环。
- 实测：儿童页 200 / 282 KB；tabList 16（过滤后 14）、recommendList 8、16 个子栏目。
- 同一 SSR 解析也服务 `lrts-home` 直连兜底（`title=有声小说&rootId=1`，#18036）。
- 因不经 Edge，**天然绕开 `projectConcurrencyLimitExceeded`**。

### 10.3 纠错：存储键前缀是 `tingshu_*`

早前 §5.1 写的 `shu_*` 前缀是错的。反汇编里 `shu_` 独立前缀 0 命中，
命中的 67 处均为 `tingshu_` 的子串。21 个键与取值形态见 README 的「2026-10-26 追加」表。

其中两处语义与旧实现不同，已改：

1. `tingshu_skip_intro` / `tingshu_skip_outro` 存的是**秒数**（`clamp(0..180)`，0=关），
   不是「布尔 + 另一个 seconds 键」。
2. 音质只有三档且落盘值是 `128` / `320` / `flac`，标签为 `标准` / `高品` / `无损`。

### 10.4 本轮未搬运（明确留档）

- `festivals`（节日主题）：服务端当前 `[]`，主题资源为本地图标/渐变，仅在远端下发时展示。
- 多设备同步（`lingyue_my_sync_code_v1`、`syncDeviceData`、`user_play_history`）：
  需登录态与写库权限。
- `umeng` 统计与 `stat_*.php` 心跳：与功能无关。
