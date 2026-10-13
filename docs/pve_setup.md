# PVE 管家服务端配置

## 建议的最小权限

不要使用 `root@pam`。为应用创建独立用户，并把虚拟机/容器权限与宿主机权限分开授予：

```bash
pveum user add pvemanager@pve
pveum passwd pvemanager@pve

pveum role add MobileGuestOperator \
  -privs "VM.Audit VM.PowerMgmt VM.Console"
pveum role add MobileNodeOperator \
  -privs "Sys.Audit Sys.PowerMgmt"

pveum acl modify /vms \
  -user pvemanager@pve -role MobileGuestOperator -propagate 1
pveum acl modify /nodes \
  -user pvemanager@pve -role MobileNodeOperator -propagate 1
```

如果某个集群只允许管理部分资源，应在对应 `/vms/<VMID>` 或 `/nodes/<节点名>` 路径逐项授权，不要在 `/` 上授予角色。节点的关机和重启权限风险较高；不需要该功能时不要授予 `Sys.PowerMgmt`。

## 节点监控权限

节点概览和历史曲线需要 `/nodes/<节点名>` 上的 `Sys.Audit`。查看存储容量另外需要 `/storage/<存储 ID>` 上的 `Datastore.Audit`；只有节点权限时，存储接口可能返回空列表，其他监控仍可正常使用。

只读监控可以按下面的示例单独授权（替换 `pve-node` 和 `local-lvm` 为实际节点、存储 ID）：

```bash
pveum role add MobileNodeMonitor -privs "Sys.Audit"
pveum role add MobileStorageMonitor -privs "Datastore.Audit"
pveum acl modify /nodes/pve-node \
  -user pvemanager@pve -role MobileNodeMonitor -propagate 1
pveum acl modify /storage/local-lvm \
  -user pvemanager@pve -role MobileStorageMonitor -propagate 1
```

这些监控权限不包含电源操作，也不要求在 `/` 授予全局角色。新增监控使用已有 HTTPS 和证书校验流程。

## HTTPS 与证书

- 优先为 PVE 配置系统信任的 CA 证书。应用禁止 HTTP 明文连接，也不提供“接受所有证书”选项。
- 使用自签名证书时，首次测试连接必须人工核对 DER 证书的 SHA-256 指纹。固定值按 `主机:端口` 保存，证书变化后 REST 与控制台都应硬阻断，重新核对后才能更新。
- 可在受信任的管理终端执行下列命令并与应用显示值逐字核对：

```bash
openssl s_client -connect pve.example:8006 -servername pve.example </dev/null 2>/dev/null \
  | openssl x509 -outform DER \
  | openssl dgst -sha256
```

- Android 10 及以上可从 WebView SSL 回调读取 DER 证书并校验固定指纹。Android 7 至 9 在系统不提供 DER 数据时会安全拒绝自签名控制台；这些设备应安装受信任证书链或升级系统，不会降级为跳过校验。

## TOTP 与网络边界

- 可在 PVE 用户的双因素设置中启用 TOTP。应用每次登录只在内存中使用一次性验证码，不会保存 TOTP 密钥、验证码、Ticket 或 CSRF Token。
- 仅在受控局域网或 VPN 内开放 TCP 8006。不要把 PVE 管理端口直接暴露到公网。
- VPN 应先由 Android 系统或组织的 VPN 客户端建立；本应用不包含隧道、端口转发或反向代理功能。
- 防火墙只允许管理网段/VPN 地址访问 PVE API，并保留 PVE 审计日志。节点电源操作应只在明确维护窗口执行。

## 控制台限制

QEMU 控制台使用 PVE 自带 noVNC，LXC 使用 PVE 自带 xterm.js。若 QEMU 只直通物理 GPU 且没有虚拟显示设备，noVNC 可能没有画面；此时应使用客户机内的 RDP/VNC 等远程方案。

PVE 顶层 Workspace 在启动 noVNC/xterm.js 前会由同源 JavaScript 读取 `PVEAuthCookie`，所以该 Cookie 无法使用 `HttpOnly`。应用将它限制为会话 Cookie，启用 `Secure` 和 `SameSite=Strict`，禁止跳转到其他 Origin，不注册敏感 JavaScript Bridge，并在退出控制台时立即清除。
