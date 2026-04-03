# OpenClaw Skill: github-to-notebooklm

## 快速开始

### 安装

```bash
# 安装 skill
pip install -e .

# 登录 NotebookLM
notebooklm login
```

### 使用

```bash
# 导入 GitHub 项目到 NotebookLM
github-to-notebooklm https://github.com/user/repo --title "My Analysis"

# 或使用短命令
g2n https://github.com/user/repo --title "My Analysis"
```

## 作为 OpenClaw Skill 使用

```python
# 在 OpenClaw 中
oc skill add github-to-notebooklm

# 使用
oc github-to-notebooklm import https://github.com/user/repo --title "Analysis"
```

## 项目结构

```
github_to_notebooklm/
├── __init__.py          # 包初始化
├── core.py              # 核心功能
├── skill.py             # OpenClaw Skill 接口
└── README.md            # 文档

pyproject.toml            # 项目配置
setup.py                  # 安装脚本
```

## 开发

```bash
# 安装开发依赖
pip install -e ".[dev]"

# 运行测试
pytest

# 代码格式化
black github_to_notebooklm/

# 类型检查
mypy github_to_notebooklm/
```
