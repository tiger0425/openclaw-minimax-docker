# SSH 密钥连接配置指南

本文档说明如何配置 OpenClaw（Linux/WSL2）到远程服务器 192.168.101.245 的 SSH 密钥连接。

---

## 目标

从 OpenClaw 系统免密码登录到远程服务器 `yihu@192.168.101.245`

---

## 步骤一：在远程服务器生成密钥对

在 **192.168.101.245** 上执行：

```bash
ssh-keygen -t ed25519 -C "yihu"
```

一路回车完成，会生成：
- 私钥：`~/.ssh/id_ed25519`
- 公钥：`~/.ssh/id_ed25519.pub`

---

## 步骤二：获取公钥内容

在 **192.168.101.245** 上执行：

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519
```

会输出类似：
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPycpWkd9xTPHOzsHs/Qq1CeGFOzO8JeDRQd3z8eZhHS yihu
```

---

## 步骤三：添加公钥到 authorized_keys

在 **192.168.101.245** 上执行：

```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPycpWkd9xTPHOzsHs/Qq1CeGFOzO8JeDRQd3z8eZhHS yihu" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## 步骤四：获取私钥

在 **192.168.101.245** 上查看私钥内容：

```bash
cat ~/.ssh/id_ed25519
```

会输出类似：
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACD8nKVpHfcUzxzs7B7P0KtQnhhTszvCXg0UHd8/HmYR0gAAAIiqEcZWqhHG
...
-----END OPENSSH PRIVATE KEY-----
```

---

## 步骤五：在 OpenClaw 上保存私钥并连接

在 **OpenClaw 系统**上执行：

```bash
# 保存私钥到临时文件
cat > /tmp/id_ed25519_yihu << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
你的私钥内容
-----END OPENSSH PRIVATE KEY-----
EOF

chmod 600 /tmp/id_ed25519_yihu

# 连接远程服务器
ssh -i /tmp/id_ed25519_yihu -F /dev/null -o StrictHostKeyChecking=no yihu@192.168.101.245
```

---

## 注意事项

### 1. known_hosts 问题
如果出现 `REMOTE HOST IDENTIFICATION HAS CHANGED` 警告，是因为服务器 SSH 密钥变了。可以清除旧密钥：
```bash
ssh-keygen -f "/home/node/.ssh/known_hosts" -R "192.168.101.245"
```

### 2. SSH config 权限问题
如果出现 `Bad owner or permissions on /home/node/.ssh/config`，使用 `-F /dev/null` 参数跳过 config 文件。

### 3. 安全建议
- 私钥文件 chmod 600 权限
- 私钥使用完毕后可删除
- 建议使用 ssh-copy-id 自动化操作

### 4. 备选方案：ssh-copy-id
如果远程服务器有密码认证，可以用：
```bash
ssh-copy-id yihu@192.168.101.245
```
自动完成公钥传输。

---

## 验证连接

成功后应看到：
```
✅ SSH连接成功!
openclaw
yihu
/home/yihu
```

---

## 故障排除

| 问题 | 解决方法 |
|------|----------|
| Permission denied (publickey) | 确认公钥已正确添加到 authorized_keys |
| Bad owner or permissions | 使用 `-F /dev/null` 参数 |
| Host key changed | 清除 known_hosts 中的旧密钥 |
| Connection timeout | 检查网络连通性和 SSH 服务状态 |

---

*文档生成时间：2026-03-24*
