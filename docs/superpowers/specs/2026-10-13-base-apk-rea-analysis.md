# base.apk REA 逆向分析报告

- **分析日期**：2026-10-13
- **目标**：`/Users/jfwang/Documents/base.apk`
- **SHA-256**：`590c99b721319cb5ec9787ff7a792c82375d04887bd3468e23b9152a7704e182`（28,810,204 字节）
- **工具**：REA（JADX headless 0.7.1 / Apktool 2.11.1 / artifact graph）
- **结论**：**该 APK 为 360 加固（Jiagu）包，真实业务代码静态不可读。书源协议无法从本样本静态提取。**

---

## 1. 核心结论

`cn.ms.pages.*`、`cn.ms.common.*` 等真实业务类（搜索、详情、章节、音频 URL 生成、签名与解密）
**不存在于磁盘上的任何 DEX 中**，仅在运行时由 `libjiagu.so` 解密到内存。

因此本轮**没有**产出可落地的书源协议改动。落地代码需要先取得脱壳后的 DEX（见 §6）。

---

## 2. 加固证据链

四层独立证据一致：

| # | 证据 | 观测结果 |
|---|---|---|
| 1 | `inspect_android_package` | JADX 仅解析出 **5 个类**；`resource_count=1544` 正常，说明资源未加密，仅代码加密 |
| 2 | `search_android_classes("cn.ms")` | **0 命中**。全量类清单：`com.stub.StubApp`、`com.tianyu.util.Configuration`、`com.tianyu.util.DtcLoader`、`com.tianyu.util.a`、`cn.longniu.pages.R` |
| 3 | `inspect_android_method("com.stub.StubApp","attachBaseContext")` | 壳逻辑确证：`System.loadLibrary("jiagu")` → `DtcLoader.init()` → 反射 `Application.attach()` 加载真实 Application；含 `interface5/interface8/interface99` 等 native 回调桥 |
| 4 | 文件层 | `assets/libjiagu.so`(32-bit ARM)、`assets/libjiagu_a64.so`(aarch64)、`assets/.jgapp`、`assets/na.czl`、`assets/zlsioh.dat`；`nm -D` 无导出符号（stripped） |

### DEX 唯一性校验

```
$ find . -name "*.dex"
./classes.dex            # 头部 = 64 65 78 0a 30 33 35  ("dex\n035")
$ strings -a classes.dex | grep -c "cn/ms"
0
```

全包仅此一个 DEX，且其中 **不含任何 `cn/ms` 类路径**。

### 载荷文件无明文 DEX

| 文件 | 大小 | 头部 | 判定 |
|---|---|---|---|
| `assets/zlsioh.dat` | 56,524 | `01 06 03 00 17 00 00 00` | 加密载荷（非 DEX 魔数） |
| `assets/na.czl` | 2,094 | `00 01 01 00 11 00 b8 97` | 加密载荷 |
| `assets/.jgapp` | 16 | ASCII `c826a293e41d6386` | 加固标识/校验值 |

`libjiagu_a64.so` 内的配置键名进一步确认机制：
`JIAGU_ENCRYPTED_DEX_NAME`、`JIAGU_HASH_FILE_NAME`、`JIAGU_FILE_PATH`、`JIAGU_SO_BASE_NAME`、
`libjiagu_vip`、`libjiagu_vip_enc.so`，并含 `Aes`/`aAeS` 相关符号。

### 资源层无书源线索

全量解码 1753 个文件、1544 条字符串资源，**逐一搜索均 0 命中**：

```
ximalaya · kuwo · qtfm · yuetingba · 5weiting · 6yueting · ting56 · qingting
```

说明书源规则不是资源内静态数据，而是运行时从服务端拉取或硬编码于加密 DEX。

---

## 3. 可提取的静态事实（已留存）

这些信息在脱壳后可直接复用为分析索引。

### 3.1 应用身份

| 项 | 值 |
|---|---|
| 包名 | `cn.longniu.pages` |
| 应用名 | 飞鸟听书 |
| versionName / Code | `2.2609` / `22609` |
| minSdk / targetSdk / compileSdk | 24 / 30 / 30 |
| `application:name` | `com.stub.StubApp`（加固壳，非真实 Application） |
| DeepLink scheme | `feiniao://my.com` |
| `usesCleartextTraffic` | **true**（允许明文 HTTP，对书源调试有利） |
| `networkSecurityConfig` | `@xml/network_security_config`（仅 `base-config`/`cleartextTrafficPermitted`） |

### 3.2 组件地图（脱壳后定位入口的索引）

**Activity（76 个，业务相关）**——书源分析重点是这几个：

| 组件 | 推测职责 |
|---|---|
| `cn.ms.pages.ActivitySouSuo` | 聚合搜索入口 |
| `cn.ms.pages.ActivitySouSuoWb` | 网页搜索 |
| `cn.ms.pages.ActivityZhuanJi` | 专辑/书籍详情 |
| `cn.ms.pages.ActivityZhuanJiXiaZai` | 专辑下载 |
| `cn.ms.pages.ActivityYinYueWangYe` | 音乐 H5（`singleTask`） |
| `cn.ms.pages.ActivityYinYueWb` | 音频分享/打开（`audio/*` intent-filter） |
| `cn.ms.pages.ActivityYinYueBenDi` / `ActivityYinYueTuiJian` | 本地音乐 / 推荐 |
| `cn.ms.pages.ActivityZiYuan` | 资源/书源管理 |
| `cn.ms.pages.ActivityGongJu3Xm` / `ActivityGongJu3Wp123` | 工具页（Xm = 喜马拉雅，Wp123 = 网盘123） |
| `cn.ms.pages.ActivityAiBoFang` / `ActivityAi1KanShu` / `ActivityAi2KanShu` | AI 播放/看书 |
| `cn.ms.pages.ActivityJingHua` / `ActivityJingHuaGuanLi` | 净化规则管理 |
| `cn.ms.pages.FrameShouYe` / `FrameJiLu` / `FrameZhangHao` / `FremeTuiJian` | 四大主页 Frame |

> 命名规律：`Xm`=喜马拉雅、`Wp123`=123网盘、`Wb`=网页。这类拼音缩写是书源适配器命名的重要线索。

**Service（3 个，业务相关）**：

- `cn.ms.common.service.MusicService` — 播放服务（`exported=true`）
- `cn.ms.common.service.XiaZaiService` — 下载服务
- `cn.ms.common.service.MsServiceCompat` — 兼容服务

**Provider（业务相关）**：`cn.longniu.pages.fileprovider`、`cn.longniu.pages.adFileProvider`

**广告/三方 SDK（与分析无关，可忽略）**：穿山甲 Pangle、优量汇 `com.qq.e`、快手 `com.kwad.sdk`、
字节 openlive `com.byted.live.lite`、腾讯 X5 `com.tencent.smtt`、Bugly、百度 OAuth。

### 3.3 权限中的分析线索

- `INTERNET` + `ACCESS_NETWORK_STATE` + `CHANGE_WIFI_STATE` — 网络书源
- `MANAGE_EXTERNAL_STORAGE` + `requestLegacyExternalStorage` — 本地文件书源（`ActivityDaoRuFile`/`DaoChuFile`）
- `QUERY_ALL_PACKAGES`、`REQUEST_INSTALL_PACKAGES` — 应用分发
- `SYSTEM_ALERT_WINDOW`、`FOREGROUND_SERVICE`、`WAKE_LOCK` — 后台播放

### 3.4 与项目现状的对应

项目 `docs/superpowers/specs/2026-06-18-typed-audio-sources-design.md` 记载，
`lib/services/typed_sources/` 下 5 个适配器（XA / xiaoKu / liuYue / xiaoLiang / xiaoQing）
是从 `/Users/jfwang/Documents/base_apk_work` 中**已脱壳的 Java 代码**移植。

**该工作目录现已不存在**（已确认），因此无法复用上一轮产物交叉验证。

---

## 4. 为什么不能"硬编"书源协议

现有 5 个适配器依赖的关键信息**只有加密 DEX 才知道**：

| 信息来源 | 作用 | 是否可从静态获得 |
|---|---|---|
| `TsService().neiRong()` 签名算法 | liuYue / XA 的服务端校验 | ✗ |
| `video_new` 的 `time` + `sign` 生成 | liuYue 音频地址 | ✗ |
| `docs-listen/{id}/ting-with-efi` 的 AES/CBC 密钥与 IV | xiaoLiang 音频解密 | ✗ |
| 喜马拉雅 `playUrl64` 等字段选取与付费过滤规则 | XA | ✗ |
| 各源请求头的定制字段与 Cookie 流转 | 全部 | ✗ |

若凭猜测补全这些常量和算法，会产出**编译通过但运行时 100% 失败**的代码，
比保持现状更糟（掩盖真实缺口、污染测试基线）。

---

## 5. 已确认的替代信息源

脱壳前，以下两条路径可用于校验适配器（不依赖 APK）：

1. **上游站点公开接口**——直接对各源的公开 API 发请求，用真实响应校准解析逻辑。
   配合 REA 的 `capture_browser_scenario` / `inspect_web_network_capture` 留存证据。
2. **现有适配器自身**——作为唯一事实来源，做健壮性审计与测试补齐。

---

## 6. 脱壳方案（下一步）

目标是拿到解密后的 `cn.ms.pages.*` DEX，然后交回 REA 分析。

### 前置：可运行该 App 的设备

需要一个 **arm64 Android 7.0+（API 24+）** 真机或模拟器。360 加固有反调试/反虚拟化，
**优先真机 + root**；模拟器大概率失败。

### 方案 A：frida-dexdump（推荐，门槛最低）

```bash
# 设备侧
adb push frida-server-*-android-arm64 /data/local/tmp/frida-server
adb shell "su -c 'chmod 755 /data/local/tmp/frida-server'"
adb shell "su -c '/data/local/tmp/frida-server &'"

# 主机侧
pip install frida-tools frida-dexdump
adb shell "su -c 'am start -n cn.longniu.pages/cn.ms.pages.ActivityLaunch'"
sleep 8
frida-dexdump -U -f cn.longniu.pages -d 3000
# 产出：./cn.longniu.pages/dex/*.dex
```

### 方案 B：FART / Youpk（编译 ROM，抗反调试更强）

适用于 frida 被检测的情况。需刷入 FART 或 Youpk 定制的 Android 系统镜像，
自动 dump 全部 DEX 及方法体。

### 方案 C：黑盒抓包（不脱壳，改变思路）

既然 `usesCleartextTraffic=true`，可直接抓 App 与上游站点的真实流量：

```bash
# mitmproxy + 系统证书（需 root 装到 /system/etc/security/cacerts）
mitmdump -w base_apk_flows.mitm
# 在 App 内依次操作：搜索 → 打开专辑 → 播放一章
```

产物 `base_apk_flows.mitm` 可用 REA 的
`inspect_web_network_capture(format="mitmproxy")` 离线解析，
直接得到各源的**真实 URL、请求头、签名参数、响应结构**。

> 方案 C 往往比脱壳更快拿到"协议事实"，且不需要对抗加固。
> 但它给的是**具体请求样本**而非完整算法；若签名含时间戳/随机数，仍需 DEX 才能复现。

### 交付方式

把产物放到项目内或 `~/Documents` 下任一位置即可，例如：

```
~/Documents/base_apk_work/dex/*.dex          # 方案 A/B
~/Documents/base_apk_work/flows.mitm         # 方案 C
```

然后告诉我路径，我用 REA 继续分析：

- DEX → `open_binary` + `search_android_classes("cn.ms.pages")` + `inspect_android_method`，
  重点定位 `TsService`、音频 URL 生成、AES/签名工具类
- mitmproxy → `inspect_web_network_capture`，还原各源请求/响应契约

---

## 7. 本轮结论摘要

| 问题 | 答案 |
|---|---|
| APK 是什么？ | 飞鸟听书 2.2609（`cn.longniu.pages`），360 加固 |
| 能静态拿到书源协议吗？ | **不能**。代码在运行时解密，磁盘无明文 DEX |
| 资源层有线索吗？ | 没有。1544 条字符串资源中 0 条命中任何书源域名 |
| 拿到了什么？ | 完整组件地图（76 Activity / 3 Service）、加固结构、权限画像、命名规律 |
| 项目改了吗？ | **没有**。避免写入无法验证的猜测代码 |
| 下一步？ | 脱壳（frida-dexdump）或抓包（mitmproxy），产物交回 REA |
