# 聆阅 APK 逆向产物

本目录保存从 `聆听.apk`（聆阅 FM，`com.miaoda.appdlx65cja8npd` v1.1.7）提取的
**派生数据**，供后续书源适配器开发与 UI 对齐参考。

## 文件

| 文件 | 说明 |
|---|---|
| `hermes-strings.txt` | 从 Hermes 字节码提取的全部唯一内联字符串（16,028 条），含 UI 文案、端点、字段名、存储键 |

> **未保存原始 `index.android.bundle`**：那是第三方版权二进制，不应提交进本仓库。
> 需要时按下方步骤从 APK 重新生成。

## 分析报告

完整分析见 [`../../superpowers/specs/2026-10-13-lingting-apk-rea-analysis.md`](../../superpowers/specs/2026-10-13-lingting-apk-rea-analysis.md)。

## 如何重新生成

APK 的 Java 层被 SecShell（梆梆）加固，但**业务逻辑在明文 Hermes JS bundle 中**，
可直接反汇编。`hbctool` 不支持 HBC v96，需用 `hermes-dec`：

```bash
# 1. 解包（bundle 位于 assets/）
unzip -o "/path/to/聆听.apk" -d /tmp/apk2
# /tmp/apk2/assets/index.android.bundle  (3.79 MB, Hermes v96)

# 2. 安装工具（hbctool 仅用于早期版本；v96 需 hermes-dec）
python3 -m venv /tmp/hbctool_env
/tmp/hbctool_env/bin/pip install hermes-dec

# 3. 查看文件头（确认版本与规模）
/tmp/hbctool_env/bin/hbc-file-parser /tmp/apk2/assets/index.android.bundle
#   Version 96 / FunctionCount 22819 / StringCount 26506

# 4. 反汇编（约 51 MB 文本）
/tmp/hbctool_env/bin/hbc-disassembler /tmp/apk2/assets/index.android.bundle /tmp/hasm_out

# 5. 提取唯一字符串
grep -oE "# String: '([^']*)'" /tmp/hasm_out \
  | sed "s/# String: '//; s/'$//" | sort -u > hermes-strings.txt
```

## 已确认的关键事实

- **书源仅 2 个**：酷我（`kuwo-*`，9 个端点）、懒人听书（`lrts-*`，6 个端点）
- **全部经 Supabase Edge Functions 代理**，客户端不承担签名/解密
- Supabase anon key 已完整还原（见分析报告 §3.3）
- **Supabase URL 不在 APK 内**（`app.config` 无该字段，bundle 中 0 命中）
- 主题色板（`getThemeColors`）已还原并移植进 `lib/theme/app_theme.dart`

## 2026-10-16 追加（函数体级深挖 + 真实验证）

反汇编 `/tmp/hasm_out` 仍在按函数体挖掘后新增确认：

- **lrts-rank 榜单**：8 页签常量（热播75/新书738/热搜77/好评76/收藏14479/完结739/免费14481/会员740，
  rangeType 1|3），响应 `{badgeList, books[100], total}`（#18082）
- **tingshu8 兜底代理**：`lrts.php?id|name|albumId`（#18078/#18064/#17910）；
  `?id=` 实测直出 m4a 直链；`?name|albumId` 形态确认但当日返回空列表
- **酷我字幕**：`fetchKuwoLyric(rid, host)` 实为再调 `kuwo-play?rid=&host=` 取 `lyric`（#18025/#18026）
- **kuwo-classify 权威分类树**：7 大类 + child(classifyId/categoryId)（#17953）
- **lrts-home**：`{books, sections:[{label,books}]}` 15 栏目（#18036）
- **albums sortType 必须是字符串枚举**（`playCnt`；传数字 500）

复验脚本：[`../../../tool/verify_rea_endpoints.sh`](../../../tool/verify_rea_endpoints.sh)
（curl 真实请求 + 429 退避；产物已固化为 `test/fixtures/*_real.json`）。

字节码函数体复挖方法（定位调用点 → 回溯函数头 → 提取 #String/#Object 序列）：

```bash
grep -n "lrts-rank" /tmp/hasm_out                      # 调用点
awk 'NR<=<行号> && /^=> \[Function/ {l=$0} END{print l}' /tmp/hasm_out   # 所属函数
```

## 2026-10-26 追加（第四轮：远端配置 + 频道页 + 存储键纠错）

同一份 Hermes 反汇编（`/tmp/hasm_out`，22,819 函数）按函数体继续挖，
随后对每个新契约做真实请求验证。本轮产物：

### 1. `remote-config` Edge Function（此前完全未知）

```
POST {edge}/functions/v1/remote-config      body: {}
  headers: apikey / Authorization: Bearer <anonKey>
→ {code:0, message:"ok", data:{
     version:{version_code, version_name, update_description,
              download_url, download_url2, has_update, force_update},
     announcement:{title, content, has_link, link_url, link_text,
                   open_external, created_at, updated_at} | null,
     umeng:{enabled, app_key, channel},
     play_api:{enabled, url},
     festivals:[...],
     server_time:"2026-10-26 12:14:22"
  }}
```

- 出处：字节码 #20358（`DEFAULT_CONFIG` 字面量 + 模块导出）、#20370（`functions.invoke('remote-config')`）。
- 另有等价直连 `http://www.tingshu8.top/api.php`（同样 `{code,message,data}`；
  `?do=check_update` 只返回 `version` 段）——2026-10-26 两者均 200，内容一致。
- 本地缓存键 `tingshu_remote_config_cache_v1`；公告已读键 **`rc_ann_dismiss_v1`**。
- 公告「不再显示」用**内容指纹**判定（#20382）：`title\1content\1link_url\1link_text`
  做 djb2（`hash*33 + code`，`>>> 0`）后 `toString(36)`。
  实测样例指纹 = `1kr0eu9`（node 独立复算一致）。
- 更新弹窗（#21402）：逐段比较 `version_name`，标题「发现新版本 v…」，
  内容 `{update_description}\n\n是否立即前往系统默认浏览器下载更新？`，
  按钮 `立即下载` / `稍后再说` → `Linking.openURL(download_url || download_url2)`。

### 2. `play_api` 播放代理开关（当前服务端关闭）

- `play_api.enabled && url` 时，酷我播放地址改走 `{host}/kuwo.php?type=&rid=`：
  - `resolvePlayHost`（#17988）：取 `^https?://[^/]+` 并去掉 `:80`；
  - `buildPlayUrl`（#17989）：`host + '/kuwo.php?type=' + type + '&rid=' + rid`。
- 实测服务端 `play_api.enabled=false`（`url:""`），故线上仍走酷我直连/Edge。
- **未接线**：`buildPlayUrl` 的 `type` 实参在反汇编里没有稳定取值证据
  （只看到 `/kuwo.php?type=` 模板），因此只实现并单测了 URL 构造，
  不猜测 `type` 去改真实播放链路。
- 已接线：`kuwo-play?rid=&quality=&host=`（#18010/#18024）——
  `quality` 是**必带**参数，未指定时字节码默认 `'128'`；
  现在字幕请求按当前音质带 `128`/`320`/`flac`（旧实现只发了 `rid` 与 `host`）。

### 3. `fetchLrtsChildren`：懒人频道页（页签 + 多栏目，不经 Edge）

```
GET https://m.lrts.me/category/book?title=儿童&rootId=6&index=-2
  headers: iPhone UA + Accept: text/html
→ HTML 内 window.__NUXT__ = (function(a,b,...){return {...}}(...));
  取 payload.data[0] → {title, rootId, tabList, recommendList,
                        subTypeRecommendList, finished, tabIndex}
```

- 出处：#18087/#18088/#18090（含 1991 字节的主逻辑）、#18091 `mapChildBook`、
  #18093 页签过滤、#18096 集合去重、#18098 子栏目循环。
- 产出结构：`{title, tabs, recommendBooks, sections:[{label,books}], allBooks, total}`。
- 页签过滤：丢 `!name`、`name==='推荐'|'全部'`、`id==='0'|'6'`（儿童页 16→14）。
- 书映射：`id||entityId||baseEntityId`、`name`、`nickName||author||'未知'`、
  `cover||originCover` 且 `http://`→`https://`、`rating` 写死 `9.5`、
  `playCount` → `N.N万播放`；`source:'lrts'`。
- 同一套 SSR 解析也用于 `lrts-home` 的**直连兜底**
  （`title=有声小说&rootId=1`，#18036）。
- 实测：儿童页 200 / 282 KB，tabList 16、recommendList 8、subTypeRecommendList 16 栏。

### 4. 存储键纠错：是 `tingshu_*`，不是 `shu_*`

早前文档写的 `shu_*` 前缀**是错的**（反汇编里 `shu_` 前缀 0 命中，
命中的 67 处全是 `tingshu_` 的子串）。21 个键的完整清单（#16799 批量读取顺序）：

```
tingshu_theme / tingshu_tap_fx / tingshu_accent / tingshu_favorites /
tingshu_history / tingshu_book_cache / tingshu_audio_quality /
tingshu_skip_intro / tingshu_skip_outro / tingshu_audio_mixing /
tingshu_playback_speed / tingshu_animations_enabled / tingshu_chapter_order /
tingshu_boost_level / tingshu_volume_boost_enabled / tingshu_volume_boost_gain /
tingshu_active_source / tingshu_sleep_stopped / lingyue_total_listened_sec_v1 /
tingshu_favorites_backup / tingshu_history_backup
```

取值形态也一并纠正（#16823/#16829/#17021/#17023 各 setter）：

| 键 | 形态 | 语义 |
|---|---|---|
| `tingshu_playback_speed` | 字符串数字 | `String(speed)` |
| `tingshu_skip_intro` / `_outro` | **数字秒** | `clamp(0..180)`，**0 = 关闭** |
| `tingshu_chapter_order` | 字符串 | `asc` / `desc` |
| `tingshu_audio_quality` | 字符串 | `128` / `320` / `flac` |

音质选项（#225xx 内联数组，逐字）：
`{'q':'128','label':'标准','desc':'128kbps · 流畅省流量'}`、
`{'q':'320','label':'高品','desc':'320kbps · 高清音质'}`、
`{'q':'flac','label':'无损','desc':'FLAC · 原音无损'}`。

### 5. 本轮未搬（明确留档）

- `festivals`（节日主题）：服务端当前 `[]`，且主题资源是本地图标 + 渐变；
  只在远端下发时才应展示，暂不实现（数据结构已解析保留）。
- `announcements` 表（Supabase REST，`is_active/expires_at` 过滤）：
  用 anon key 实测返回 `[]`（RLS），远端公告以 `remote-config` 为准。
- `umeng` 统计、`stat_report.php` / `stat_heartbeat.php` 心跳：与功能无关，跳过。
- 多设备同步（`lingyue_my_sync_code_v1` / `syncDeviceData` / `user_play_history`）：
  需要登录态与写库权限，本轮只记录键名与形状。

## 2026-10-27 追加（第五轮：首页直连兜底 + 章节倒序防护）

### 1. `lrts-home` 的直连兜底（#18036）

上一轮实现了 Nuxt SSR 解码器，本轮把它接到首页：Edge `lrts-home` 全挂
（典型是 `429 projectConcurrencyLimitExceeded`）时，改抓
`https://m.lrts.me/category/book?title=有声小说&rootId=1&index=-2`，
用同一套 NUXT 解析映射成相同的 `{books, sections}`。

- 字节码 #18036 里 Edge 失败后正是这么做的（同一段 NUXT 代码，标题/rootId 写死）。
- 实测：页面 200 / 259 KB，13 个页签、14 个栏目、每栏 8 本书。
- 这条链路**完全不经过 Edge**，因此首页不再受项目级并发配额影响。

### 2. 章节顺序防护（#17864 / #17865）

`extractChapterNumber`（420 B）+ `ensureChaptersAscending`（396 B）是两个
容易被忽略但很实用的工具：上游（酷我 `albuminfo`、Edge `kuwo-episodes`、
懒人分页、自建 JSON 规则）都**偶发倒序**返回章节。

- `extractChapterNumber`：7 级正则级联（「第N集/章/节/回」→「N集」→
  开头编号 → 被分隔符夹住的数字 → 结尾编号 → 前非数字后分隔符 → 最后一组数字）。
- `ensureChaptersAscending`：每 `max(1, len/60)` 抽一条，相邻抽样点比较集号，
  抽样点 <3 或总变化为 0 时不动；**降序占比 ≥ 70% 才整表翻转**。
  不做「按集号排序」——很多标题不含集号或含的是卷号/日期，强排会打乱上游正确顺序。

搬进 `lib/services/chapter_order.dart`，接到三条取章路径
（酷我 / 懒人 / JSON 规则源），翻转后**重建 index 与 chapterId**。

> 诚实记录一个歧义：`'音频 2024 版 66'` 按级联会先命中「被空格夹住的 2024」，
> 而不是结尾的 66。这是字节码原行为，测试里明确写成了断言，
> 没有为了「看起来更聪明」而分叉。
