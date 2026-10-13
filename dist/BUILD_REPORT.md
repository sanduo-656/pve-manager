# PVE 管家 0.4.2+7 构建与验证报告

日期：2026-10-13（Asia/Shanghai）

## 安装包

- 文件：PVE-Manager-0.4.2+7-release.apk
- 桌面名称：PVE 管家；应用内首页：PVE 管家 v0.4.2
- Application ID：com.sanduo.pvemanager
- versionName：0.4.2；versionCode：7
- 大小：67,886,065 bytes
- SHA-256：64D98EB9002C48D0A2B34ED9263A15586E72238559FA759348CFDAAF6517667C
- min SDK：24；compile/target SDK：36
- ABI：arm64-v8a、armeabi-v7a、x86_64
- APK v2 签名验证与 16 KiB 对齐检查通过；当前为 Android Debug 内部测试签名。

## 本版变更

- 替换蓝色服务器／P 图形启动图标，提供多密度与自适应圆形、圆角遮罩。
- 明确不依赖 Google Play 服务、商店或 Google 账号；保留系统 WebView 与 PVE 网络访问要求。
- 增加 70 秒 1080p 宣传视频、封面、中文配音、字幕、原创合成配乐和发布文稿。
- 视频使用真实 Flutter 组件的模拟器录屏与固定演示数据，不发送 PVE 请求或电源操作。
- 资源管理、节点监控、控制台与登录能力延续 0.4.1。

## 验证

- 版本同步检查与静态分析通过。
- 应用信息、可访问性及截图定向测试：10 项通过；录屏集成交互测试通过。
- Release APK 构建成功，实际版本、名称、ABI、签名与对齐已核验。
- Release 运行时依赖离线解析成功，无未解析项目，未发现 GMS、Play services、Firebase 或 Billing 依赖。
- Android API 36 模拟器中临时停用 GMS 和 Google Play 商店后，安装、冷启动、登录页及首页显示正常，未记录应用运行错误；两个组件已恢复原始状态。
- 实际启动图标、桌面名称、应用内版本以及默认端口 8006／认证域 pam 已确认。

## 宣传视频

- 文件：PVE-Manager-0.4.2+7-promo-1080p.mp4
- 70.000 秒，1920×1080，30 fps，H.264 / yuv420p，AAC / 48 kHz stereo。
- 大小：4,791,513 bytes
- SHA-256：43B908B488B5D0ED733CD67434E816807A64D6B9A4B64E11829BA45EEEFFB6BC
- 全片解码检查通过，画面逐场景检查通过；始终标明演示数据。

## 验证范围

无 Google 服务的设备验证范围为安装、冷启动与登录／首页显示；本轮未在真实 PVE 上重新验证登录、监控、控制台或电源操作。网络为节点汇总 RRD 采样，磁盘为根分区和 PVE 存储容量，不包含逐物理磁盘 IOPS、SMART、温度或后台告警。
