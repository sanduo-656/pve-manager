# PVE 管家 v0.4.2

版本：**0.4.2+7** · 发布日期：**2026-10-13** · Android **7.0+**

PVE 管家是在手机上查看和管理 Proxmox VE 的中文第三方客户端。**无需 Google Play 服务（GMS）或 Google 账号，下载 APK 即可安装。** 管理与监控需要设备能够通过网络访问 PVE；远程控制台仍需可用的 Android 系统 WebView。

<img src="https://github.com/sanduo-656/pve-manager/blob/main/assets/branding/pve-manager-icon.png?raw=true" width="128" alt="PVE 管家新应用图标">

## 本版更新

- **新应用图标**：蓝色背景、白色服务器层叠结构与虚拟方块，适配 Android 自适应图标的圆形和圆角遮罩。
- **安装说明更清楚**：明确无需 Google Play 商店、GMS 或 Google 账号，说明系统 WebView 与 PVE 网络连接要求。
- **宣传视频与介绍素材**：提供 70 秒 1080p 宣传视频、封面与文字稿，包含中文配音、字幕、原创合成配乐和模拟器实录，展示登录、资源管理和节点监控。界面及监控值使用演示数据。

节点性能监控、历史趋势、资源电源操作、控制台与登录界面延续 0.4.1 的能力。桌面名称保持“PVE 管家”，版本号显示在应用内首页。

[![PVE 管家宣传视频封面](https://github.com/sanduo-656/pve-manager/blob/main/docs/video/pve-manager-cover.png?raw=true)](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.2/PVE-Manager-0.4.2%2B7-promo-1080p.mp4)

## 下载与安装

下载 [PVE-Manager-0.4.2+7-release.apk](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.2/PVE-Manager-0.4.2%2B7-release.apk) 和 [SHA256SUMS.txt](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.2/SHA256SUMS.txt)。

另附 [1080p 宣传视频](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.2/PVE-Manager-0.4.2%2B7-promo-1080p.mp4)、[完整源码包](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.2/PVE-Manager-0.4.2%2B7-source.zip) 和 [介绍素材包](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.2/PVE-Manager-0.4.2%2B7-presentation.zip)。

宣传视频为 1920×1080、30 fps、H.264／AAC，文件大小 4,791,513 bytes。视频 SHA-256：`43B908B488B5D0ED733CD67434E816807A64D6B9A4B64E11829BA45EEEFFB6BC`。

| 项目 | 信息 |
| --- | --- |
| Android 版本 | 7.0 及以上，min SDK 24 |
| 安装包版本 | versionName 0.4.2 / versionCode 7 |
| 架构 | arm64-v8a、armeabi-v7a、x86_64 |
| 大小 | 67,886,065 bytes，约 64.7 MiB |
| Application ID | `com.sanduo.pvemanager` |
| 签名 | 内部测试签名 |

SHA-256：

```text
64D98EB9002C48D0A2B34ED9263A15586E72238559FA759348CFDAAF6517667C
```

这是测试体验版本，尚未使用正式商店发布签名。首次使用可参考 [账号与权限配置](https://github.com/sanduo-656/pve-manager/blob/main/docs/pve_setup.md) 创建专用 PVE 账号；新连接默认端口 `8006`、认证域 `pam`，可在高级设置中修改。

## 验证与使用边界

本版通过静态分析、10 项应用信息／可访问性／截图定向测试，以及宣传录屏集成测试。Release 运行时依赖解析完成，没有 Google Play 服务或 Firebase 依赖，也没有未解析的依赖项。

在 Android API 36 模拟器中临时停用 GMS 和 Play 商店后，完成 Release APK 安装、冷启动、登录页与首页界面检查；验证后已将两个组件恢复原状。此项验证仅覆盖该模拟器及上述界面流程，不代表无 GMS ROM 上连接真实 PVE 的全功能实测。

系统 WebView 需可用；Android 7–9 无法读取 DER 证书数据时会拒绝自签名控制台，应使用受信任证书链。应用不会忽略证书错误。

节点监控读取 PVE 原有接口，无需额外采集程序；网络为节点汇总 RRD 采样，磁盘为根分区与 PVE 存储容量。真实 PVE 8/9 的字段、权限和采样精度仍需进一步验证，当前不提供物理磁盘 IOPS、SMART、温度或后台告警。

问题反馈：[GitHub Issues](https://github.com/sanduo-656/pve-manager/issues)。请提供应用与系统版本、复现步骤和脱敏错误信息，避免上传凭据。
