# PVE 管家 0.4.1+6 构建与检查报告

日期：2026-10-13（Asia/Shanghai）

## 安装包

- 文件：PVE-Manager-0.4.1+6-release.apk
- 桌面显示名称：PVE 管家；应用内首页标题：PVE 管家 v0.4.1
- Application ID：com.sanduo.pvemanager
- versionName：0.4.1；versionCode：6
- 大小：67,496,529 bytes
- SHA-256：636886193BCAEA461D7F3A9C303CC41A072689116B4181E0A267514342A48F16
- min SDK：24；compile/target SDK：36
- ABI：arm64-v8a、armeabi-v7a、x86_64
- APK v2 签名验证、16 KiB zip alignment 检查均通过；当前使用 Android Debug 内部测试签名。

## 本轮审查与修复

逐文件审阅维护中的 Dart 业务、网络、凭据与控制台代码，Flutter 页面与组件、Android 手写配置和 Kotlin 桥，以及发布、集成测试和截图脚本；不将第三方依赖和生成缓存计作项目源码。

- 合并节点监控：CPU/负载/I/O 等待、内存/Swap、根分区、网络采样、历史曲线、存储列表和独立缓存/错误状态。
- 应用内标题自动跟随 pubspec 版本；桌面名称固定为 PVE 管家；发布前自动同步 Dart AppInfo。
- 短暂断网导致 Ticket 续期失败时保留仍有效会话，以便自动恢复；认证失败、过期及证书变化继续阻断。
- 连接身份替换或删除后，旧电源任务与节点观察回调不能覆盖或清除新连接的状态。
- 初始化未完成时释放控制器，不再创建客户端、登录或启动轮询。
- 修复连接编辑重复提交、异步离场 setState、异常后忙状态未恢复和 TOTP 异常退出。
- 修复 320dp、2 倍字号的版本标题/导航/电源按钮，以及 TOTP 键盘场景溢出；负使用率显示未知；IPv6 地址正确加方括号。
- 控制台捕获 native 刷新、证书回调和显示模式异常；平台恢复失败不再阻止返回。Dart/Kotlin 统一校验端口与 Cookie 字符。
- 发布脚本排除自定义输出目录，阻止仓库/祖先输出及 staging 自递归路径。

## 验证

- 版本生成器 --check：通过。
- flutter analyze --no-pub：无问题。
- 完整 flutter test --no-pub：150 项通过；实际版本标题的大字号定向复验 6 项通过。
- 资源、详情和登录页固定尺寸截图验收通过。
- Release APK：构建成功；aapt 从 APK 核验显示名称、版本、SDK 与 ABI。
- Android 16 / API 36 模拟器：覆盖安装成功、冷启动 Status ok；安装版本为 0.4.1 / 6。
- 初次登录页采用简洁表单布局，返回后首页可见 PVE 管家 v0.4.1；对应进程未记录 AndroidRuntime/flutter error。

## 实测边界

本轮没有改装用户手机、读取真实密码或执行真实 PVE 电源操作。新增监控在真实 PVE 8/9 上的字段/权限表现，以及真实控制台连接、TOTP 与长期会话仍需联调。native 失败回归主要使用平台模拟，不能替代所有机型的设备验证。
