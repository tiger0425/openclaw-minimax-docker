# PRD v2.1 实施方案

## 终审结论

- **v2.0：通过。** 可作为当前主干方案继续沿用。
- **v2.1：有条件通过。** 可以进入实施阶段，但必须按 P0 / P1 分期落地，不能一次性整体并入生产闭环。

本次终审的核心判断是：v2.1 的方向是对的，但它引入的已经不是普通功能增强，而是一套新的“控制面”能力，包括监控、策略、审批、知识沉淀、自我修复与跨 Agent 协同。如果不先划清边界，直接一体化落地，很容易形成高耦合、自反馈、难审计的系统。

---

## 背景

PRD v2.0 已经完成了产品定位、角色分工、交付链路和业务闭环定义，适合作为当前产品主干。

PRD v2.1 在此基础上进一步提出了以下增强：

- 07 号监控员升级为带运营看板与自我进化能力的控制节点
- 7 Hooks 自我进化系统
- Detection / Fixer 双 Pipeline
- 05 号数据处理员升级为 Knowledge Flywheel
- Noah 的 Autonomy Ladder
- QAPS 任务分类
- A2A 两步触发机制

这些能力本质上都不属于“单点功能”，而是对整个系统运行方式的改造。因此它们必须以统一控制面思路实施，而不能按零散功能分别接入。

---

## 实施目标

本轮实施目标不是一次性做完全部 v2.1 能力，而是先建立一套**可控、可观测、可回退**的基础框架，再逐步开放自动化执行与知识回写能力。

目标分为两层：

1. **P0 目标：先把控制面骨架搭起来**
   - 明确控制面 / 执行面边界
   - 建立统一事件模型
   - 建立策略闸门
   - 建立 Detector / Fixer 契约
   - 落只读 Dashboard

2. **P1 目标：在 P0 稳定后再打开自我进化能力**
   - 知识飞轮进入候选知识沉淀与受控发布
   - Hooks 进入建议模式，再逐步进入低风险自动应用
   - Dashboard 增加有限写操作

---

## 实施原则

### 一、控制面与执行面分离

- **控制面** 负责分类、策略、审批、观测、审计、知识晋升。
- **执行面** 负责检测、修复、任务执行、状态回传。

控制面不能直接绕开执行契约写生产状态，执行面也不能自己修改控制策略。

### 二、先可观测，再自动化

所有自动修复、自我优化、自我学习能力，都必须建立在事件、指标、审计链路已经稳定的前提上。

### 三、默认保守，逐步放权

默认采用：

- 只读观测
- 人工审批
- dry-run
- 小流量灰度
- 可一键回退

### 四、租户隔离优先

知识库、事件流、问题队列、执行凭证、Dashboard 数据投影都必须 tenant-scoped，不能默认共享。

### 五、所有关键动作必须可审计

任何策略判断、自动修复、跨 Agent 调度、知识晋升，都必须留下结构化审计记录。

---

## 当前现状判断

基于当前仓库探索结果，可以确认：

- 当前仓库几乎没有 v2.1 所需的实现基础
- 未发现监控、Dashboard、Hooks、issues pipeline、Knowledge Flywheel 的现成模块
- 因此本次实施不是“在现有系统上补几个功能”，而是“从零新增一套控制面”

这意味着实施顺序必须非常克制，优先做结构，不能先做花哨功能。

---

## 外部参考与约束

PRD v2.1 的部分灵感来源于 `https://github.com/Amyssjj/Agent_Exploration`，但需要明确：我们参考的是它的**已验证机制与踩坑经验**，不是直接照搬它的实现形态。

### 一、确认可借鉴的部分

根据对该项目 README、`Skills_MCP/OpenClaw_Selfimproving/`、`LearningNotes/` 与 `CLIs/oa-cli/` 的对照分析，可以确认以下思路与本方案高度相关：

- 7 Hooks 的生命周期分层
- Detection / Fixer 分离，以及 claim-then-fix 的运行纪律
- Route-based learning 的确定性命中思路
- OA CLI 先观测、后控制的运营看板定位
- `sessions_send` / `sessions_spawn` 在多 Agent 协作中的真实限制与踩坑经验

### 二、不应直接照搬的部分

外部项目更偏“原型实验仓 + 方法论文档仓 + CLI 工具仓”，因此以下内容不能直接作为我们 v2.1 的最终架构：

- 直接以 markdown + Route 作为正式知识库与权限来源
- 直接以 SQLite `issues` 表作为最终事实中枢
- 直接以 `sessions_send` 作为正式 A2A 主协议
- 默认大量 hook 采用 fail-open 安全姿态
- 先铺 hooks、后补治理与审计的实现顺序

### 三、本方案的定位

我们的 v2.1 应保持“**把探索性机制升级为产品化控制面**”这一方向：

- 借它的机制，不抄它的最终形态
- 借它的踩坑经验，不回退我们已经形成的 P0 / P1 分期
- 借它的确定性与低延迟思想，但继续坚持事件、策略、审批、审计、租户隔离优先

### 四、由外部对照得出的新增约束

本次对照分析后，P0 需要明确增加两条约束：

1. **统一入口归一层**
   - cron、webhook、人工触发、A2A 请求都必须先转换成统一的 `task.created -> policy.evaluated` 链路
   - 不允许不同入口各自带一套策略判定逻辑

2. **两层执行安全对齐**
   - 第一层：控制面给出允许范围、审批要求、工具与 Agent 白名单
   - 第二层：宿主 / 工具层做最终硬约束与越权拦截
   - 不允许只靠 prompt 或单层策略控制高风险执行

---

## P0 范围

P0 的目标不是做“完整 v2.1”，而是做出 **最小可运行的控制面骨架**。

### 1. 统一事件模型

先定义系统里所有关键行为的统一事件结构，至少包含：

- `tenant_id`
- `task_id`
- `trigger_id`
- `correlation_id`
- `source`
- `qaps_class`
- `autonomy_level`
- `decision`
- `status`
- `artifact_ref`
- `outcome`
- `created_at`

要求：

- Dashboard 读取它
- A2A 依赖它
- 知识飞轮消费它
- 审计记录基于它

不能每个模块各写一套日志结构。

### 2. 策略闸门

把以下三块统一收口为一条策略链：

- QAPS：负责任务分类
- Autonomy Ladder：负责授权级别
- A2A 两步触发：负责跨 Agent 行为的提案与执行边界

建议统一抽象为：

`任务进入 → 分类 → 风险分级 → 是否允许自动执行 → 是否需要审批 → 执行记录`

注意：

- QAPS 不直接决定执行
- Autonomy Ladder 不负责业务分类
- A2A 只负责按策略触发，不自带独立授权逻辑

### 2.5 统一入口归一层

P0 需要补一层显式入口适配，把不同来源的触发全部归一到同一条控制链。

要求如下：

- cron 触发要归一为标准任务事件
- webhook / 外部回调要归一为标准任务事件
- 人工操作要归一为标准任务事件
- A2A 请求要先生成统一任务上下文，再进入策略闸门

目标是确保所有入口统一进入：

`task.created -> task.classified -> policy.evaluated -> approval / execution`

如果没有这一层，后续一定会出现“同一类动作从不同入口进入却得到不同权限判断”的问题。

### 3. Detector / Fixer 契约化拆分

P0 只做契约，不做大规模自动修复。

#### Detector 职责

- 发现问题
- 生成结构化 finding
- 写入 issues / findings 队列
- 附带 evidence、confidence、severity

#### Fixer 职责

- 认领 finding
- 基于 finding 做 dry-run
- 输出修复提案
- 在符合授权时执行修复
- 更新状态与审计记录

P0 规则：

- Detector 不得直接修复
- Fixer 不负责主动扫描
- Fixer 默认 dry-run

### 4. 只读 Dashboard

P0 Dashboard 只做观测，不做控制台。

初始指标建议：

- Cron 成功率
- Agent 活跃状态
- Token 消耗趋势
- Open Issues 数量
- Findings 状态分布
- Fixer 处理耗时

P0 禁止：

- 直接在 Dashboard 上执行危险动作
- 在 Dashboard 上绕过审批流修改状态
- 在 Dashboard 上直接改策略

### 5. A2A 最小闭环

P0 的 A2A 只实现最小安全版本：

1. 创建可见 root message
2. 持久化提案记录
3. 调用真正的 Agent 触发动作
4. 记录往返次数、TTL、来源、审批状态

必须具备：

- 去重
- 最大回合数限制
- 子 Agent 禁止继续派单
- 明确的权限矩阵

### 6. 审计与回退机制

P0 必须具备：

- 关键动作审计日志
- 策略命中原因可追踪
- kill switch
- feature flag
- 失败回退路径

### 7. 两层执行安全

P0 必须明确执行安全不是单层能力，而是两层对齐：

#### 第一层：控制面安全

- 策略闸门给出允许范围
- 判断是否审批
- 输出工具与 Agent 白名单
- 输出自治级别与 TTL

#### 第二层：宿主 / 工具层安全

- 对危险命令与危险工具做最终硬拦截
- 对越权调用做最终拒绝
- 对高风险写操作保留强制阻断能力

原则是：

- prompt 只作为辅助，不作为最终安全边界
- 单层失败不应导致高风险动作直接放行
- 高风险执行必须至少经过一层 fail-closed 约束

---

## P1 范围

P1 在 P0 通过后推进，目标是把 v2.1 的“进化能力”逐步打开。

### 1. Knowledge Flywheel

P1 才进入真正的知识飞轮阶段，但要先从“候选知识库”开始。

建议分三层：

- Layer 0：原始记录
- Layer 1：结构化 closeout / case summary
- Layer 2：抽象知识（Principles / Patterns / Scars）

P1 初期规则：

- 只允许候选知识沉淀
- 不允许自动直接改 Prompt / Rule / Route
- 必须经过规则或人工审核后才能晋升为可用知识

### 2. 7 Hooks 自我进化系统

Hooks 在 P1 中建议分两步：

#### 第一步：建议模式

- before_prompt_build：建议注入什么
- before_tool_call：建议修正什么
- after_tool_call：建议记录什么
- agent_end：建议汇报什么

#### 第二步：低风险自动应用

只在低风险、可回退场景开放自动应用，例如：

- 命令参数补全
- 安全拦截
- 审计补记
- route 命中注入

不建议在早期开放：

- 自动改高风险执行策略
- 自动跨租户共享知识
- 自动修改关键业务流程

### 3. Dashboard 受控写操作

P1 可以逐步增加少量写操作，但必须受统一控制面 API 约束。

允许优先开放的动作：

- approve
- retry
- cancel
- requeue

暂不建议早期开放的动作：

- 修改核心策略
- 跳过审批
- 强制关闭关键生产任务

---

## 技术决策

### 1. 统一事件优先于功能开发

没有统一事件模型，就不应该先做 Dashboard、Knowledge Flywheel、Hooks 自动化。

### 2. Dashboard 是事件投影，不是事实来源

Dashboard 只能展示和触发受控动作，不能成为真实状态的唯一来源。

### 3. Knowledge Flywheel 先做“候选知识”，不要直接做“自动学习”

因为线上修复结果天然含噪声，直接回写会污染系统。

### 4. Hooks 先做 guardrail，再做优化器

Hooks 的首要价值是：

- 安全拦截
- 参数校正
- 审计补全
- 风险提醒

不是一开始就做全自动自我进化。

### 5. Detection 与 Fixing 必须通过队列或契约通信

不能直接函数内互相调用并共享隐式上下文，否则后续无法审计、无法回放、无法限流。

### 6. 外部经验只作为机制参考，不作为最终产品形态

`Agent_Exploration` 证明了 Hooks、Route-based learning、Detection/Fixer、OA Dashboard 的思路可行，但它更像探索与运维经验库，而不是最终生产级控制面。

因此本方案应坚持：

- 参考其机制与限制
- 不回退统一事件模型与策略链设计
- 不把 markdown 经验库直接等同于正式知识库
- 不把原型实现细节直接上升为产品协议

---

## 统一事件模型建议

建议先定义以下事件大类：

- `task.created`
- `task.classified`
- `policy.evaluated`
- `approval.requested`
- `approval.resolved`
- `finding.created`
- `fix.proposed`
- `fix.executed`
- `fix.failed`
- `knowledge.candidate_created`
- `knowledge.promoted`
- `a2a.requested`
- `a2a.executed`
- `hook.triggered`

每类事件都必须支持：

- trace 回溯
- tenant 隔离
- 风险等级
- 来源 Agent
- 关联 artifacts

---

## 策略闸门设计

统一策略闸门建议使用以下判断顺序：

1. 识别任务类型（QAPS）
2. 判断风险等级
3. 匹配自治级别（Autonomy Ladder）
4. 判断是否允许自动执行
5. 判断是否必须审批
6. 判断允许哪些工具 / 哪类 A2A
7. 生成审计记录

这样做的价值是：

- 所有权限边界都经过同一条链
- 不会出现“文档说要审批，A2A 却直接执行”的冲突
- 后续 Dashboard、Hooks、Flywheel 都能消费同一份策略输出

---

## Detector / Fixer 契约建议

### Finding 结构

建议至少包含：

- `id`
- `reported_by`
- `tenant_id`
- `type`
- `severity`
- `status`
- `confidence`
- `evidence`
- `created_at`
- `correlation_id`

### Fix Proposal 结构

建议至少包含：

- `finding_id`
- `proposed_by`
- `change_scope`
- `risk_level`
- `dry_run_result`
- `requires_approval`
- `rollback_plan`
- `resolution_note`

### 执行规则

- 所有修复先出 proposal
- proposal 先 dry-run
- 高风险修复强制审批
- 执行结果必须写回 finding

---

## Dashboard 设计边界

Dashboard 的角色应该是：

- 让 Noah / Boss 看懂系统健康状态
- 让运维看到问题流转
- 让审批人看到上下文

不应该让 Dashboard 直接承担：

- 未审计的控制台写操作
- 绕过策略链的人工改数
- 直接修改底层事实数据

建议实施顺序：

1. 只读大盘
2. 受控审批动作
3. 有审计的 retry / requeue
4. 最后才考虑更强控制能力

---

## Knowledge Flywheel 边界

Knowledge Flywheel 是 v2.1 最有长期价值的部分之一，但也是最容易失控的部分之一。

### 必须坚持的边界

- 不默认跨客户共享
- 不直接用线上成功案例改全局规则
- 不让一次性 patch 自动升级为“最佳实践”
- 不让低置信度结论进入共享知识层

### 建议落地路径

1. 先做候选知识沉淀
2. 增加信号评分
3. 做去重与归并
4. 审核后再晋升为正式知识
5. 最后再开放 Route 级别注入

---

## 里程碑

### 里程碑一：控制面骨架建立

交付物：

- 统一事件模型文档
- 策略闸门文档
- Detector / Fixer 契约文档
- Dashboard 指标定义

### 里程碑二：P0 最小闭环打通

交付物：

- 只读 Dashboard 原型
- Finding 流转闭环
- A2A 最小安全实现
- 审计与回退机制

### 里程碑三：P1 受控增强

交付物：

- 候选知识库
- Hooks 建议模式
- Dashboard 审批入口
- 小流量自动修复实验

### 里程碑四：P1 稳定化

交付物：

- 知识晋升机制
- 低风险自动应用
- 运营指标复盘
- 是否继续放量的评审结论

---

## 风险与约束

### 主要风险

1. 策略逻辑分散，导致判定不一致
2. 自动修复和知识回写相互污染
3. Dashboard 越权成为旁路控制台
4. A2A 消息回路形成 ping-pong 或级联风暴
5. 多租户知识隔离失效

### 主要约束

- 当前仓库缺乏 v2.1 直接实现基础
- 必须先补文档契约和基础设施
- 不能跳过 P0 直接做 P1

---

## 验证标准

### P0 验证标准

- 已形成统一事件模型并被核心模块共用
- QAPS / Autonomy / A2A 已统一进入单一策略链
- Detector 与 Fixer 已通过契约解耦
- Dashboard 已能只读展示关键系统状态
- 所有关键动作可审计、可回退

### P1 验证标准

- 候选知识沉淀流程稳定
- Hooks 建议模式命中率与有效性可量化
- 小流量自动修复无严重越权问题
- Dashboard 写操作全部经过统一审批链
- 未出现明显知识污染与跨租户泄露

---

## 建议的下一步动作

1. 先补一份《统一事件模型设计》
2. 再补一份《策略闸门设计》
3. 再补一份《Detector / Fixer 契约》
4. 然后再进入 Dashboard 原型设计
5. 最后再启动 Knowledge Flywheel 与 Hooks 的实现

不建议反过来先做 Dashboard 或先做 Hooks 自动化，否则大概率会返工。

---

## 最终建议

最终建议是：

- **保留 v2.0 作为主干方案继续推进**
- **批准 v2.1 进入实施，但必须按本方案拆为 P0 / P1**
- **先做控制面骨架，再做自我进化能力**

如果后续进入正式实施，建议以本文件作为总实施纲领，再拆分出三份配套设计文档：

- `docs/统一事件模型设计.md`
- `docs/策略闸门设计.md`
- `docs/Detector_Fixer_契约设计.md`
