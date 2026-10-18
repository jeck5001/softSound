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
