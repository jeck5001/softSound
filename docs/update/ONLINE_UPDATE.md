# 在线更新（自更新）— 已托管到 GitHub Releases

## 现状：已可用

| 项 | 值 |
|---|---|
| 版本 | **0.0.1**（versionCode **1**） |
| Release | https://github.com/jeck5001/softSound/releases/tag/v0.0.1 |
| APK 直链 | `https://github.com/jeck5001/softSound/releases/download/v0.0.1/qingting-0.0.1.apk` |
| 清单（主） | `https://raw.githubusercontent.com/jeck5001/softSound/main/manifest.json` |
| 签名 | 正式签名 `CN=QingTing`，证书 SHA-256 `d1a20e9d…7f25` |
| 仓库 | Public（APK 可匿名下载） |

**实测**（走本机代理）：清单 2.4 秒返回；APK 36 秒下完 71MB（约 1.9 MB/s）；
下载文件 SHA-256 与清单声明**逐字一致**。

---

## ⚠️ 两个必须知道的现状

### 1. GitHub 在国内需代理
不经代理时，本机与模拟器访问 `github.com` / `raw.githubusercontent.com`
**超时或 0 字节**；走代理后一切正常。

所以：**给国内用户分发时，GitHub Releases 不是可靠渠道**。
建议后续换成对象存储（阿里 OSS / 七牛）或自有服务器 + HTTPS。
换的时候只需改 `manifest.json` 里的 `download_url` 与
`kUpdateManifestUrl`，代码不用动。

App 侧已做三处兜底：
- 清单 3 个地址依次重试（raw / refs-heads / jsDelivr）
- 每个地址重试 2 次，8 秒超时
- APK 下载支持镜像前缀（`downloadMirrors`），且**每个候选都过 SHA-256 校验**

### 2. 签名密钥务必离线备份
`android/qingting-release.jks`（别名 `qingting`，口令见 `android/key.properties`）。
两者都在 `.gitignore` 里，**不在仓库中**。

> 密钥丢失 → 老用户永远无法覆盖更新，只能卸载重装（本地数据丢失）。

---

## 发版流程（每次新版照做）

```bash
# 1. 改版本号（三处必须一致，有单测强制）
#    pubspec.yaml:  version: 0.0.2+2
#    lib/theme/app_strings.dart:  appVersion = '0.0.2'
#    lib/services/app_updater.dart:  kCurrentVersionCode = 2

# 2. 出包
flutter build apk --release

# 3. 算 sha256
shasum -a 256 build/app/outputs/flutter-apk/app-release.apk

# 4. 创建 Release 并上传（文件名保持 qingting-<version>.apk）
export https_proxy=http://127.0.0.1:7890
gh release create v0.0.2 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "轻听 v0.0.2" --notes "..."

# 5. 更新仓库根的 manifest.json（version_code / download_url / sha256）

# 6. 提交并推送（必须是 main，清单从 main 读）
git add manifest.json && git commit -m "release: 0.0.2" && git push origin main
```

> 第 6 步别忘：**清单没推上去，用户就检查不到新版本**。

---

## 清单格式

```json
{
  "version_code": 2,
  "version_name": "0.0.2",
  "update_description": "修复 X",
  "download_url": "https://github.com/jeck5001/softSound/releases/download/v0.0.2/qingting-0.0.2.apk",
  "sha256": "<64 位十六进制>",
  "force_update": false,
  "min_supported_code": 1
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `version_code` | ✅ | 必须 > 用户当前 versionCode |
| `version_name` | ✅ | 弹窗标题用 |
| `download_url` | ✅ | http/https 直链 |
| `sha256` | 强烈建议 | 不匹配会删文件并报错 |
| `force_update` | | true 则不显示"暂不更新" |
| `min_supported_code` | | 低于此 code 强制更新 |

---

## 已知限制

| 项 | 现状 |
|---|---|
| jsDelivr 缓存 | `@main` 有缓存延迟（实测取到旧 sha）。仅作兜底；主地址用 raw |
| 增量更新 | 未做，每次全量 ~71 MB |
| 后台静默更新 | 未做（Android 不允许，必须用户确认） |
| 灰度发布 | 未做，清单是全局的 |

---

## 排障

**点了"检查更新"没反应？**
1. 确认 `kUpdateManifestUrl` 非空（空则提示"尚未配置更新源"）
2. 手机上直接开清单 URL 看能否访问
3. `adb logcat | grep "拉取更新清单失败"` 看具体错误

**下载完装不上？**
- 提示"应用未安装" → 签名不一致（换过 keystore）
- 提示"不允许安装未知应用" → 系统设置里允许本应用安装
