---
name: pinchtab
description: 使用 PinchTab 完成浏览器自动化：打开网页、查看可交互元素、点击操作、填写表单、页面文本抓取、使用持久化 profile 登录站点、导出截图或 PDF、管理多个浏览器实例，或在 CLI 不可用时回退到 HTTP API。优先用于基于稳定无障碍 ref（如 e5、e12）的 token 高效浏览器操作。
metadata:
  openclaw:
    requires:
      bins:
        - pinchtab
      anyBins:
        - google-chrome
        - google-chrome-stable
        - chromium
        - chromium-browser
    homepage: https://github.com/pinchtab/pinchtab
    install:
      - kind: brew
        formula: pinchtab/tap/pinchtab
        bins: [pinchtab]
      - kind: go
        package: github.com/pinchtab/pinchtab/cmd/pinchtab@latest
        bins: [pinchtab]
---

# 使用 PinchTab 进行浏览器自动化

PinchTab 为 AI 代理提供了可通过稳定无障碍 ref、低 token 文本提取和持久化 profile/实例驱动的浏览器。将其视为 CLI 优先的浏览器技能；仅在 CLI 不可用或需要 CLI 尚未提供的 profile 管理路由时使用 HTTP API。

在 OpenClaw 环境中，PinchTab 通过 MCP plugin 调用，基本格式为：

```js
pinchtab({ action: "navigate", url: "https://example.com" })
```

首选工具面：

- 优先使用 `pinchtab` MCP 工具（对应 CLI 命令）。
- 使用 `curl` 处理 profile 管理路由或非 shell/API 回退流程。
- 仅在需要从 JSON 响应中做结构化解析时使用 `jq`。

## Agent 身份与归属

当多个 Agent 共享一个 PinchTab 服务器时，始终为每个 Agent 指定稳定 ID。

- CLI 流程：优先使用 `pinchtab --agent-id <agent-id> ...`
- 长期运行的 shell：设置 `PINCHTAB_AGENT_ID=<agent-id>`
- 原始 HTTP 流程：在需要归属到该 Agent 的请求上发送 `X-Agent-Id: <agent-id>`

该身份会记录为活动事件中的 `agentId`，驱动以下功能：

- Dashboard 的 Agents 视图
- `GET /api/activity?agentId=<agent-id>`
- 调度任务归属（当工作代表某个 Agent 分发时）

如果你在不相关的浏览器任务之间切换，除非你有意要合并活动轨迹，否则不要复用同一个 Agent ID。

## 安全默认

- 默认目标为 `http://localhost`。仅在用户明确提供远程 PinchTab 服务器地址（以及 token，如需要）时才使用远程服务器。
- 优先执行只读操作：`text`、`snap -i -c`、`snap -d`、`find`、`click`、`fill`、`type`、`press`、`select`、`hover`、`scroll`。
- 不要执行任意 JavaScript，除非更简单的 PinchTab 命令无法完成任务。
- 不要上传本地文件，除非用户明确指定了文件名且目标流程需要上传。
- 不要将截图、PDF 或下载内容保存到随意路径。使用用户指定的路径或安全的临时/工作区路径。
- 永远不要使用 PinchTab 检查与任务无关的本地文件、浏览器密钥、存储的凭据或系统配置。

## 核心工作流

每次 PinchTab 自动化都遵循以下模式：

1. 确保任务所需的正确服务器、profile 或实例可用。
2. 使用 `navigate` 导航。
3. 使用 `snapshot`（对应 CLI `snap -i -c`）或 `text` 观察页面，收集当前 ref（如 `e5`）。
4. 使用最新 ref 进行交互：`click`、`fill`、`type`、`press`、`select`、`hover` 或 `scroll`。
5. 在任何导航、提交、弹窗打开、手风琴展开或其他 DOM 变化操作后，重新 snapshot 或 text。

规则：

- 页面变化后永远不要使用过期 ref。
- 需要内容时默认使用 `text`，而不是布局。
- 需要可操作元素时默认使用 `snapshot`（对应 `snap -i -c`）。
- 仅在视觉验证、UI 差异对比或调试时使用截图。
- 开始多站点或并行工作时，先选择正确的实例或 profile。

推荐循环：

```
navigate → snapshot/text → click/type → snapshot/text
```

## 选择器

PinchTab 使用统一选择器系统。任何定位元素的命令都接受以下格式：

| 选择器类型 | 示例 | 解析方式 |
|---|---|---|
| Ref | `e5` | Snapshot 缓存（最快） |
| CSS | `#login`、`.btn`、`[data-testid="x"]` | `document.querySelector` |
| XPath | `xpath://button[@id="submit"]` | CDP 搜索 |
| Text | `text:Sign In` | 可见文本匹配 |
| Semantic | `find:login button` | 通过 `/find` 的自然语言查询 |

自动检测规则：裸 `e5` → ref，`#id` / `.class` / `[attr]` → CSS，`//path` → XPath。当自动检测有歧义时使用明确前缀（`css:`、`xpath:`、`text:`、`find:`）。

```bash
pinchtab click e5                        # ref
pinchtab click "#submit"                 # CSS（自动检测）
pinchtab click "text:Sign In"            # 文本匹配
pinchtab click "xpath://button[@type]"   # XPath
pinchtab fill "#email" "user@test.com"   # CSS
pinchtab fill e3 "user@test.com"         # ref
```

在 HTTP API 中通过 `selector` 字段使用相同语法：

```json
{"kind": "click", "selector": "text:Sign In"}
{"kind": "fill", "selector": "#email", "text": "user@test.com"}
{"kind": "click", "selector": "e5"}
```

旧版 `ref` 字段仍然为向后兼容而支持。

在 OpenClaw MCP 环境中，示例：

```js
pinchtab({ action: "click", ref: "e5" })
pinchtab({ action: "click", selector: "text:Sign In" })
pinchtab({ action: "fill", selector: "#email", text: "user@test.com" })
```

## 命令链

仅在不需要检查中间输出来决定下一步时使用命令链。

好的做法：

```bash
pinchtab nav https://pinchtab.com && pinchtab snap -i -c
pinchtab click --wait-nav e5 && pinchtab snap -i -c
pinchtab nav https://pinchtab.com --block-images && pinchtab text
```

当必须先阅读 snapshot 输出时，分步执行：

```bash
pinchtab nav https://pinchtab.com
pinchtab snap -i -c
# 阅读 ref，选择正确的 e#
pinchtab click e7
pinchtab snap -i -c
```

在 OpenClaw MCP 中，始终分步调用：

```js
pinchtab({ action: "navigate", url: "https://pinchtab.com" })
pinchtab({ action: "snapshot", filter: "interactive", format: "compact" })
// 阅读 ref，选择正确的 e#
pinchtab({ action: "click", ref: "e7" })
pinchtab({ action: "snapshot", filter: "interactive", format: "compact" })
```

## Challenge 求解

PinchTab 包含可插拔的求解器框架，可自动检测并解决浏览器验证挑战（Cloudflare Turnstile、CAPTCHA、中间页）。在导航**之后**、页面显示挑战而非预期内容时使用此功能。

**重要提示：** 求解器在 PinchTab 配置中设置 `stealthLevel: "full"`（或 `instanceDefaults.stealthLevel: "full"`）时效果最佳。完全隐身模式会修补 CDP 检测向量、轮换指纹并遮蔽自动化信号 — 这些都是 Cloudflare 等验证提供者在复选框点击前后检查的内容。没有完全隐身模式，求解器可能正确点击但验证仍因指纹验证失败。

```bash
# 自动检测并解决当前页面上的任何验证挑战
curl -X POST http://localhost:9867/solve \
  -H 'Content-Type: application/json' \
  -d '{"maxAttempts": 3, "timeout": 30000}'

# 使用特定求解器
curl -X POST http://localhost:9867/solve/cloudflare \
  -H 'Content-Type: application/json' \
  -d '{"maxAttempts": 3}'

# Tab 级别求解
curl -X POST http://localhost:9867/tabs/TAB_ID/solve \
  -H 'Content-Type: application/json' \
  -d '{}'

# 列出可用求解器
curl http://localhost:9867/solvers
```

**何时使用 solve：**

- 页面标题为"Just a moment..."或类似的验证指示
- 导航后 `text` 返回空内容或验证页面文本
- Cloudflare Turnstile 组件阻挡了目标内容

**工作流模式：**

```bash
pinchtab nav https://protected-site.com
pinchtab text                    # 检查页面是否加载或显示验证挑战
# 如果检测到验证挑战：
curl -X POST http://localhost:9867/solve \
  -H 'Content-Type: application/json' -d '{}'
pinchtab text                    # 验证：现在应显示真实页面内容
```

**响应字段：** `solver`（哪个求解器处理了）、`solved`（布尔值）、`challengeType`（如 "managed"）、`attempts`、`title`（最终页面标题）。

自动检测模式（`POST /solve` 不指定求解器）会依次尝试每个注册的求解器，如果没有验证挑战则立即返回 `solved: true, attempts: 0`。这使得在任何导航后推测性调用它是安全的。

## 处理认证与状态

在开始与站点交互之前，选择以下五种模式之一。

### 1. 一次性公开浏览

对公开页面、抓取或不需要登录持久化的任务使用临时实例。

```bash
pinchtab instance start
pinchtab instances
# 将 CLI 命令指向你想使用的实例端口
pinchtab --server http://localhost:9868 nav https://pinchtab.com
pinchtab --server http://localhost:9868 text
```

### 2. 复用已有命名 profile

用于对同一已认证站点的重复任务。

```bash
pinchtab profiles
pinchtab instance start --profile work --mode headed
pinchtab --server http://localhost:9868 nav https://mail.google.com
```

如果登录已存储在该 profile 中，之后可以切换到 headless：

```bash
pinchtab instance stop inst_ea2e747f
pinchtab instance start --profile work --mode headless
```

### 3. 通过 HTTP 创建专用认证 profile

当需要持久 profile 但尚不存在时使用。

```bash
curl -X POST http://localhost:9867/profiles \
  -H "Content-Type: application/json" \
  -d '{"name":"billing","description":"Billing portal automation","useWhen":"Use for billing tasks"}'

curl -X POST http://localhost:9867/profiles/billing/start \
  -H "Content-Type: application/json" \
  -d '{"headless":false}'
```

然后使用 `--server` 指向返回的端口。

### 4. 人工辅助的 headed 登录，然后 Agent 复用

用于 CAPTCHA、MFA 或首次设置。

```bash
pinchtab instance start --profile work --mode headed
# 人工在可见的 Chrome 窗口中完成登录
pinchtab --server http://localhost:9868 nav https://app.example.com/dashboard
pinchtab --server http://localhost:9868 snap -i -c
```

一旦会话存储完毕，后续任务可复用同一 profile。

### 5. 远程或非 shell Agent 使用带 token 的 HTTP API

当 Agent 无法直接调用 CLI 时使用。

```bash
curl http://localhost:9867/health
curl -X POST http://localhost:9867/profiles \
  -H "Content-Type: application/json" \
  -d '{"name":"work"}'
curl -X POST http://localhost:9867/instances/start \
  -H "Content-Type: application/json" \
  -d '{"profileId":"work","mode":"headless"}'
curl -X POST http://localhost:9868/action \
  -H "X-Agent-Id: agent-main" \
  -H "Content-Type: application/json" \
  -d '{"kind":"click","selector":"e5"}'
```

如果服务器暴露在 localhost 之外，需要 token 并保守绑定。参见 [TRUST.md](./TRUST.md)。

**Agent 会话**：每个 Agent 可以获取自己的可撤销会话 token，而不是共享服务器 bearer token。设置 `PINCHTAB_SESSION=ses_...` 或发送 `Authorization: Session ses_...`。通过 `POST /api/sessions` 创建（`{"agentId":"...", "label":"..."}`）。会话有空闲超时（默认 12h）和最大生命周期（默认 24h）。通过 rotate（`POST /api/sessions/{id}/rotate`）和 revoke（`POST /api/sessions/{id}/revoke`）管理。

## 核心命令

### 服务器与目标定位

```bash
pinchtab server                                     # 前台启动服务器
pinchtab daemon install                             # 安装为系统服务
pinchtab health                                     # 检查服务器状态
pinchtab instances                                  # 列出运行中的实例
pinchtab profiles                                   # 列出可用 profile
pinchtab --server http://localhost:9868 snap -i -c  # 指向特定实例
```

### 导航与标签页

```bash
pinchtab nav <url>
pinchtab nav <url> --new-tab
pinchtab nav <url> --tab <tab-id>
pinchtab nav <url> --block-images
pinchtab nav <url> --block-ads
pinchtab back                                       # 后退
pinchtab forward                                    # 前进
pinchtab reload                                     # 重新加载当前页面
pinchtab tab                                        # 列出标签页或按 ID 聚焦
pinchtab tab new <url>
pinchtab tab close <tab-id>
pinchtab instance navigate <instance-id> <url>
```

对应 OpenClaw MCP 调用：

```js
pinchtab({ action: "navigate", url: "https://example.com" })
pinchtab({ action: "navigate", url: "https://example.com", newTab: true })
pinchtab({ action: "back" })
pinchtab({ action: "forward" })
pinchtab({ action: "reload" })
```

### 观察

```bash
pinchtab snap
pinchtab snap -i                                    # 仅可交互元素
pinchtab snap -i -c                                 # 可交互 + 紧凑格式
pinchtab snap -d                                    # 与上次 snapshot 的差异
pinchtab snap --selector <css>                      # 限定到 CSS 选择器
pinchtab snap --max-tokens <n>                      # Token 预算限制
pinchtab snap --text                                # 文本输出格式
pinchtab text                                       # 页面文本内容
pinchtab text --raw                                 # 原始文本提取
pinchtab find <query>                               # 语义元素搜索
pinchtab find --ref-only <query>                    # 仅返回 ref
```

指南：

- `snap -i -c` 是查找可操作 ref 的默认命令。
- `snap -d` 是多步流程中的默认后续 snapshot。
- `text` 是阅读文章、仪表板、报表或确认消息的默认命令。
- `find --ref-only` 在页面很大且你已知语义目标时很有用。

对应 OpenClaw MCP 调用：

```js
pinchtab({ action: "snapshot", filter: "interactive", format: "compact" })
pinchtab({ action: "snapshot", diff: true, filter: "interactive", format: "compact" })
pinchtab({ action: "text" })
pinchtab({ action: "text", mode: "readability" })
pinchtab({ action: "find", query: "login button" })
```

### 交互

所有交互命令接受统一选择器（ref、CSS、XPath、文本、语义）。参见上方选择器章节。

```bash
pinchtab click <selector>                           # 点击元素
pinchtab click --wait-nav <selector>                # 点击并等待导航
pinchtab click --x 100 --y 200                      # 按坐标点击
pinchtab dblclick <selector>                        # 双击元素
pinchtab type <selector> <text>                     # 按键输入
pinchtab fill <selector> <text>                     # 直接设值
pinchtab press <key>                                # 按键（Enter、Tab、Escape...）
pinchtab hover <selector>                           # 悬停元素
pinchtab select <selector> <value>                  # 选择下拉选项
pinchtab scroll <selector|pixels>                   # 滚动元素或页面
```

规则：

- 表单录入优先使用 `fill`（确定性）。
- 仅当站点依赖键盘事件时才使用 `type`。
- 当点击预期会导航时使用 `click --wait-nav`。
- 在 `click`、`press Enter`、`select` 或 `scroll` 后，如果 UI 可能改变，立即重新 snapshot。

对应 OpenClaw MCP 调用：

```js
pinchtab({ action: "click", ref: "e5" })
pinchtab({ action: "click", selector: "text:Sign In" })
pinchtab({ action: "fill", ref: "e3", text: "user@example.com" })
pinchtab({ action: "type", ref: "e8", text: "search query" })
pinchtab({ action: "press", key: "Enter" })
pinchtab({ action: "hover", ref: "e2" })
pinchtab({ action: "select", ref: "e6", value: "option1" })
pinchtab({ action: "scroll", pixels: 500 })
```

### 导出、调试与验证

```bash
pinchtab screenshot
pinchtab screenshot -o /tmp/pinchtab-page.png       # 格式由扩展名驱动
pinchtab screenshot -q 60                            # JPEG 质量
pinchtab pdf
pinchtab pdf -o /tmp/pinchtab-report.pdf
pinchtab pdf --landscape
```

对应 OpenClaw MCP 调用：

```js
pinchtab({ action: "screenshot", quality: 80 })
pinchtab({ action: "pdf" })
```

### 高级操作：仅在明确需要时使用

仅在任务明确要求且更安全的命令不够用时使用这些命令。

```bash
pinchtab eval "document.title"
pinchtab download <url> -o /tmp/pinchtab-download.bin
pinchtab upload /absolute/path/provided-by-user.ext -s <css>
```

规则：

- `eval` 用于狭窄的只读 DOM 检查，除非用户明确要求页面变更。
- `download` 应优先使用安全的临时或工作区路径，而非任意文件系统位置。
- `upload` 需要用户明确提供或认可的文件路径。

对应 OpenClaw MCP 调用：

```js
pinchtab({ action: "evaluate", expression: "document.title" })
```

### HTTP API 回退

```bash
curl -X POST http://localhost:9868/navigate \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'

curl "http://localhost:9868/snapshot?filter=interactive&format=compact"

curl -X POST http://localhost:9868/action \
  -H "Content-Type: application/json" \
  -d '{"kind":"fill","selector":"e3","text":"ada@example.com"}'

curl http://localhost:9868/text

# 实例级别求解（实例端口，非服务器端口）
curl -X POST http://localhost:9868/solve \
  -H "Content-Type: application/json" \
  -d '{"maxAttempts": 3}'

curl http://localhost:9868/solvers
```

在以下情况使用 API：

- Agent 无法 shell out 时
- 需要 profile 创建或变更时
- 需要明确的实例和标签页范围路由时

## 常见模式

### 打开页面并检查操作

```bash
pinchtab nav https://pinchtab.com && pinchtab snap -i -c
```

OpenClaw MCP 版本：

```js
pinchtab({ action: "navigate", url: "https://pinchtab.com" })
pinchtab({ action: "snapshot", filter: "interactive", format: "compact" })
```

### 填写并提交表单

```bash
pinchtab nav https://example.com/login
pinchtab snap -i -c
pinchtab fill e3 "user@example.com"
pinchtab fill e4 "correct horse battery staple"
pinchtab click --wait-nav e5
pinchtab text
```

OpenClaw MCP 版本：

```js
pinchtab({ action: "navigate", url: "https://example.com/login" })
pinchtab({ action: "snapshot", filter: "interactive", format: "compact" })
pinchtab({ action: "fill", ref: "e3", text: "user@example.com" })
pinchtab({ action: "fill", ref: "e4", text: "correct horse battery staple" })
pinchtab({ action: "click", ref: "e5" })
pinchtab({ action: "text" })
```

### 搜索并低成本提取结果页

```bash
pinchtab nav https://example.com/search
pinchtab snap -i -c
pinchtab fill e2 "quarterly report"
pinchtab click e3  # 点击搜索按钮
pinchtab text
```

**表单提交规则：**
- ❌ **永远不要在常规表单输入框上使用 `press Enter`。** 它不会提交标准 HTML 表单。
- ✅ **始终点击提交按钮**来触发表单提交处理器。
- **原因？** HTML5 表单仅在有显式 JavaScript `onkeypress` 或 `onkeyup` 处理器时才会在 Enter 时自动提交。`<form onsubmit>` 处理器仅在点击按钮时触发，而不是在按 Enter 时。

**来自基准测试的真实示例：**

```bash
# 错误：这会失败
pinchtab nav http://fixtures/wiki.html
pinchtab snap -i -c
pinchtab fill "#wiki-search-input" "go"
pinchtab press Enter  # ❌ 不会提交表单

# 正确：这能工作
pinchtab nav http://fixtures/wiki.html
pinchtab snap -i -c
pinchtab fill "#wiki-search-input" "go"
pinchtab click "#wiki-search-btn"  # ✅ 触发 onsubmit 处理器
pinchtab text  # 现在在结果页面上
```

**始终遵循此模式：**

```bash
# 模板：fill 然后 click
pinchtab fill "<selector>" "value"
pinchtab click "<button-selector>"  # 始终点击，永远不要 press Enter
pinchtab text  # 验证表单已提交
```

### 在多步流程中使用 diff 快照

```bash
pinchtab nav https://example.com/checkout
pinchtab snap -i -c
pinchtab click e8
pinchtab snap -d -i -c
```

OpenClaw MCP 版本：

```js
pinchtab({ action: "navigate", url: "https://example.com/checkout" })
pinchtab({ action: "snapshot", filter: "interactive", format: "compact" })
pinchtab({ action: "click", ref: "e8" })
pinchtab({ action: "snapshot", diff: true, filter: "interactive", format: "compact" })
```

### 无需 snapshot 直接定位元素

当你了解页面结构时，跳过 snapshot 直接使用 CSS 或文本选择器：

```bash
pinchtab click "text:Accept Cookies"
pinchtab fill "#search" "quarterly report"
pinchtab click "xpath://button[@type='submit']"
```

OpenClaw MCP 版本：

```js
pinchtab({ action: "click", selector: "text:Accept Cookies" })
pinchtab({ action: "fill", selector: "#search", text: "quarterly report" })
```

### 通过 Cloudflare 保护站点导航

```bash
pinchtab nav https://protected-site.com
# 页面可能显示 CF 验证挑战（"Just a moment..."）
curl -X POST http://localhost:9867/solve \
  -H 'Content-Type: application/json' -d '{"maxAttempts": 3}'
# 现在真实页面已加载 — 正常继续
pinchtab snap -i -c
pinchtab text
```

### 引导认证 profile

```bash
pinchtab profiles
pinchtab instance start --profile work --mode headed
# 人工登录一次
pinchtab --server http://localhost:9868 text
```

### 为不同站点运行独立实例

```bash
pinchtab instance start --profile work --mode headless
pinchtab instance start --profile staging --mode headless
pinchtab instances
```

然后使用 `--server` 将每个命令流指向各自的端口。

## 安全与 Token 经济

- 使用专用自动化 profile，而非日常浏览 profile。
- 如果 PinchTab 可从外部机器访问，要求 token 并保守绑定。
- 在截图、PDF、eval、下载或上传之前，优先使用 `text`、`snap -i -c` 和 `snap -d`。
- 对不需要视觉资源的读取密集型任务使用 `--block-images`。
- 在不相关的账户或环境之间切换时停止或隔离实例。

## Diff 与验证

- 在长工作流中每次状态变更操作后使用 `snap -d`。
- 使用 `text` 确认成功消息、表格更新或导航结果。
- 仅在视觉回归、CAPTCHA 或布局特定确认重要时使用 `screenshot`。
- 如果 ref 在变更后消失，将其视为预期行为，获取新 ref 而非重试过期的 ref。

## 隐私与安全

PinchTab 是完全开源的本地优先浏览器自动化工具：

- **仅在 localhost 运行。** 服务器默认绑定到 `127.0.0.1`。PinchTab 本身不进行外部网络调用。
- **无遥测或分析。** 二进制文件不进行任何外发连接。
- **单一 Go 二进制文件（约 16 MB）。** 完全可验证 — 任何人都可以从 [github.com/pinchtab/pinchtab](https://github.com/pinchtab/pinchtab) 源码构建。
- **本地 Chrome profile。** 持久化 profile 仅在你的机器上存储 cookie 和会话。这使得 Agent 无需重新输入凭据即可复用已认证的会话，类似于人类复用其浏览器 profile 的方式。
- **Token 高效设计。** 使用无障碍树（结构化文本）而非截图，保持 Agent 上下文窗口小。可与 Playwright 媲美，但专为 AI Agent 构建。
- **多实例隔离。** 每个浏览器实例在自己的 profile 目录中运行，带有标签页级锁定以实现安全的多 Agent 使用。

## 内容提取：text vs snapshot

选择正确的提取方法：

| 用例 | 推荐方式 | 原因 |
|------|----------|------|
| 文章正文、段落 | `text` | 干净的散文提取 |
| 卡片中的价格、数字 | `snapshot` | text 会剥离结构化数据 |
| 表单字段值 | `snapshot` | 可查看当前输入值 |
| 验证元素是否存在 | 带选择器的 `snapshot` | text 不会显示标题 |
| JS 渲染内容 | 等待后的 `snapshot` | text 可能遗漏动态内容 |

**常见陷阱**：`text` 提取可读散文但会剥离标题、价格和结构化 UI 元素。如果需要验证标题、价格或按钮标签，请使用 `snapshot`。

```bash
# 错误：在 text 输出中查找 "$149.99"
pinchtab text | grep "149.99"  # 可能失败 — 价格经常被剥离

# 正确：snapshot 包含所有可见文本
pinchtab snap -c | grep "149.99"  # 有效
```

## Fixture 选择器快速参考

| 页面 | 关键选择器 |
|------|-----------|
| 电商 | `.add-to-cart`、`#checkout-btn`、`.price`（对价格值使用 `snapshot` 而非 `-c`） |
| 搜索 | `#search-input`、`#search-btn`（点击按钮 — 永远不要 press Enter） |
| 表单 | `#fullname`、`#email`、`#phone`、`#country`、`#subject`、`#message`、`#submit-btn` |
| Wiki | `#wiki-search-input`、`#wiki-search-btn` |
| SPA | `#new-task-input`、`#priority-select`、`#add-task-btn` |
| 登录 | `#username`、`#password`、`#login-btn`、`#logout-btn` |
| 仪表板 | `#settings-btn`、`#theme-select`、`#modal-save` |

## 参考资料

- 完整 API：[api.md](./references/api.md)
- 最小环境变量：[env.md](./references/env.md)
- Agent 优化：[agent-optimization.md](./references/agent-optimization.md)
- Profile 管理：[profiles.md](./references/profiles.md)
- MCP 集成：[mcp.md](./references/mcp.md)
- 安全模型：[TRUST.md](./TRUST.md)
