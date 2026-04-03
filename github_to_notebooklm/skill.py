"""
OpenClaw Skill: github-to-notebooklm
将 GitHub 项目自动导入 NotebookLM
"""

from typing import Dict, Optional
from .core import GithubToNotebookLM, setup_notebooklm, check_notebooklm_login


class Skill:
    """OpenClaw Skill 接口"""
    
    name = "github-to-notebooklm"
    version = "1.0.0"
    description = "将 GitHub 项目导入 NotebookLM 进行 AI 分析"
    
    def __init__(self, config: Optional[Dict] = None):
        """
        初始化 Skill
        
        Args:
            config: Skill 配置
        """
        self.config = config or {}
        self.importer = GithubToNotebookLM(
            max_file_size=self.config.get('max_file_size', 10 * 1024 * 1024),
            exclude_patterns=self.config.get('exclude_patterns'),
            include_patterns=self.config.get('include_patterns'),
        )
    
    def import_repo(
        self,
        github_url: str,
        notebook_id: Optional[str] = None,
        notebook_title: Optional[str] = None,
        branch: Optional[str] = None,
        subpath: Optional[str] = None,
        mode: str = "full",
    ) -> Dict:
        """
        导入 GitHub 仓库到 NotebookLM
        
        Args:
            github_url: GitHub 项目 URL
            notebook_id: 已有笔记本 ID
            notebook_title: 新笔记本标题
            branch: 指定分支
            subpath: 指定子目录
            mode: 输出模式 (full/summary/tree)
            
        Returns:
            Dict: 导入结果
        """
        return self.importer.import_to_notebook(
            github_url=github_url,
            notebook_id=notebook_id,
            notebook_title=notebook_title,
            branch=branch,
            subpath=subpath,
            output_mode=mode,
        )
    
    def setup(self) -> bool:
        """
        运行设置向导
        
        Returns:
            bool: 设置是否成功
        """
        return setup_notebooklm()
    
    def health_check(self) -> Dict:
        """
        健康检查
        
        Returns:
            Dict: 检查结果
        """
        result = {
            "skill": self.name,
            "version": self.version,
            "notebooklm_installed": False,
            "notebooklm_authenticated": False,
            "gitingest_installed": False,
        }
        
        # 检查 notebooklm
        try:
            import notebooklm
            result["notebooklm_installed"] = True
            try:
                check_notebooklm_login()
                result["notebooklm_authenticated"] = True
            except:
                pass
        except ImportError:
            pass
        
        # 检查 gitingest
        try:
            import gitingest
            result["gitingest_installed"] = True
        except ImportError:
            pass
        
        return result


# 便捷函数
def import_github_to_notebooklm(
    github_url: str,
    notebook_id: Optional[str] = None,
    notebook_title: Optional[str] = None,
    **kwargs
) -> Dict:
    """
    便捷的导入函数
    
    Args:
        github_url: GitHub 项目 URL
        notebook_id: 已有笔记本 ID
        notebook_title: 新笔记本标题
        **kwargs: 其他参数（branch, subpath, mode 等）
        
    Returns:
        Dict: 导入结果
    """
    skill = Skill()
    return skill.import_repo(
        github_url=github_url,
        notebook_id=notebook_id,
        notebook_title=notebook_title,
        **kwargs
    )
