# PinchTab 浏览器替换独立服务方案

## 摘要
> **总结**：将 OpenClaw 的浏览器执行层替换为独立的 PinchTab 外部服务，避免与原项目运行态、代码路径和状态目录混用。方案采用“契约先行、验证先行、分阶段切流、可回退收口”的方式推进。  
> **交付物**：独立 PinchTab 服务、外部调用契约、状态归属约定、迁移验证、回退方案、部署文档。  
> **工作量**：Medium  
> **并行方式**：YES - 3 waves  
> **关键路径**：外部契约与测试 → 独立服务接入 → 切流与回退验证 → 清理旧浏览器路径

## 背景
### 原始需求
用户要求：`@docs\PinchTab_浏览器替换方案.md 不要和原项目混合在一次`，并明确接受“独立服务”和“完全外部化接入”作为落地方式。

### 访谈总结
已确认 PinchTab 不能作为 OpenClaw 内嵌能力落地，必须作为独立服务接入；OpenClaw 仅保留编排与外部调用，不承载 PinchTab 的运行时实现。

### Metis 评审（已消化缺口）
- 必须写死“独立服务、外部契约、状态归属、回退门”。
- 必须先做黑盒契约/一致性测试，再做接入。
- 必须明确滚动回退与失败回退，不允许保留模糊的“手工确认”验收。

## 目标
### 核心目标
把 PinchTab 作为 OpenClaw 的独立浏览器执行层接入，做到代码、运行、状态、部署四个维度都不与原项目混用。

### 交付物
- 独立 PinchTab 服务与健康检查
- OpenClaw 到 PinchTab 的外部调用契约
- 浏览器状态归属与持久化约定
- 核心浏览器流程黑盒验证
- 切流、回退、收口说明

### 完成定义（可验证条件）
- PinchTab 可独立启动并通过健康检查。
- OpenClaw 在 PinchTab 模式下只通过外部调用访问浏览器能力。
- 页面导航、点击、输入、snapshot、重启后状态保持等核心流程可验证。
- 失败时可按文档回退到旧浏览器路径。
- 清理阶段可移除旧浏览器路径且不影响主业务编排。

### 必须有
- 独立部署边界
- 外部契约
- 回退方案
- 状态归属
- 黑盒验证

### 必须没有
- 不允许把 PinchTab 实现代码混入 OpenClaw 浏览器栈
- 不允许默认共享进程树、网络命名空间或状态目录
- 不允许把“薄适配层”写回成原项目内部耦合实现
- 不允许未验证就删除旧浏览器路径

## 验证策略
> 全程只接受代理执行验证，不依赖人工肉眼确认。
- 测试决策：**tests-after + 契约优先**
- QA 策略：每个任务都要包含 happy path 与 failure path
- 证据：`.sisyphus/evidence/task-{N}-{slug}.{ext}`

## 执行策略
### 并行执行波次
> 目标：每波 5-8 个任务。当前拆分为 3 波，先契约后接入再收口。

Wave 1：契约、状态与验证基线
Wave 2：独立服务接入与 OpenClaw 外部调用
Wave 3：切流、回退、清理与文档收口

### 依赖矩阵
- 任务 1-3 为后续所有任务的前置条件
- 任务 4-6 依赖外部契约确认
- 任务 7-9 依赖服务接入完成
- 任务 10-12 依赖切流路径稳定

### 代理分发摘要
- Wave 1 → 3 个任务 → 深度/quick/unspecified-high
- Wave 2 → 4 个任务 → 深度/unspecified-high/quick
- Wave 3 → 5 个任务 → 深度/unspecified-high/writing

## 待办事项

### 1. 定义 PinchTab 独立服务边界与外部契约

**要做什么**：确定 PinchTab 的服务边界、调用协议、鉴权、超时、错误模型和版本管理方式，并将其固定为独立外部服务契约。

**必须不要做**：不要把契约写成 OpenClaw 内部模块调用；不要保留“以后再决定”的协议空洞。

**推荐代理画像**：
- 类别：`deep` — 需要明确外部服务边界与契约设计。
- 技能：`[]` — 当前无需额外技能。
- 省略：`quick` — 这不是简单文本修订。

**并行化**：可并行：YES｜Wave 1｜阻塞：任务 2-12｜被阻塞于：无

**参考**：
- `docs/PinchTab_浏览器替换方案.md:62-130` — 当前方案的架构与替换策略基础。
- `github-deploy-latest/MIGRATION.md` — 迁移文档风格参考。
- `github-deploy-latest/DEPLOY-GUIDE.md` — 部署边界写法参考。

**验收标准**：
- [ ] 形成一份独立服务契约说明，明确 transport、auth、timeout、error、version 五项。
- [ ] 明确 OpenClaw 只能通过该契约访问 PinchTab。

**QA 场景**：
```
场景：契约基线可读
  工具：Bash
  步骤：检查计划/草稿中是否明确写出服务边界、鉴权、超时、错误、版本五项。
  预期：五项全部存在且没有“待定”表述。
  证据：.sisyphus/evidence/task-1-contract-baseline.txt

场景：契约缺项拒绝
  工具：Bash
  步骤：故意移除一项契约字段并复核文档约束。
  预期：计划明确要求补齐，不能进入实现。
  证据：.sisyphus/evidence/task-1-contract-missing.txt
```

**提交**：NO｜消息：`docs(plan): define pinchTab external contract`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 2. 固化浏览器状态归属与持久化边界

**要做什么**：明确 profile、session、cookie、snapshot、下载文件的归属目录与生命周期，禁止与原项目 workspace 混用。

**必须不要做**：不要假定现有 `openclaw_data/browser` 可直接透传给 PinchTab；不要让状态目录双写。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 1｜阻塞：任务 4-12｜被阻塞于：任务 1

**参考**：
- `openclaw-minimax-docker/openclaw_data/openclaw.json` — 已有浏览器配置与数据目录边界。
- `openclaw-minimax-docker/openclaw_data/browser/openclaw/user-data/` — 独立 profile 落盘的现状。

**验收标准**：
- [ ] 文档明确 state owner、持久化目录、迁移/重置策略三项。
- [ ] 文档明确不与 `workspace/` 共用状态目录。

**QA 场景**：
```
场景：状态目录边界明确
  工具：Bash
  步骤：复查计划中对 profile/session/cookie/snapshot 的归属说明。
  预期：每类状态都有唯一归属，不存在共享语义。
  证据：.sisyphus/evidence/task-2-state-boundary.txt

场景：状态混用被拒绝
  工具：Bash
  步骤：检查计划中是否允许 PinchTab 直接写入原项目 workspace。
  预期：明确拒绝，且给出替代归属目录。
  证据：.sisyphus/evidence/task-2-state-reject.txt
```

**提交**：NO｜消息：`docs(plan): define browser state ownership`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 3. 建立浏览器黑盒验证基线

**要做什么**：列出必须覆盖的黑盒场景：独立启动、健康检查、导航、点击、输入、snapshot、重启后状态保持、失败回退。

**必须不要做**：不要把验证写成“人工看一下”；不要用抽象的“基本可用”代替具体场景。

**推荐代理画像**：
- 类别：`unspecified-high`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 1｜阻塞：任务 4-12｜被阻塞于：任务 1-2

**参考**：
- `docs/v2.0_v2.1_双轨同步实施方案.md` — 验证与边界写法参考。
- `github-deploy-latest/POST-DEPLOY-CHECKLIST.md` — 上线后检查清单风格参考。

**验收标准**：
- [ ] 形成一组可执行的黑盒验证用例。
- [ ] 每个用例都有 happy path 与 failure path。

**QA 场景**：
```
场景：黑盒基线存在
  工具：Bash
  步骤：检查计划是否列出独立启动、健康检查、导航、点击、输入、snapshot、重启保持、回退八项。
  预期：八项全部存在。
  证据：.sisyphus/evidence/task-3-blackbox-baseline.txt

场景：失败路径完整
  工具：Bash
  步骤：检查每个验证项是否都有失败条件。
  预期：每项都有失败路径。
  证据：.sisyphus/evidence/task-3-blackbox-failure.txt
```

**提交**：NO｜消息：`test(plan): define browser parity baseline`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 4. 新建 PinchTab 独立服务骨架

**要做什么**：以独立服务形式准备 PinchTab 的启动、健康检查和最小可访问接口，不进入 OpenClaw 运行时内部。

**必须不要做**：不要复用 OpenClaw 内部浏览器启动链；不要把 PinchTab 当成同容器附属能力。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 2｜阻塞：任务 5-12｜被阻塞于：任务 1-3

**参考**：
- `github-deploy-latest/README.md` — 独立部署包表达方式参考。
- `openclaw-latest-release/README.md` — 独立制品目录模式参考。

**验收标准**：
- [ ] 独立服务可单独启动。
- [ ] 健康检查可独立通过。

**QA 场景**：
```
场景：独立启动成功
  工具：Bash
  步骤：按计划中的独立服务启动方式执行启动检查。
  预期：服务启动成功并暴露健康检查。
  证据：.sisyphus/evidence/task-4-service-start.txt

场景：启动失败可定位
  工具：Bash
  步骤：模拟缺失配置启动。
  预期：失败信息能定位到配置缺失，不是 OpenClaw 内部报错。
  证据：.sisyphus/evidence/task-4-service-fail.txt
```

**提交**：NO｜消息：`feat(service): bootstrap pinchTab standalone service`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 5. 实现 OpenClaw 到 PinchTab 的外部调用客户端

**要做什么**：在 OpenClaw 侧准备仅用于外部调用的客户端层，调用目标是 PinchTab 独立服务，不包含 PinchTab 内部实现。

**必须不要做**：不要把客户端层扩展成浏览器内核适配；不要引入共享状态目录。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 2｜阻塞：任务 6-12｜被阻塞于：任务 1-4

**参考**：
- `docs/PinchTab_浏览器替换方案.md:211-227` — 角色划分可作为边界说明参考。

**验收标准**：
- [ ] OpenClaw 只通过外部接口调用 PinchTab。
- [ ] 失败时返回明确错误码/错误文本。

**QA 场景**：
```
场景：外部调用成功
  工具：Bash
  步骤：通过计划指定的方式发起一次 PinchTab 外部调用。
  预期：返回有效响应。
  证据：.sisyphus/evidence/task-5-external-call.txt

场景：外部调用失败
  工具：Bash
  步骤：关闭 PinchTab 或提供错误地址后再次调用。
  预期：OpenClaw 收到清晰失败信息，不回退到混合实现。
  证据：.sisyphus/evidence/task-5-external-call-fail.txt
```

**提交**：NO｜消息：`feat(integration): add external pinchTab client`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 6. 定义切流门与回退门

**要做什么**：明确 PinchTab 切流开关、默认路径、失败回退条件、回退执行动作与回退后验证。

**必须不要做**：不要把回退写成口头说明；不要在未达门槛时移除旧路径。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 2｜阻塞：任务 7-12｜被阻塞于：任务 1-5

**参考**：
- `docs/v2.0_实施路线图（兼容v2.1预埋约束）.md` — 分阶段切换与门禁写法参考。
- `github-deploy-latest/MIGRATION.md` — 迁移/回退表达参考。

**验收标准**：
- [ ] 有明确切流条件。
- [ ] 有明确回退条件与动作。

**QA 场景**：
```
场景：切流门有效
  工具：Bash
  步骤：检查计划中的切流门是否包含成功率、健康检查、状态保持三个条件。
  预期：条件齐全且可执行。
  证据：.sisyphus/evidence/task-6-cutover-gate.txt

场景：回退门有效
  工具：Bash
  步骤：模拟 PinchTab 失败后执行回退检查。
  预期：旧浏览器路径可恢复，且验证步骤明确。
  证据：.sisyphus/evidence/task-6-rollback-gate.txt
```

**提交**：NO｜消息：`docs(plan): define cutover and rollback gates`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 7. 接入核心浏览器动作映射

**要做什么**：把导航、点击、输入、snapshot、关闭会话等核心动作映射到 PinchTab 外部接口。

**必须不要做**：不要继续维护旧 CDP 风格调用链；不要把动作映射写进 OpenClaw 内部浏览器实现。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 2｜阻塞：任务 8-12｜被阻塞于：任务 1-6

**参考**：
- `docs/PinchTab_浏览器替换方案.md:155-165` — 需要封装的动作清单。

**验收标准**：
- [ ] 核心动作均有对应外部调用映射。
- [ ] 动作失败时可追溯到具体动作。

**QA 场景**：
```
场景：动作映射成功
  工具：Bash
  步骤：逐项执行导航、点击、输入、snapshot 映射验证。
  预期：每项均返回成功结果。
  证据：.sisyphus/evidence/task-7-action-map.txt

场景：动作映射失败
  工具：Bash
  步骤：向不存在页面执行点击/输入。
  预期：返回明确失败，不导致 OpenClaw 崩溃。
  证据：.sisyphus/evidence/task-7-action-map-fail.txt
```

**提交**：NO｜消息：`feat(browser): map core actions to pinchTab`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 8. 处理浏览器状态持久化与重启恢复

**要做什么**：确保 PinchTab 重启后可恢复既定状态，或按策略明确重置，并将行为写进验收。

**必须不要做**：不要默认“重启即丢失”或“必定恢复”而不写策略。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 2｜阻塞：任务 9-12｜被阻塞于：任务 1-7

**参考**：
- `openclaw-minimax-docker/openclaw_data/browser/openclaw/user-data/` — 现有 profile 持久化参考。

**验收标准**：
- [ ] 重启后状态恢复策略明确。
- [ ] 若不恢复，必须明确为有意重置且可验证。

**QA 场景**：
```
场景：重启后恢复
  工具：Bash
  步骤：保存状态后重启 PinchTab，再检查状态。
  预期：按策略恢复。
  证据：.sisyphus/evidence/task-8-restart-restore.txt

场景：重启后失败
  工具：Bash
  步骤：模拟状态目录损坏。
  预期：有明确错误与恢复建议。
  证据：.sisyphus/evidence/task-8-restart-fail.txt
```

**提交**：NO｜消息：`feat(browser): define persistence and recovery`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 9. 接入独立服务健康检查与部署约定

**要做什么**：定义 PinchTab 的启动、健康检查、端口、环境变量、部署目录和清理约定。

**必须不要做**：不要沿用 OpenClaw 内部浏览器容器的部署语义。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 3｜阻塞：任务 10-12｜被阻塞于：任务 1-8

**参考**：
- `github-deploy-latest/DEPLOY-GUIDE.md` — 部署约定写法参考。
- `openclaw-latest-release/README.md` — 独立制品目录约定参考。

**验收标准**：
- [ ] 有独立健康检查说明。
- [ ] 有独立部署/回收说明。

**QA 场景**：
```
场景：健康检查可用
  工具：Bash
  步骤：按部署约定调用健康检查接口。
  预期：返回健康状态。
  证据：.sisyphus/evidence/task-9-healthcheck.txt

场景：部署约定缺失拒绝
  工具：Bash
  步骤：检查计划是否遗漏端口/环境变量/清理约定。
  预期：若缺失则必须补齐，不能进入实施。
  证据：.sisyphus/evidence/task-9-deploy-missing.txt
```

**提交**：NO｜消息：`docs(deploy): define standalone service operations`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 10. 编写并行接入与切流验证步骤

**要做什么**：把并行接入、默认切换、失败回退、收口清理写成步骤化验证。

**必须不要做**：不要只写阶段名；不要没有验证结果与退出条件。

**推荐代理画像**：
- 类别：`unspecified-high`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 3｜阻塞：任务 11-12｜被阻塞于：任务 1-9

**参考**：
- `docs/v2.0_v2.1_双轨同步实施方案.md`
- `docs/v2.0_实施路线图（兼容v2.1预埋约束）.md`

**验收标准**：
- [ ] 每一阶段都有退出条件。
- [ ] 每一阶段都有失败后的回退动作。

**QA 场景**：
```
场景：并行接入验证
  工具：Bash
  步骤：检查计划是否包含并行接入、成功率记录、回退率记录。
  预期：全部存在。
  证据：.sisyphus/evidence/task-10-parallel-rollout.txt

场景：默认切换验证
  工具：Bash
  步骤：检查计划是否明确默认路径切到 PinchTab。
  预期：有明确切换点与回退点。
  证据：.sisyphus/evidence/task-10-default-switch.txt
```

**提交**：NO｜消息：`docs(plan): define rollout and rollback steps`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 11. 清理旧浏览器路径与依赖

**要做什么**：在验证通过后，移除旧浏览器容器、旧 CDP 依赖、旧路径说明，并明确保留哪些回退资产。

**必须不要做**：不要在未通过回退验证前清理；不要误删回退资产。

**推荐代理画像**：
- 类别：`deep`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：YES｜Wave 3｜阻塞：任务 12｜被阻塞于：任务 1-10

**参考**：
- `github-deploy-latest/POST-DEPLOY-CHECKLIST.md`
- `docs/PinchTab_浏览器替换方案.md:183-188`

**验收标准**：
- [ ] 旧路径清理清单明确。
- [ ] 回退资产仍然保留。

**QA 场景**：
```
场景：清理清单完整
  工具：Bash
  步骤：检查清理项是否覆盖旧容器、旧配置、旧说明。
  预期：覆盖完整。
  证据：.sisyphus/evidence/task-11-cleanup-list.txt

场景：回退资产保留
  工具：Bash
  步骤：检查回退所需配置是否仍保留。
  预期：保留完整，可快速回退。
  证据：.sisyphus/evidence/task-11-rollback-assets.txt
```

**提交**：NO｜消息：`chore(cleanup): remove legacy browser path after parity`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

### 12. 完成文档收口与发布说明

**要做什么**：把最终边界、部署方式、回退方式、状态归属写成对外可执行文档，并与现有替换方案文档统一口径。

**必须不要做**：不要保留“薄适配层优先”的旧表述；不要让文档继续暗示原项目内嵌集成。

**推荐代理画像**：
- 类别：`writing`
- 技能：`[]`
- 省略：`quick`

**并行化**：可并行：NO｜Wave 3｜阻塞：无｜被阻塞于：任务 1-11

**参考**：
- `docs/PinchTab_浏览器替换方案.md`
- `github-deploy-latest/MIGRATION.md`

**验收标准**：
- [ ] 文档口径统一为“独立服务、完全外部化、状态不混用”。
- [ ] 读者可按文档完成部署、验证与回退。

**QA 场景**：
```
场景：文档口径一致
  工具：Bash
  步骤：检查计划与草稿是否仍存在“原项目内薄适配层”表述。
  预期：不存在。
  证据：.sisyphus/evidence/task-12-doc-consistency.txt

场景：发布说明可执行
  工具：Bash
  步骤：核对部署、回退、验证三部分是否齐全。
  预期：三部分齐全。
  证据：.sisyphus/evidence/task-12-release-ready.txt
```

**提交**：NO｜消息：`docs(release): align pinchTab standalone messaging`｜文件：`.sisyphus/plans/pinchtab-浏览器替换方案.md`

## 最终验证波次（强制）
> 4 个评审任务并行执行，全部通过后才能进入收尾。若任一不通过，先修复再复审。
- [ ] F1. 计划合规审查 — oracle
- [ ] F2. 代码质量审查 — unspecified-high
- [ ] F3. 真实手工 QA — unspecified-high（如有 UI 则补 Playwright）
- [ ] F4. 范围一致性检查 — deep

## 提交策略
- 第 1 组：契约与状态边界文档
- 第 2 组：独立服务与外部调用接入
- 第 3 组：切流、回退、清理、收口文档

## 成功标准
- PinchTab 以独立服务形式落地，不与原项目混用。
- OpenClaw 只通过外部接口使用 PinchTab。
- 核心浏览器场景可验证，失败可回退。
- 旧浏览器路径可在验证通过后收口清理。
