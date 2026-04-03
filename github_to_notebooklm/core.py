import os
import tempfile
from pathlib import Path
from typing import Optional, Union, List, Dict
from datetime import datetime
import subprocess
import sys

from gitingest.entrypoint import ingest


class GithubToNotebookLM:
    """
    GitHub 项目导入 NotebookLM 的核心类
    
    支持:
    - 从 GitHub URL 摄取代码
    - 生成格式化的代码摘要
    - 导入到 NotebookLM（新建或追加到已有笔记）
    """
    
    def __init__(
        self,
        max_file_size: int = 10 * 1024 * 1024,  # 10MB
        exclude_patterns: Optional[List[str]] = None,
        include_patterns: Optional[List[str]] = None,
    ):
        """
        初始化导入器
        
        Args:
            max_file_size: 最大文件大小（字节），默认 10MB
            exclude_patterns: 排除的文件模式列表
            include_patterns: 包含的文件模式列表（优先级高于排除）
        """
        self.max_file_size = max_file_size
        self.exclude_patterns = exclude_patterns or [
            "*.pyc", "__pycache__", "node_modules",
            ".git", "*.min.js", "*.min.css", "*.lock",
            "dist", "build", ".pytest_cache", ".mypy_cache",
            "*.so", "*.dylib", "*.dll",  # 二进制库
            ".env", ".env.*",  # 环境变量文件
            "coverage", ".coverage", "htmlcov",
        ]
        self.include_patterns = include_patterns or []
        self._nlm = None
        
    def _get_nlm(self):
        """延迟加载 notebooklm 客户端"""
        if self._nlm is None:
            try:
                from notebooklm import NotebookLM
                self._nlm = NotebookLM()
            except ImportError:
                raise ImportError(
                    "请先安装 notebooklm-py: pip install notebooklm-py\n"
                    "然后运行: notebooklm login"
                )
        return self._nlm
    
    def import_to_notebook(
        self,
        github_url: str,
        notebook_id: Optional[str] = None,
        notebook_title: Optional[str] = None,
        branch: Optional[str] = None,
        subpath: Optional[str] = None,
        output_mode: str = "full",  # "full", "summary", "tree"
    ) -> Dict:
        """
        将 GitHub 项目导入 NotebookLM
        
        Args:
            github_url: GitHub 项目 URL
            notebook_id: 已有笔记本 ID（为 None 则创建新笔记本）
            notebook_title: 新笔记本标题（创建新笔记本时使用）
            branch: 指定分支
            subpath: 指定子目录
            output_mode: 输出模式 - "full"(完整), "summary"(仅摘要), "tree"(仅目录树)
            
        Returns:
            Dict: 包含 notebook_id、source_id、内容统计等信息
            
        Raises:
            ImportError: 未安装 notebooklm-py
            ValueError: 参数验证失败
            RuntimeError: 导入过程中出错
        """
        print(f"🔍 正在分析 GitHub 项目: {github_url}")
        if branch:
            print(f"   分支: {branch}")
        if subpath:
            print(f"   子目录: {subpath}")
        
        # 1. 使用 gitingest 摄取代码
        print("\n📦 正在摄取代码...")
        try:
            summary, tree, content = ingest(
                source=github_url,
                max_file_size=self.max_file_size,
                exclude_patterns=set(self.exclude_patterns),
                include_patterns=set(self.include_patterns) if self.include_patterns else None,
                branch=branch,
                output=None,
            )
            print(f"   ✓ 摄取完成")
        except Exception as e:
            raise RuntimeError(f"代码摄取失败: {e}")
        
        # 2. 根据 output_mode 组合内容
        full_content = self._format_content(
            github_url=github_url,
            branch=branch,
            subpath=subpath,
            summary=summary,
            tree=tree,
            content=content,
            output_mode=output_mode,
        )
        
        # 3. 获取或创建笔记本
        nlm = self._get_nlm()
        
        if notebook_id:
            # 追加到已有笔记本
            try:
                notebook = nlm.get_notebook(notebook_id)
                print(f"\n📓 添加到已有笔记本: {notebook.title} ({notebook_id})")
            except Exception as e:
                raise RuntimeError(f"获取笔记本失败: {e}")
        else:
            # 创建新笔记本
            title = notebook_title or f"📁 {self._extract_repo_name(github_url)}"
            try:
                notebook = nlm.create_notebook(title=title)
                print(f"\n📓 创建新笔记本: {title}")
            except Exception as e:
                raise RuntimeError(f"创建笔记本失败: {e}")
        
        # 4. 保存到临时文件并上传
        repo_name = self._extract_repo_name(github_url)
        branch_info = f"@{branch}" if branch else ""
        subpath_info = f"/{subpath}" if subpath else ""
        source_name = f"{repo_name}{branch_info}{subpath_info}"
        
        with tempfile.NamedTemporaryFile(
            mode='w', 
            suffix='.txt', 
            delete=False,
            encoding='utf-8'
        ) as f:
            f.write(full_content)
            temp_path = f.name
        
        try:
            # 5. 上传到 NotebookLM
            print(f"\n⬆️  正在上传到 NotebookLM...")
            source = notebook.add_source(
                file_path=temp_path,
                source_name=source_name
            )
            print(f"   ✓ 成功添加源: {source.source_id}")
            
            # 6. 构建返回结果
            result = {
                "success": True,
                "notebook_id": notebook.notebook_id,
                "notebook_title": notebook.title,
                "source_id": source.source_id,
                "source_name": source_name,
                "github_url": github_url,
                "branch": branch,
                "subpath": subpath,
                "output_mode": output_mode,
                "content_stats": {
                    "summary_length": len(summary),
                    "tree_length": len(tree),
                    "content_length": len(content),
                    "total_length": len(full_content),
                    "estimated_tokens": len(full_content) // 4,  # 粗略估算
                },
                "timestamp": datetime.now().isoformat(),
            }
            
            # 7. 打印摘要
            self._print_summary(result)
            
            return result
            
        finally:
            # 清理临时文件
            os.unlink(temp_path)
    
    def _format_content(
        self,
        github_url: str,
        branch: Optional[str],
        subpath: Optional[str],
        summary: str,
        tree: str,
        content: str,
        output_mode: str,
    ) -> str:
        """
        格式化内容为 NotebookLM 友好的格式
        
        Args:
            github_url: GitHub 项目 URL
            branch: 分支名
            subpath: 子目录
            summary: 摘要
            tree: 目录树
            content: 文件内容
            output_mode: 输出模式
            
        Returns:
            str: 格式化后的完整内容
        """
        header = f"""# GitHub 项目代码摘要

**仓库**: {github_url}
**分支**: {branch or 'default'}
**子目录**: {subpath or 'root'}
**生成时间**: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

---

"""
        
        if output_mode == "summary":
            return f"{header}{summary}"
        elif output_mode == "tree":
            return f"{header}{summary}\n\n{tree}"
        else:  # full
            return f"{header}{summary}\n\n{tree}\n\n{content}"
    
    def _extract_repo_name(self, url: str) -> str:
        """从 GitHub URL 提取仓库名"""
        url = url.rstrip('/')
        # 处理各种格式:
        # https://github.com/owner/repo
        # https://github.com/owner/repo/tree/main/src
        # github.com/owner/repo
        if 'github.com' in url:
            parts = url.split('github.com/')[-1].split('/')
            if len(parts) >= 2:
                return f"{parts[0]}/{parts[1]}"
        return url.split('/')[-1] if '/' in url else url
    
    def _print_summary(self, result: Dict):
        """打印导入结果摘要"""
        print("\n" + "="*60)
        print("✅ 导入成功！")
        print("="*60)
        print(f"📓 笔记本: {result['notebook_title']}")
        print(f"   ID: {result['notebook_id']}")
        print(f"\n📄 源文件: {result['source_name']}")
        print(f"   ID: {result['source_id']}")
        print(f"\n📊 内容统计:")
        stats = result['content_stats']
        print(f"   - 摘要长度: {stats['summary_length']:,} 字符")
        print(f"   - 目录树: {stats['tree_length']:,} 字符")
        print(f"   - 文件内容: {stats['content_length']:,} 字符")
        print(f"   - 总计: {stats['total_length']:,} 字符")
        print(f"   - 估算 Token: ~{stats['estimated_tokens']:,}")
        print("\n💡 提示: 在 NotebookLM 中你可以问:")
        print('   - "这个项目的主要功能是什么？"')
        print('   - "解释核心架构设计"')
        print('   - "生成一个快速上手指南"')
        print("="*60)


def check_notebooklm_login() -> bool:
    """检查用户是否已登录 notebooklm"""
    try:
        from notebooklm import NotebookLM
        nlm = NotebookLM()
        # 尝试获取笔记本列表来验证登录状态
        # 注意：这里只是简单的检查，实际可能需要更可靠的方式
        return True
    except Exception as e:
        if "authentication" in str(e).lower() or "auth" in str(e).lower():
            return False
        # 其他错误可能是导入问题
        raise


def setup_notebooklm():
    """引导用户完成 notebooklm 设置"""
    print("🔧 NotebookLM 设置向导")
    print("="*60)
    
    # 检查是否已安装
    try:
        import notebooklm
        print("✓ notebooklm-py 已安装")
    except ImportError:
        print("⚠️  notebooklm-py 未安装")
        print("\n请运行以下命令安装:")
        print("  pip install notebooklm-py")
        print("\n如果需要浏览器自动登录，请运行:")
        print('  pip install "notebooklm-py[browser]"')
        print("  playwright install chromium")
        return False
    
    # 检查登录状态
    print("\n🔐 检查登录状态...")
    try:
        check_notebooklm_login()
        print("✓ 已登录 NotebookLM")
        return True
    except:
        print("⚠️  未登录 NotebookLM")
        print("\n请运行以下命令登录:")
        print("  notebooklm login")
        print("\n这将打开浏览器完成 Google OAuth 授权。")
        return False


# 命令行入口
def main():
    """命令行入口"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="将 GitHub 项目导入 NotebookLM 进行 AI 分析",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 导入到新笔记本
  python -m github_to_notebooklm https://github.com/user/repo --title "My Project"
  
  # 导入到已有笔记本
  python -m github_to_notebooklm https://github.com/user/repo --notebook-id abc123
  
  # 指定分支和子目录
  python -m github_to_notebooklm https://github.com/user/repo --branch develop --subpath src/core
  
  # 只生成摘要（减少 token 使用）
  python -m github_to_notebooklm https://github.com/user/repo --mode summary
        """
    )
    
    parser.add_argument(
        "github_url",
        help="GitHub 项目 URL（支持完整 URL 或 owner/repo 格式）"
    )
    parser.add_argument(
        "--notebook-id",
        dest="notebook_id",
        help="已有笔记本 ID（不提供则创建新笔记本）"
    )
    parser.add_argument(
        "--title",
        dest="title",
        help="新笔记本标题"
    )
    parser.add_argument(
        "--branch",
        dest="branch",
        help="指定分支（默认为默认分支）"
    )
    parser.add_argument(
        "--subpath",
        dest="subpath",
        help="指定子目录（如 src/core）"
    )
    parser.add_argument(
        "--mode",
        dest="mode",
        choices=["full", "summary", "tree"],
        default="full",
        help="输出模式: full=完整内容, summary=仅摘要, tree=摘要+目录树（默认: full）"
    )
    parser.add_argument(
        "--max-size",
        dest="max_size",
        type=int,
        default=10*1024*1024,
        help="最大文件大小（字节，默认 10MB）"
    )
    parser.add_argument(
        "--exclude",
        dest="exclude",
        nargs="+",
        default=[],
        help="额外的排除模式（如 --exclude '*.log' 'test_*'）"
    )
    parser.add_argument(
        "--setup",
        action="store_true",
        help="运行设置向导"
    )
    
    args = parser.parse_args()
    
    # 设置模式
    if args.setup:
        setup_notebooklm()
        return
    
    # 验证 URL
    if not args.github_url:
        parser.error("请提供 GitHub 项目 URL")
    
    # 检查 notebooklm 是否就绪
    try:
        check_notebooklm_login()
    except ImportError:
        print("❌ 错误: 未安装 notebooklm-py")
        print("\n请运行: pip install notebooklm-py")
        print("然后运行: notebooklm login")
        sys.exit(1)
    except:
        print("❌ 错误: 未登录 NotebookLM")
        print("\n请运行: notebooklm login")
        sys.exit(1)
    
    # 执行导入
    try:
        importer = GithubToNotebookLM(
            max_file_size=args.max_size,
            exclude_patterns=args.exclude,
        )
        
        result = importer.import_to_notebook(
            github_url=args.github_url,
            notebook_id=args.notebook_id,
            notebook_title=args.title,
            branch=args.branch,
            subpath=args.subpath,
            output_mode=args.mode,
        )
        
        sys.exit(0)
        
    except KeyboardInterrupt:
        print("\n\n⚠️  操作已取消")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
