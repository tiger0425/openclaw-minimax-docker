# OpenClaw容器网络访问改造方案

## 摘要

**问题**: OpenClaw容器无法访问宿主机和本地局域网，影响PinchTab等外部服务的集成。

**根因**: 
1. `docker-compose.prod.yml` 使用 `--bind loopback` 限制只监听127.0.0.1
2. 缺少 `ports` 映射，服务无法从外部访问  
3. 没有 `extra_hosts` 配置，容器无法解析宿主机名

**解决方案**: 采用分层递进式改造，分三个阶段实施：
- **阶段1（快速修复）**: 修改绑定参数 + 添加端口映射
- **阶段2（网络增强）**: 自定义bridge网络 + 主机名解析
- **阶段3（高级方案）**: 按需启用macvlan或host网络模式

---

## 背景

### 当前网络配置分析

根据对 `openclaw-latest-release/` 目录的分析：

**docker-compose.yml (开发/测试配置)**
```yaml
# 有ports映射，使用--bind lan
ports:
  - "18889:18889"
  - "18890:18890"
  - "19222:19222"
command: ["...", "--bind", "lan", "..."]
```

**docker-compose.prod.yml (生产配置)**
```yaml
# 无ports映射，使用--bind loopback
command: ["...", "--bind", "loopback", "..."]
# 注意：缺少 ports 配置
```

**问题总结**
| 配置项 | 当前值 | 问题 |
|-------|-------|------|
| `--bind` | `loopback` | 服务只监听127.0.0.1，外部无法访问 |
| `ports` | 未配置 | 无端口映射，无法从宿主/局域网访问 |
| `extra_hosts` | 未配置 | 无法解析host.docker.internal |
| `network_mode` | `service:openclaw-gateway` | headless-shell共享网络命名空间 |

### 影响范围

- **PinchTab集成受阻**: 如果PinchTab运行在宿主机或局域网，OpenClaw无法访问
- **调试困难**: 无法从局域网其他机器访问OpenClaw服务
- **服务发现失败**: 容器内无法通过标准方式访问宿主机服务

---

## 目标

### 核心目标
1. 让OpenClaw容器能够访问宿主机的服务（如PinchTab）
2. 让OpenClaw容器能够访问本地局域网的其他主机
3. 保持向后兼容性，允许回退到安全模式
4. 提供清晰的配置文档和验证步骤

### 非目标
- 不强制要求所有部署都开放网络访问（保持可配置）
- 不改动OpenClaw应用代码，只调整Docker配置
- 不提供跨互联网的网络访问能力

---

## 技术决策

### 决策1: 绑定参数选择
**选项A**: `--bind lan` - 监听所有接口，允许外部访问
**选项B**: `--bind loopback` - 只监听127.0.0.1，安全但隔离

**决策**: 采用**可配置策略**
- 默认使用 `--bind lan`（便于集成）
- 提供环境变量覆盖选项 `OPENCLAW_BIND=loopback`
- 在docker-compose中通过变量控制

### 决策2: 网络模式选择
**方案A**: Bridge + 端口映射（推荐默认）
- 优点: 标准、安全、可移植
- 缺点: 需要显式端口映射

**方案B**: Host网络模式
- 优点: 性能最好，直接访问宿主机
- 缺点: Linux only，安全边界模糊，端口冲突风险

**方案C**: Macvlan
- 优点: 容器获得独立IP，像物理机一样
- 缺点: 配置复杂，WiFi环境支持差，无法直接访问宿主机

**决策**: **方案A为默认**，**方案B和C作为可选高级配置**

### 决策3: 宿主机访问方式
**选项A**: `host.docker.internal` - Docker标准方式（Windows/Mac原生支持，Linux需配置）
**选项B**: `172.17.0.1` - Docker网桥网关IP（Linux only，不稳定）
**选项C**: 宿主机实际IP - 如 `192.168.101.245`（需要配置）

**决策**: **优先支持选项A和C**
- 配置 `extra_hosts` 添加 `host.docker.internal` 映射
- 允许通过环境变量指定宿主机IP
- 提供脚本自动检测并配置

---

## 执行策略

### 并行执行波次

**Wave 1: 快速修复（1-2个任务）**
- 修改docker-compose.prod.yml绑定参数
- 添加ports映射配置

**Wave 2: 网络增强（1个任务）**
- 配置自定义bridge网络和extra_hosts

**Wave 3: 验证与文档（2个任务）**
- 验证网络连通性
- 更新部署文档

---

## 待办事项

### 任务1: 修改docker-compose.prod.yml绑定参数

**What to do**:
1. 修改 `docker-compose.prod.yml` 第31行，将 `--bind loopback` 改为 `--bind lan`
2. 同时保留通过环境变量覆盖的能力

**Must NOT do**:
- 不要修改docker-compose.yml（开发配置已正确）
- 不要删除原有配置，改为可配置方式

**Recommended Agent Profile**:
- Category: `quick` - 简单配置修改
- Skills: [] - 无需特殊技能

**Parallelization**: 
- Can Parallel: YES
- Wave: 1
- Blocks: 任务2
- Blocked By: 无

**References**:
- File: `openclaw-latest-release/docker-compose.prod.yml:31`
- Pattern: `command: ["...", "--bind", "loopback", ...]`

**Acceptance Criteria**:
- [ ] docker-compose.prod.yml中使用`--bind lan`或`${OPENCLAW_BIND:-lan}`
- [ ] 可通过环境变量覆盖绑定参数

**QA Scenarios**:
```
Scenario: 验证绑定参数修改
  Tool: Bash
  Steps:
    1. cd openclaw-latest-release
    2. grep -A2 'command:' docker-compose.prod.yml | grep 'bind'
  Expected: 显示"--bind lan"或环境变量引用
  Evidence: .sisyphus/evidence/task1-bind-config.txt

Scenario: 验证环境变量覆盖
  Tool: Bash
  Steps:
    1. export OPENCLAW_BIND=loopback
    2. docker compose -f docker-compose.prod.yml config | grep bind
  Expected: 显示loopback配置
  Evidence: .sisyphus/evidence/task1-env-override.txt
```

**Commit**: 
- YES | Message: `chore(network): change bind from loopback to lan in prod compose`
- Files: `openclaw-latest-release/docker-compose.prod.yml`

---

### 任务2: 添加ports映射到docker-compose.prod.yml

**What to do**:
1. 在 `docker-compose.prod.yml` 的 `openclaw-gateway` 服务中添加 `ports` 配置
2. 映射端口：18889, 18890, 19222（与docker-compose.yml一致）

**Must NOT do**:
- 不要映射不安全的端口范围
- 不要暴露不必要的端口

**Recommended Agent Profile**:
- Category: `quick` - 简单配置修改
- Skills: [] - 无需特殊技能

**Parallelization**:
- Can Parallel: YES (与任务1同波次)
- Wave: 1
- Blocks: 任务4
- Blocked By: 无

**References**:
- Pattern: `openclaw-latest-release/docker-compose.yml:31-34`
- Example:
  ```yaml
  ports:
    - "18889:18889"
    - "18890:18890"
    - "19222:19222"
  ```

**Acceptance Criteria**:
- [ ] docker-compose.prod.yml包含ports配置
- [ ] 端口与docker-compose.yml一致

**QA Scenarios**:
```
Scenario: 验证端口配置
  Tool: Bash
  Steps:
    1. cd openclaw-latest-release
    2. docker compose -f docker-compose.prod.yml config | grep -A10 'ports'
  Expected: 显示三个端口映射
  Evidence: .sisyphus/evidence/task2-ports-config.txt

Scenario: 验证端口可访问性
  Tool: Bash (需要容器运行)
  Steps:
    1. docker compose -f docker-compose.prod.yml up -d
    2. curl -s http://localhost:18889/health || echo "服务可能未完全启动"
  Expected: 返回HTTP响应(200或404均可，只要不拒绝连接)
  Evidence: .sisyphus/evidence/task2-port-access.txt
```

**Commit**:
- YES | Message: `chore(network): add ports mapping to prod compose`
- Files: `openclaw-latest-release/docker-compose.prod.yml`

---

### 任务3: 配置extra_hosts和自定义网络

**What to do**:
1. 在 `docker-compose.prod.yml` 中添加 `extra_hosts` 配置，支持 `host.docker.internal`
2. 添加自定义bridge网络配置（可选，用于更精细的网络控制）
3. 添加环境变量支持自定义宿主机IP

**Must NOT do**:
- 不要破坏现有headless-shell的network_mode配置
- 不要引入macvlan等复杂配置作为默认

**Recommended Agent Profile**:
- Category: `standard` - 网络配置需要理解Docker网络模型
- Skills: [] - 基础Docker知识

**Parallelization**:
- Can Parallel: NO (依赖任务1、2)
- Wave: 2
- Blocks: 任务4
- Blocked By: 任务1, 任务2

**References**:
- Docker文档: https://docs.docker.com/compose/compose-file/05-services/#extra_hosts
- File: `openclaw-latest-release/.env.example` - 需要添加新变量

**配置示例**:
```yaml
services:
  openclaw-gateway:
    extra_hosts:
      - "host.docker.internal:host-gateway"
      - "pinchtab-host:${PINCHTAB_HOST:-host-gateway}"
    environment:
      - HOST_IP=${HOST_IP:-host.docker.internal}
    networks:
      - openclaw-net

networks:
  openclaw-net:
    driver: bridge
```

**Acceptance Criteria**:
- [ ] extra_hosts配置支持host.docker.internal
- [ ] 环境变量HOST_IP可用于指定宿主机地址
- [ ] .env.example更新说明新变量

**QA Scenarios**:
```
Scenario: 验证host.docker.internal解析
  Tool: Bash
  Steps:
    1. docker compose -f docker-compose.prod.yml run --rm openclaw-gateway \
       sh -c "getent hosts host.docker.internal || curl -v http://host.docker.internal:18889"
  Expected: 能解析到宿主机IP(通常是172.x.x.1)
  Evidence: .sisyphus/evidence/task3-host-resolution.txt

Scenario: 验证自定义HOST_IP
  Tool: Bash
  Steps:
    1. export HOST_IP=192.168.101.245
    2. docker compose -f docker-compose.prod.yml config | grep HOST_IP
  Expected: 显示自定义IP配置
  Evidence: .sisyphus/evidence/task3-custom-host.txt
```

**Commit**:
- YES | Message: `feat(network): add extra_hosts and custom network configuration`
- Files: `openclaw-latest-release/docker-compose.prod.yml`, `openclaw-latest-release/.env.example`

---

### 任务4: 验证网络连通性

**What to do**:
1. 启动容器并验证端口映射生效
2. 从容器内部访问宿主机（curl/ping测试）
3. 从局域网其他机器访问OpenClaw服务
4. 验证PinchTab场景（如果适用）

**Must NOT do**:
- 不要修改生产环境的运行配置，使用测试环境验证
- 不要依赖外部网络（互联网）进行核心功能验证

**Recommended Agent Profile**:
- Category: `unspecified-high` - 需要执行测试和验证
- Skills: [] - 基础网络诊断

**Parallelization**:
- Can Parallel: NO (依赖前面所有任务)
- Wave: 3
- Blocks: 无
- Blocked By: 任务1, 任务2, 任务3

**Verification Steps**:
1. **容器启动验证**
   ```bash
   cd openclaw-latest-release
   docker compose -f docker-compose.prod.yml up -d
   docker compose -f docker-compose.prod.yml ps
   ```

2. **端口映射验证**
   ```bash
   # 从宿主机访问
   curl http://localhost:18889/
   # 从局域网其他机器访问
   curl http://<宿主机IP>:18889/
   ```

3. **容器访问宿主机验证**
   ```bash
   # 进入容器
   docker exec -it openclaw-latest-prod-gateway /bin/bash
   # 测试访问宿主机
   curl http://host.docker.internal:8080  # 假设宿主机有服务在8080
   curl http://172.17.0.1:8080  # Docker网关方式
   ```

4. **局域网访问验证**
   ```bash
   # 从容器访问局域网其他主机
   docker exec openclaw-latest-prod-gateway \
     curl http://192.168.101.x:port/endpoint
   ```

**Acceptance Criteria**:
- [ ] 宿主机可以通过localhost访问OpenClaw服务
- [ ] 局域网其他机器可以通过宿主机IP访问OpenClaw服务
- [ ] 容器可以访问宿主机的服务（通过host.docker.internal或IP）
- [ ] 容器可以访问局域网其他主机

**QA Scenarios**:
```
Scenario: 端口映射验证
  Tool: Bash
  Steps:
    1. docker compose -f docker-compose.prod.yml up -d
    2. sleep 5
    3. curl -s -o /dev/null -w "%{http_code}" http://localhost:18889/
  Expected: HTTP状态码不是"000"(连接被拒绝)
  Evidence: .sisyphus/evidence/task4-port-test.txt

Scenario: 容器访问宿主机
  Tool: Bash
  Steps:
    1. # 先在宿主机启动测试服务: python3 -m http.server 9999 &
    2. docker exec openclaw-latest-prod-gateway \
       curl -s -o /dev/null -w "%{http_code}" http://host.docker.internal:9999/
  Expected: HTTP状态码为200
  Evidence: .sisyphus/evidence/task4-host-access.txt

Scenario: 容器访问局域网
  Tool: Bash
  Steps:
    1. docker exec openclaw-latest-prod-gateway \
       ping -c 1 192.168.101.1 || curl http://192.168.101.1:80
  Expected: 能收到响应
  Evidence: .sisyphus/evidence/task4-lan-access.txt
```

**Commit**: NO (这是验证任务，不修改代码)

---

### 任务5: 更新部署文档

**What to do**:
1. 更新 `openclaw-latest-release/README.md`，添加网络配置说明
2. 创建或更新网络配置专项文档
3. 添加PinchTab集成示例

**Must NOT do**:
- 不要覆盖原有的基础部署说明
- 不要包含未经验证的网络方案

**Recommended Agent Profile**:
- Category: `writing` - 文档编写
- Skills: [] - 无需特殊技能

**Parallelization**:
- Can Parallel: YES (与任务4同时)
- Wave: 3
- Blocks: 无
- Blocked By: 任务1, 任务2, 任务3

**Documentation Structure**:
1. **网络配置概述** - 解释三种网络模式
2. **默认配置说明** - 当前配置的能力和限制
3. **高级配置选项** - host网络、macvlan等
4. **PinchTab集成指南** - 具体配置示例
5. **故障排查** - 常见网络问题及解决

**Acceptance Criteria**:
- [ ] README.md包含网络配置章节
- [ ] 提供PinchTab集成示例
- [ ] 包含故障排查指南

**QA Scenarios**:
```
Scenario: 文档完整性检查
  Tool: Bash
  Steps:
    1. grep -c "network" openclaw-latest-release/README.md
    2. grep -c "PinchTab\|host.docker.internal" openclaw-latest-release/README.md
  Expected: 相关关键词出现多次
  Evidence: .sisyphus/evidence/task5-doc-check.txt

Scenario: 文档可读性
  Tool: Read
  Steps:
    1. 读取README.md网络配置章节
    2. 验证是否包含配置示例
  Expected: 有清晰的YAML配置示例
  Evidence: 文档内容截图
```

**Commit**:
- YES | Message: `docs(network): add network configuration and PinchTab integration guide`
- Files: `openclaw-latest-release/README.md`

---

## 最终验证波次（Mandatory）

在所有实施任务完成后，必须执行以下验证：

### F1. 方案合规审计 - oracle
- [ ] 检查所有修改是否遵循Docker最佳实践
- [ ] 验证配置向后兼容性
- [ ] 确认安全边界没有被意外打破

### F2. 文档质量审查 - unspecified-high
- [ ] 检查文档是否包含所有必要的配置示例
- [ ] 验证PinchTab集成指南的完整性
- [ ] 确认故障排查指南覆盖常见问题

### F3. 实际连通性测试 - unspecified-high
- [ ] 在Linux服务器环境测试
- [ ] 验证端口映射生效
- [ ] 验证容器访问宿主机
- [ ] 验证容器访问局域网

### F4. 范围保真度检查 - deep
- [ ] 确认只修改了Docker配置，未改动应用代码
- [ ] 确认保持了向后兼容（可选择loopback模式）
- [ ] 确认没有引入破坏性变更

**验收通过标准**: 所有F1-F4检查项通过，或用户明确接受风险后忽略。

---

## 决策点

### 需要用户决策的事项

1. **安全模式选择** [DECISION NEEDED]
   - **保守方案**: 默认使用 `--bind lan`，但提供环境变量覆盖选项
   - **开放方案**: 永久改为 `--bind lan`，不提供loopback选项
   - **推荐**: 保守方案，允许通过 `OPENCLAW_BIND=loopback` 回退到安全模式

2. **端口暴露范围** [DECISION NEEDED]
   - **最小范围**: 只暴露18889端口（gateway主端口）
   - **标准范围**: 暴露18889、18890、19222三个端口（与开发配置一致）
   - **推荐**: 标准范围，保持一致性

3. **宿主机访问方式** [DECISION NEEDED]
   - **方式A**: 使用 `host.docker.internal`（需Docker 20.10+，Linux需额外配置）
   - **方式B**: 使用宿主机的实际局域网IP（如192.168.101.245）
   - **方式C**: 同时支持两种方式，通过环境变量选择
   - **推荐**: 方式C，提供最灵活的集成能力

4. **是否支持host网络模式** [DECISION NEEDED]
   - **支持**: 提供可选的docker-compose.host.yml，使用`network_mode: host`
   - **不支持**: 保持bridge网络，避免平台差异
   - **推荐**: 提供文档说明，但不作为默认推荐

### 默认决策（如无用户反馈则采用）

假设用户48小时内未回复，采用以下默认决策：

| 决策项 | 默认选择 | 理由 |
|-------|---------|------|
| 安全模式 | 保守方案 | 兼顾灵活性和安全性 |
| 端口暴露 | 标准范围 | 保持一致性 |
| 宿主机访问 | 方式C | 最灵活 |
| host网络模式 | 提供文档但不默认 | 避免平台差异风险 |

---

## 风险与约束

### 已识别风险

1. **安全风险**: `--bind lan` 会让OpenClaw监听所有接口，如果没有OPENCLAW_GATEWAY_TOKEN保护，可能被未授权访问
   - **缓解**: 强制要求设置OPENCLAW_GATEWAY_TOKEN，文档中强调

2. **平台兼容性**: `host.docker.internal` 在旧版Docker/Linux上需要手动配置
   - **缓解**: 同时提供IP直接访问方式作为备选

3. **防火墙限制**: 即使配置了端口映射，宿主机防火墙可能阻止外部访问
   - **缓解**: 文档中说明需要开放端口

4. **端口冲突**: 如果宿主机已有服务占用18889等端口，会导致启动失败
   - **缓解**: 使用环境变量允许自定义端口映射

### 约束条件

1. 不能修改OpenClaw应用代码，只调整Docker配置
2. 保持向后兼容，允许回退到loopback模式
3. 支持Linux服务器和Docker Desktop（Windows/macOS）
4. 不引入新的依赖服务

---

## 成功标准

### 验收标准

1. **功能验证**:
   - [ ] 宿主机可以通过 `curl http://localhost:18889` 访问OpenClaw
   - [ ] 局域网其他机器可以通过 `curl http://<宿主机IP>:18889` 访问OpenClaw
   - [ ] 容器内可以通过 `curl http://host.docker.internal:port` 访问宿主机服务
   - [ ] 容器内可以访问局域网其他主机

2. **配置验证**:
   - [ ] `docker-compose.prod.yml` 包含ports配置
   - [ ] 可以通过环境变量覆盖绑定参数
   - [ ] `.env.example` 包含网络相关配置说明

3. **文档验证**:
   - [ ] README.md包含网络配置章节
   - [ ] 提供PinchTab集成示例
   - [ ] 包含故障排查指南

### 交付物

- 修改后的 `docker-compose.prod.yml`
- 更新后的 `.env.example`
- 更新的 `README.md`
- 验证报告（.sisyphus/evidence/目录）

---

## 附录

### A. 快速验证脚本

```bash
#!/bin/bash
# verify-network.sh - 网络连通性验证脚本

echo "=== OpenClaw网络连通性验证 ==="

# 1. 检查容器运行状态
echo "[1/5] 检查容器状态..."
docker compose -f docker-compose.prod.yml ps

# 2. 验证端口映射
echo "[2/5] 验证端口映射..."
netstat -tlnp | grep -E "18889|18890|19222" || ss -tlnp | grep -E "18889|18890|19222"

# 3. 从宿主机访问
echo "[3/5] 从宿主机访问服务..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:18889/
echo " (应该是非000状态码)"

# 4. 容器访问宿主机
echo "[4/5] 容器访问宿主机..."
docker exec openclaw-latest-prod-gateway \
  curl -s -o /dev/null -w "%{http_code}" http://host.docker.internal:18889/ 2>/dev/null || echo "需要先在宿主机启动测试服务"

# 5. 网络配置检查
echo "[5/5] 网络配置检查..."
docker exec openclaw-latest-prod-gateway cat /etc/hosts | grep host.docker.internal

echo "=== 验证完成 ==="
```

### B. PinchTab集成示例

假设PinchTab运行在宿主机8080端口：

**docker-compose.prod.yml**:
```yaml
services:
  openclaw-gateway:
    extra_hosts:
      - "pinchtab:host-gateway"
    environment:
      - PINCHTAB_URL=http://pinchtab:8080
```

**OpenClaw配置**:
在 `.env` 中设置：
```
PINCHTAB_URL=http://host.docker.internal:8080
```

### C. 常用网络诊断命令

```bash
# 查看容器网络配置
docker exec openclaw-latest-prod-gateway ip addr

# 查看容器hosts文件
docker exec openclaw-latest-prod-gateway cat /etc/hosts

# 从容器测试网络连通性
docker exec openclaw-latest-prod-gateway curl http://host.docker.internal:port

# 查看Docker网络
docker network ls
docker network inspect bridge
```
