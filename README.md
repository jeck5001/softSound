# 轻听（soft_sound）

跨平台听书 App。UI 与功能对齐「聆阅 FM」（`聆听.apk`）的 Flutter 重写版，
支持懒人听书 / 酷我两个书源，含播放、下载、字幕、倍速、睡眠定时、
媒体通知与锁屏控制。

## 快速开始

```bash
flutter pub get
flutter run                      # 连接设备或模拟器

flutter analyze                  # 必须 0 issue
flutter test                     # 599 用例
flutter build apk --release      # 产物 build/app/outputs/flutter-apk/app-release.apk
```

Android 模拟器需带 DNS（否则 `m.lrts.me` 解析失败），详见 [CLAUDE.md](CLAUDE.md)。

## 功能

| 模块 | 说明 |
|---|---|
| 书源 | 懒人听书（`lrts`）、酷我（`kuwo`），均经 Supabase Edge Functions 代理 |
| 发现 | 首页推荐、分类树、频道页、榜单 |
| 搜索 | 多源并发 + 相关度过滤 + 5 分钟缓存 |
| 播放 | 章节队列、倍速、跳过片头尾、睡眠定时、字幕、音量增强、音频混音 |
| 媒体会话 | 通知栏/锁屏三键（上一章 / 播放-暂停 / 下一章），支持快进快退 |
| 书架 | 网格 / 列表、排序，选择持久化 |
| 下载 | 离线缓存与下载管理 |
| 其他 | 播放历史、继续收听、主题色、动效开关、后台保活引导、检查更新 |

## 项目结构

```
lib/
├── app/            # 应用壳、路由（go_router）
├── core/           # 通用工具
├── data/           # drift 数据库、模型、仓库
├── domain/         # 领域对象
├── features/       # 按页面划分：home/search/player/bookshelf/…
├── services/       # 书源适配器、播放器、媒体会话、下载、远端配置
└── theme/          # 设计系统、文案（AppStrings）、设置
```

技术栈：Flutter · Riverpod · go_router · Dio · drift (SQLite) ·
just_audio + audio_service。

## 文档

| 文档 | 内容 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | 开发约定、红线、命令速查、真机验证方法 |
| [UI_PORT.md](docs/reverse-engineering/lingting/UI_PORT.md) | 逐条移植记录：每个功能的字节码出处 + 实测证据 |
| [逆向说明](docs/reverse-engineering/lingting/README.md) | 如何从 APK 反汇编（Hermes v96），已确认的端点与存储契约 |
| [分析报告](docs/superpowers/specs/2026-10-13-lingting-apk-rea-analysis.md) | 完整逆向分析 |

## 说明

- 本项目是对第三方 App 的**界面与功能复刻**，用于学习 Flutter 工程实践。
  仓库内不含原 App 的二进制（`index.android.bundle` 等版权文件）。
- release 包目前仍使用 debug 签名，正式分发前需配置签名。
