# PVE 管家 v0.4.1

版本：**0.4.1+6** · 发布日期：**2026-10-13** · Android **7.0+**

PVE 管家让你在 Android 手机上查看 Proxmox VE 虚拟机与容器、执行常用电源操作、打开远程控制台，并查看宿主机的资源概况。这个版本加入节点性能与容量监控，更新登录界面，并修复会话、操作状态与小屏布局问题。

![PVE 管家功能概览](https://github.com/sanduo-656/pve-manager/blob/main/docs/images/pve-manager-overview.png?raw=true)

## 本版更新

- **节点性能监控**：查看 CPU、I/O 等待、系统负载、内存、Swap、根分区容量、节点汇总网络速率，以及 PVE 存储容量。
- **历史趋势**：支持 1 小时、24 小时、周、月和年；显示采样时间，保留缺失数据的曲线断点。
- **刷新与错误反馈**：仅在前台查看节点时刷新；各接口独立提示失败，并保留上次成功数据与更新时间。
- **更清晰的登录页**：服务器、用户名与密码直接展示，端口和认证域放入“高级设置”；默认 `8006`、`pam`，新建连接默认不记住密码。
- **应用内版本展示**：首页显示 `PVE 管家 v0.4.1`，桌面名称保持“PVE 管家”。
- **稳定性修复**：改善短暂断网后的会话续期、连接切换后的操作状态，以及异步登录和编辑流程。
- **界面与控制台修复**：改善小屏、大字体及键盘场景，完善控制台错误与退出反馈。

![节点监控说明](https://github.com/sanduo-656/pve-manager/blob/main/docs/images/pve-manager-monitoring.png?raw=true)

## 下载与安装

下载 [PVE-Manager-0.4.1+6-release.apk](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.1/PVE-Manager-0.4.1%2B6-release.apk) 和 [SHA256SUMS.txt](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.1/SHA256SUMS.txt)。

另附 [完整源码包](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.1/PVE-Manager-0.4.1%2B6-source.zip) 和 [介绍素材包](https://github.com/sanduo-656/pve-manager/releases/download/v0.4.1/PVE-Manager-0.4.1%2B6-presentation.zip)。素材包包含可复制的中文介绍稿、两张 1920×1080 介绍图、界面截图及账号配置指南；校验文件包含上述三个下载文件的 SHA-256。

| 项目 | 信息 |
| --- | --- |
| Android 版本 | 7.0 及以上，min SDK 24 |
| 安装包版本 | versionName 0.4.1 / versionCode 6 |
| 架构 | arm64-v8a、armeabi-v7a、x86_64 |
| 大小 | 67,496,529 bytes，约 64.4 MiB |
| Application ID | `com.sanduo.pvemanager` |
| 签名 | 内部测试签名 |

SHA-256：

```text
636886193BCAEA461D7F3A9C303CC41A072689116B4181E0A267514342A48F16
```

这是测试体验版本，尚未使用正式商店发布签名。首次使用前，可参考 [账号与权限配置](https://github.com/sanduo-656/pve-manager/blob/main/docs/pve_setup.md) 创建专用 PVE 账号。

## 使用提示

- 地址只填主机名或 IP，端口单独设置。默认 `pam` 对应 Linux 系统账号；PVE 认证域账号请选择 `pve`，也可使用自定义认证域。
- 用户名包含 `@认证域` 时，以用户名为准，例如 `pvemanager@pve`。
- 使用 HTTPS；自签名证书须核对 SHA-256 指纹后确认。密码仅在启用“记住密码”时保存。
- 节点监控读取需要 `Sys.Audit`；存储读取需要对应存储的 `Datastore.Audit`。电源操作需要另行授权。

## 验证与已知限制

此版本已通过 `flutter analyze`、**150 项自动化测试**、APK v2 签名及 16 KiB 对齐检查，并完成 Android API 36 模拟器安装、冷启动与页面检查。

介绍图片和截图使用演示数据。新增监控在真实 PVE 8/9 上的字段、权限和 RRD 采样精度仍需进一步验证；自动化测试不能替代目标环境中的控制台、TOTP、长期会话及电源操作验收。

网络数据为 PVE 提供的节点汇总 RRD 采样，单位 B/s，不是逐网卡实时抓取。磁盘数据为根分区和 PVE 存储容量，未包含物理磁盘 IOPS、延迟或 SMART。当前也不提供 CPU 温度和后台持续告警。

Android 7–9 在 WebView 无法读取 DER 证书数据时会拒绝自签名控制台；应使用受信任证书链。仅直通 GPU 且没有虚拟显示设备的虚拟机，noVNC 可能无画面。

问题反馈：[GitHub Issues](https://github.com/sanduo-656/pve-manager/issues)。请提供应用与系统版本、复现步骤和脱敏错误信息，避免上传凭据。
