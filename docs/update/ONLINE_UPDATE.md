# 在线更新（自更新）配置说明

## 先说结论

功能已实现并**全链路验证通过**：

```
设置 → 检查更新 → 发现新版本 v0.3.0 → 立即更新
  → 应用内下载（带进度）→ SHA-256 校验 → 唤起系统安装器 ✅
```

要真正用起来，**你需要做两件事**（各约 5 分钟）：

1. 把 APK 和清单传到可公开下载的地方
2. 把清单地址填进 `lib/services/app_updater.dart` 的 `kUpdateManifestUrl`

---

## ⚠️ 先说一个已修掉的严重问题

改造前，「检查更新」走的是**聆阅的** `remote-config`：

| 字段 | 实际值 | 后果 |
|---|---|---|
| `version_name` | `1.1.7`（聆阅版本） | 我们的 `0.2.x` **永远**比它小 → 永远提示"发现新版本" |
| `download_url` | `wwayk.lanzoum.com/...`（聆阅作者网盘） | 点下载装的是**聆阅** → 把本应用替换掉 |

这个问题是致命的：用户一点更新，应用就没了。

现在已改为**独立清单**，并且未配置时会明确显示「尚未配置更新源」，
**不会**回退到聆阅那段。

---

## 一、发版前必做：配置正式签名

当前 release 仍是 **debug 签名**（`android/app/build.gradle.kts` 有 TODO）。

Android 会拒绝「签名不一致」的覆盖安装。所以：

- 如果用户装的是 debug 签名的包，你换了正式签名 → **装不上**，只能卸载重装
- 一旦定了正式签名，**以后所有版本都必须用同一个 keystore**

```bash
# 1. 生成 keystore（只做一次，务必备份！丢了就再也无法更新老用户）
keytool -genkey -v -keystore ~/qingting-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias qingting

# 2. 在 android/key.properties 写（不要提交到 git）
#    storePassword=...
#    keyPassword=...
#    keyAlias=qingting
#    storeFile=/Users/you/qingting-release.jks
```

然后在 `android/app/build.gradle.kts` 的 `signingConfigs` 里读取它。

---

## 二、版本号规则

`pubspec.yaml`：

```yaml
version: 0.2.9+29
#        ↑     ↑
#     版本名   versionCode（自更新比较的就是它，必须单调递增）
```

同时要更新 `lib/services/app_updater.dart` 里的 `kCurrentVersionCode`。

> `test/services/app_updater_test.dart` 会**强制校验**这两处一致。
> 不一致会导致「永远有新版本」或「永远检查不到更新」。

---

## 三、清单格式

传一个静态 JSON，例如 `manifest.json`：

```json
{
  "version_code": 30,
  "version_name": "0.3.0",
  "update_description": "修复目录不全；优化播放体验",
  "download_url": "https://your-host.com/qingting-0.3.0.apk",
  "sha256": "f01ed6e7...",
  "force_update": false,
  "min_supported_code": 1
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `version_code` | ✅ | 必须 > 用户当前 versionCode 才会提示 |
| `version_name` | ✅ | 弹窗显示用 |
| `update_description` | | 更新内容 |
| `download_url` | ✅ | APK 直链，必须 http/https |
| `sha256` | 强烈建议 | 不匹配会**删除文件并报错**，防止下载到损坏/被替换的包 |
| `force_update` | | `true` 时不显示"暂不更新"，且不能点外部关闭 |
| `min_supported_code` | | 低于此 versionCode 强制更新（老版本兜底） |

生成 sha256：

```bash
shasum -a 256 轻听-0.3.0.apk
```

---

## 四、托管位置怎么选

| 方案 | 优点 | 注意 |
|---|---|---|
| **GitHub Releases**（推荐） | 免费、有直链、能放多个历史版本 | 需要公开仓库；国内访问可能慢 |
| 对象存储（阿里 OSS / 七牛） | 国内快 | 要确保 APK 是**公开可读**且 `Content-Type` 不是网页 |
| 自有服务器 / Nginx | 完全可控 | 需要 HTTPS（Android 9+ 默认禁明文） |

清单和 APK 可以放同一处，也可以分开。

---

## 五、填进代码

`lib/services/app_updater.dart`：

```dart
const String kUpdateManifestUrl = 'https://your-host.com/manifest.json';
```

留空 = 未配置，设置页会显示「尚未配置更新源」。

---

## 六、用户体验细节（已处理）

- **下载在主线程外**，带进度回调，不会卡界面
- **SHA-256 校验**失败会删文件并提示「安装包校验失败」
- **系统会拦一道**：Android 8.0+ 首次更新需用户允许「安装未知应用」。
  弹窗里已写明操作路径，避免用户以为"点了没反应"
- 清单请求带 `Cache-Control: no-cache`，避免 CDN 缓存导致检查不到新版本

---

## 七、未实现（如实说明）

| 项 | 现状 |
|---|---|
| 增量更新（差分包） | 未做。每次全量下载 APK（~71 MB） |
| 应用商店上架 | 未做。目前只能侧载 |
| 后台静默更新 | 未做，也不可能（Android 限制必须用户确认） |
| 灰度 / 分渠道 | 未做。清单是全局的 |

如果需要减少下载体积，可行的下一步是接 `bsdiff` 做差分，但会显著增加复杂度，
建议等用户量起来再考虑。
