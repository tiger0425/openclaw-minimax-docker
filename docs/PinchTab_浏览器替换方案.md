# PinchTab 浏览器替换方案

## 摘要

本方案讨论将 OpenClaw 当前自带的浏览器执行层，替换为 PinchTab 的可行路径。

结论先行：**可以替，但不建议直接硬切。** 更稳妥的方式是保留 OpenClaw 负责任务编排、飞书 websocket、状态管理与回复逻辑；把浏览器执行、profile 持久化、页面操作与 snapshot 能力下沉到 PinchTab，通过一层薄适配器接入。

这样做的核心收益是：

- 不动 OpenClaw 的主逻辑
- 先并行验证 PinchTab
- 允许随时回退到旧浏览器实现
- 把浏览器生命周期与会话状态收敛到单一执行层

---

## 目标

1. 让 OpenClaw 继续保持现有飞书接入与任务编排能力。
2. 将浏览器执行从 OpenClaw 自带 browser / headless-shell 迁移到 PinchTab。
3. 保留可回退路径，避免一次性替换导致系统失控。
4. 把页面控制、profile 管理、snapshot、导航、点击、输入等能力统一交给 PinchTab。

---

## 当前边界

从现有仓库可见，OpenClaw 目前的浏览器边界主要由以下内容定义：

- `openclaw.json`
  - `browser.enabled`
  - `browser.headless`
  - `browser.attachOnly`
  - `browser.executablePath`
  - `browser.profiles.cdpPort`
  - `browser.profiles.cdpUrl`
- `docker-compose.yml`
  - `headless-shell` 服务
  - `network_mode: service:openclaw-gateway`
  - 旧版自带浏览器镜像

这说明当前系统默认把浏览器当成 OpenClaw 自己的一部分来管理，而不是一个独立外部服务。

---

## PinchTab 的能力边界

PinchTab 更像一个独立的浏览器控制平面，具备以下特征：

- 可通过 HTTP API 控制浏览器
- 可通过 daemon / server / bridge 模式部署
- 支持 profile 持久化
- 支持 headed / headless
- 支持 MCP 集成
- 支持多实例与隔离

这意味着 PinchTab 不是单纯的 Chromium 替代品，而是一个**浏览器执行层 + 控制层**。

---

## 推荐架构

```text
飞书 / Websocket
    ↓
OpenClaw（任务编排、消息、状态、回传）
    ↓
Browser Adapter（新增薄适配层）
    ↓
PinchTab（浏览器执行层）
    ↓
Chrome / Profile / DOM / Snapshot
```

### 角色划分

- **OpenClaw**：负责任务编排、Agent 调度、飞书消息接入、结果汇总。
- **Browser Adapter**：负责把 OpenClaw 现有浏览器操作映射到 PinchTab API / MCP。
- **PinchTab**：负责真实浏览器生命周期、profile、页面操作、截图与结构化读取。

---

## 替换策略

### 方案 A：薄适配层（推荐）

OpenClaw 不直接接管 PinchTab 的内部协议，而是通过一层外部适配器调用 PinchTab HTTP API 或 MCP。

**优点**

- 改动最小
- 可并行验证
- 易于回退

**缺点**

- 多一层协议转换
- 需要明确状态与错误语义

### 方案 B：完全替换

直接移除 OpenClaw 自带浏览器栈，让 PinchTab 取而代之。

**优点**

- 结构清晰
- 以后浏览器能力集中

**缺点**

- 风险高
- 需要一次性解决状态迁移、回退和兼容问题

### 方案 C：并行共存

保留旧浏览器和 PinchTab 两套执行层，按任务类型分流。

**优点**

- 最稳
- 可逐步切流

**缺点**

- 运维复杂度最高

- 需要双套监控与回退策略

推荐顺序：**A → C → B**，不要反过来。

---

## 需要替换的点

### 1. 配置层

需要逐步淡化以下 OpenClaw browser 配置：

- `browser.executablePath`
- `browser.headless`
- `browser.attachOnly`
- `browser.profiles.cdpPort`
- `browser.profiles.cdpUrl`

这些字段本质上是 CDP / Chromium 驱动思路，和 PinchTab 的 HTTP / daemon 模式不完全一致。

### 2. 运行层

需要去掉或降级以下服务依赖：

- `headless-shell`
- 直接绑定 Chromium 容器的网络关系

### 3. 代码层

需要新增浏览器适配器，统一封装：

- 新建会话 / profile
- 打开页面
- 导航
- 点击 / 输入
- snapshot / text extraction
- 关闭 / 清理会话

---

## 迁移步骤

### 阶段 1：并行接入

1. 保留 OpenClaw 旧浏览器路径。
2. 新增 PinchTab 适配器。
3. 让部分低风险任务先走 PinchTab。
4. 记录成功率、回退率、登录态保持情况。

### 阶段 2：默认切换

1. 把默认浏览器执行层切到 PinchTab。
2. 旧 Chromium 路径保留为 fallback。
3. 完成主要场景验证：登录、页面操作、截图、文件、长任务。

### 阶段 3：收口清理

1. 移除 OpenClaw 自带浏览器容器。
2. 删除旧 CDP profile 依赖。
3. 更新部署与验收文档。

---

## 风险与约束

### 1. 协议不一致

OpenClaw 当前偏 CDP / Chromium，PinchTab 偏 HTTP API / MCP。两者不是天然 drop-in。

### 2. 状态归属

profile、cookie、session、下载文件和截图目录必须明确谁负责，否则会出现双写和状态漂移。

### 3. 安全边界

PinchTab 文档强调 local-first。若部署到远端，必须额外定义 token、反代、网络边界和暴露接口。

### 4. 故障归因

一旦接入外部浏览器执行层，错误会跨越 OpenClaw / PinchTab / 网络三层，必须提前定义错误归属。

---

## 建议实现边界

建议将 OpenClaw 保留为：

- 飞书接入
- 任务调度
- Agent 上下文管理
- 结果输出

将 PinchTab 承担为：

- 浏览器生命周期
- profile
- 页面控制
- DOM / snapshot / text

浏览器适配器只做一件事：**把 OpenClaw 现有浏览器动作翻译成 PinchTab 调用**。

---

## 验证标准

替换方案成立至少需要满足：

1. 飞书消息仍然可触发任务。
2. 页面导航、点击、输入、snapshot 可用。
3. 登录态可以跨重启保持。
4. 失败时可以回退到旧实现或明确失败。
5. 部署脚本可明确说明 PinchTab 的启动、健康检查和回收方式。

---

## 结论

PinchTab **适合作为 OpenClaw 的外部浏览器执行层**，但不适合一开始就直接“硬替”掉所有浏览器相关能力。

最稳妥的路线是：

> **OpenClaw 继续管任务与飞书，PinchTab 负责浏览器执行，二者之间通过薄适配器连接。**

如果后续验证稳定，再考虑把 OpenClaw 自带的 Chromium / headless-shell 路径彻底移除。
