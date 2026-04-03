# Detector / Fixer 契约设计

## 摘要

本文档定义 v2.1 在 P0 阶段的 `Detector / Fixer` 契约。目标是把“发现问题”和“修复问题”拆成两个清晰角色，并通过结构化 Finding、Proposal、ExecutionRecord 与统一事件流进行协作。

P0 重点不是自动修复，而是先把契约、状态流、审批、dry-run、审计与回退建立起来。

---

## 设计目标

1. 让 Detector 只负责发现问题，不直接修复
2. 让 Fixer 只消费结构化问题，不主动扫描
3. 让所有修复先 dry-run，再审批，再执行
4. 让执行结果与回退都可追溯

---

## 核心原则

### 一、职责单一

- `Detector`：扫描、发现、记录
- `Fixer`：认领、提案、dry-run、执行、回写

### 二、通过契约通信

Detector 与 Fixer 不允许直接共享隐式上下文，必须通过结构化实体和事件交互。

### 三、默认 dry-run

任何修复都先生成 proposal，并先 dry-run。

### 四、默认审计

任何状态变化都必须通过事件记录，并可回放。

### 五、默认租户隔离

所有 findings、proposals、executions 都必须带 `tenant_id`。

---

## 核心实体

## 1. Finding

表示“发现了一个问题”。

### 字段建议

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | finding ID |
| `tenant_id` | string | 租户 ID |
| `reported_by` | string | detector 标识 |
| `detected_at` | string | 发现时间 |
| `type` | string | 问题类型 |
| `severity` | string | 严重级别 |
| `confidence` | number | 置信度 |
| `evidence_refs` | string[] | 证据引用 |
| `status` | string | 当前状态 |
| `correlation_id` | string | 链路关联 ID |
| `metadata` | object | 扩展信息 |

### 状态建议

`open -> acknowledged -> confirmed -> in_progress -> resolved | false_positive`

---

## 2. Fix Proposal

表示“针对某个 finding 给出的修复提案”。

### 字段建议

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | proposal ID |
| `finding_id` | string | 对应问题 |
| `tenant_id` | string | 租户 ID |
| `proposed_by` | string | fixer 标识 |
| `proposed_at` | string | 提案时间 |
| `change_scope` | string | 变更范围 |
| `description` | string | 修复说明 |
| `risk_level` | string | 风险级别 |
| `requires_approval` | boolean | 是否需审批 |
| `dry_run_result` | object | dry-run 结果 |
| `rollback_plan_ref` | string | 回退方案引用 |
| `status` | string | 当前状态 |
| `audit_ref` | string | 审计记录引用 |

### 状态建议

`proposed -> dry_run_passed -> pending_approval -> approved | rejected -> executing -> executed | failed -> rolled_back`

---

## 3. Execution Record

表示“某次提案的实际执行记录”。

### 字段建议

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | execution ID |
| `proposal_id` | string | 对应 proposal |
| `executed_by` | string | 执行者 |
| `started_at` | string | 开始时间 |
| `finished_at` | string | 结束时间 |
| `outcome` | string | 执行结果 |
| `artifacts` | string[] | 产出引用 |
| `rollback_triggered` | boolean | 是否触发回退 |
| `audit_ref` | string | 审计记录引用 |

---

## 标准交互流程

Detector/Fixer 流程只接受已经过统一入口归一层的任务上下文，不直接以入口原始形态驱动执行链。也就是说，cron 检测、人工触发、A2A 派发带来的问题处理请求，都必须先进入标准任务 / 事件链，再进入 finding / proposal 流程。

### 阶段一：发现

1. Detector 扫描到异常
2. 生成 `Finding`
3. 发布 `finding.created`
4. 写入 findings 存储
5. 触发策略评估

### 阶段二：提案

1. Fixer 消费 `finding.created`
2. 读取证据与上下文
3. 先做 dry-run
4. 生成 `Fix Proposal`
5. 发布 `fix.proposed`

### 阶段三：审批

1. 策略闸门判定是否必须审批
2. 若需审批，生成 `approval.requested`
3. 审批完成后生成 `approval.resolved`
4. proposal 状态进入 `approved` 或 `rejected`

### 阶段四：执行

1. Fixer 读取已批准 proposal
2. 创建 Execution Record
3. 执行修复
4. 发布 `fix.executed` 或 `fix.failed`
5. 回写 finding / proposal 状态

### 阶段五：回退

1. 若执行失败且具备 rollback plan
2. 触发回退
3. 发布 `fix.rolled_back`
4. 标记最终状态

---

## Dry-run 规则

### 强制要求

- 所有 proposal 必须带 `dry_run_result`
- 无 dry-run 结果不得进入审批或执行
- high / critical 风险修复必须先 dry-run 成功

### `dry_run_result` 建议结构

```json
{
  "success": true,
  "summary": "预计修复配置问题，不影响其他 cron 任务",
  "artifacts": [
    "artifact://dryrun/proposal_xxx.log"
  ],
  "metrics_before": {},
  "metrics_after": {}
}
```

### 失败处理

- dry-run 失败且风险 >= medium：默认拒绝执行
- dry-run 失败但问题为低风险：可进入人工复核，不得自动执行

---

## 与策略闸门的关系

Detector/Fixer 不拥有最终执行权。最终执行权来自策略闸门。

### 必须遵守的规则

- Fixer 在生成 proposal 前，可先读取一次策略建议
- Fixer 在执行前，必须再次校验策略结果
- 高风险 proposal 未审批时，不得执行
- kill switch 打开时，不得继续执行
- 若统一入口归一失败，不得绕过策略链进入 fix 流程
- 执行面通过策略校验后，仍需接受宿主 / 工具层最终硬约束

---

## 权限与安全

### Detector 权限

- 允许读取监控、日志、指标
- 不允许直接改生产状态

### Fixer 权限

- 允许读取 finding 与 proposal
- 允许在授权后执行修复
- 不允许绕过审批链

### 最终执行硬约束

即使 proposal 已经通过策略闸门，也不代表一定允许真正落地执行。

P0 必须保留宿主 / 工具层的最终硬约束能力，例如：

- 阻断危险命令
- 阻断越权工具调用
- 阻断未授权写操作
- 在高风险失败场景直接停止执行并进入回退/告警

这层约束的目标不是替代策略闸门，而是兜住最后一公里的执行安全。

### 凭证要求

- 使用短期凭证
- 凭证使用写入审计
- 不得把长期凭证写入 evidence 或 artifacts

---

## 幂等与去重

### Detector 侧

- 同一异常短时间重复扫描，应进行聚合或去重
- 建议使用 `correlation_id + type + tenant_id` 做辅助聚合键

### Fixer 侧

- 同一 `finding_id` 不得重复生成等价 proposal
- 同一 `proposal_id` 的执行不得重复落地

### 推荐策略

- 事件总线采用 at-least-once
- 消费侧基于 ID 幂等

---

## 审计要求

以下动作必须进入审计：

- finding 创建
- proposal 创建
- dry-run 结果
- 审批请求与审批结果
- 执行开始与执行完成
- 回退开始与回退完成

审计至少包含：

- 谁做的
- 何时做的
- 做了什么
- 为什么做
- 依据了哪条策略
- 证据在哪里

---

## 回退要求

### 必须具备 rollback plan 的情况

- 配置类变更
- 路由类变更
- 系统行为调整
- 会影响线上任务流转的变更

### 回退触发条件

- 执行失败
- 关键指标恶化
- 审批撤销
- 人工触发回退

### 回退记录

回退也必须写 Execution Record 与事件，不能静默处理。

---

## P0 验证标准

1. Detector 不会直接修改生产状态
2. 所有 proposal 都带 dry-run 结果
3. high / critical proposal 不经审批不得执行
4. fix 执行失败时可进入回退路径
5. findings、proposals、executions 均可按 tenant 查询和追溯
6. 所有 fix 流程都来自统一入口归一后的上下文
7. 执行前即使已获策略许可，宿主 / 工具层仍能拦截越权操作

---

## P1 演进方向

P1 可在 P0 稳定后继续增加：

- auto-low 场景的小流量自动执行
- 更智能的 finding 合并与降噪
- 基于历史成功率调节 Fixer 权限
- 与 Knowledge Flywheel 的候选知识沉淀联动

前提是：

- 审计链完整
- 回退链可用
- 幂等与去重稳定
