# GitHub to NotebookLM Skill

将 GitHub 项目自动导入 NotebookLM 进行 AI 分析和问答。

## 功能特性

- 🚀 **一键导入**: 输入 GitHub URL，自动摄取代码并导入 NotebookLM
- 📁 **智能过滤**: 自动排除缓存文件、依赖目录等噪音
- 🌿 **分支支持**: 可指定特定分支进行分析
- 📂 **子目录**: 支持只导入项目中的特定目录
- 📝 **多种输出模式**: 完整内容、仅摘要、摘要+目录树
- 🔗 **追加模式**: 可导入到已有笔记本或创建新笔记本

## 安装

### 1. 安装依赖

```bash
pip install notebooklm-py gitingest
```

如果需要浏览器自动登录：
```bash
pip install "notebooklm-py[browser]"
playwright install chromium
```

### 2. 登录 NotebookLM

```bash
notebooklm login
```

这将打开浏览器完成 Google OAuth 授权。

### 3. 验证安装

```bash
python -m github_to_notebooklm --setup
```

## 使用方法

### 命令行

```bash
# 基础用法 - 导入到新笔记本
python -m github_to_notebooklm https://github.com/user/repo

# 指定标题
python -m github_to_notebooklm https://github.com/user/repo --title "My Project Analysis"

# 导入到已有笔记本
python -m github_to_notebooklm https://github.com/user/repo --notebook-id YOUR_NOTEBOOK_ID

# 指定分支
python -m github_to_notebooklm https://github.com/user/repo --branch develop

# 只导入子目录
python -m github_to_notebooklm https://github.com/user/repo --subpath src/core

# 只生成摘要（节省 token）
python -m github_to_notebooklm https://github.com/user/repo --mode summary

# 排除特定文件
python -m github_to_notebooklm https://github.com/user/repo --exclude "*.test.js" "docs/*"
```

### Python API

```python
from github_to_notebooklm import GithubToNotebookLM

# 创建导入器
importer = GithubToNotebookLM(
    max_file_size=10*1024*1024,  # 10MB
    exclude_patterns=["*.pyc", "node_modules"]
)

# 导入到新笔记本
result = importer.import_to_notebook(
    github_url="https://github.com/user/repo",
    notebook_title="Code Analysis"
)

# 导入到已有笔记本
result = importer.import_to_notebook(
    github_url="https://github.com/user/repo",
    notebook_id="your-notebook-id"
)

print(f"Notebook ID: {result['notebook_id']}")
print(f"Source ID: {result['source_id']}")
```

### OpenClaw 集成

```python
from github_to_notebooklm import Skill

# 初始化 skill
skill = Skill()

# 检查健康状态
health = skill.health_check()
print(health)

# 导入仓库
result = skill.import_repo(
    github_url="https://github.com/user/repo",
    notebook_title="Analysis"
)
```

## 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `github_url` | str | 必填 | GitHub 项目 URL |
| `--notebook-id` | str | None | 已有笔记本 ID |
| `--title` | str | None | 新笔记本标题 |
| `--branch` | str | None | 指定分支 |
| `--subpath` | str | None | 指定子目录 |
| `--mode` | str | "full" | 输出模式: full/summary/tree |
| `--max-size` | int | 10MB | 最大文件大小 |
| `--exclude` | list | [] | 额外排除模式 |

## 输出模式

- **full**: 完整内容（摘要 + 目录树 + 所有文件内容）
- **summary**: 仅摘要（适合快速了解项目概况）
- **tree**: 摘要 + 目录树（了解结构，不查看具体内容）

## 使用 NotebookLM 分析导入的项目

导入后，在 NotebookLM 中可以问：

- "这个项目的主要功能是什么？"
- "解释项目的核心架构设计"
- "生成一个快速上手指南"
- "找出代码中的潜在问题"
- "这个模块是如何工作的？"
- "比较 A 模块和 B 模块的设计差异"

## 注意事项

1. **NotebookLM 限制**: 单个文档约 200K tokens 限制，大项目建议：
   - 使用 `--subpath` 分批导入
   - 使用 `--mode summary` 减少内容
   - 调整 `--max-size` 限制文件大小

2. **非官方 API**: `notebooklm-py` 基于 Google 未公开的 API，可能随时失效

3. **首次登录**: 需要先运行 `notebooklm login` 完成 OAuth

4. **隐私**: 代码会上传到 Google 服务器进行处理

## 故障排除

### 未安装 notebooklm-py
```
❌ 错误: 未安装 notebooklm-py
请运行: pip install notebooklm-py
```

### 未登录
```
❌ 错误: 未登录 NotebookLM
请运行: notebooklm login
```

### 导入失败
- 检查 GitHub URL 是否正确
- 检查是否有网络访问权限
- 尝试减少 `--max-size` 或 `--exclude` 更多文件

## License

MIT
