# Workspace Index

> 记录本仓库 AI developer workspace 与 journal 的稳定入口。

---

## Overview

本目录只保存主动写入的 AI 工作记录。原始对话不在这里；跨会话检索通过 Trellis memory/平台日志完成。

### File Structure

```
workspace/
|-- index.md              # 当前文件，全局 workspace 索引
+-- {developer}/          # 单个开发者目录
    |-- index.md          # 个人会话索引
    +-- journal-N.md      # 会话记录文件

.trellis/tasks/             # 当前和归档 Trellis task artifacts
```

---

## Getting Started

### For New Developers

运行初始化脚本：

```bash
python3 ./.trellis/scripts/init_developer.py <your-name>
```

这会：
1. 创建 gitignored identity 文件。
2. 创建个人 workspace 目录。
3. 创建个人 index。
4. 创建初始 journal 文件。

### For Returning Developers

1. 获取当前 developer name：
   ```bash
   python3 ./.trellis/scripts/get_developer.py
   ```

2. 读取个人 index：
   ```bash
   cat .trellis/workspace/$(python3 ./.trellis/scripts/get_developer.py)/index.md
   ```

---

## Guidelines

### Journal File Rules

- 每个 journal 文件最多 2000 行。
- 达到上限后创建 `journal-{N+1}.md`。
- 创建新 journal 文件时更新个人 `index.md`。

### Session Record Format

每条会话记录应包含：

- Summary: 一句话说明本次做了什么。
- Branch: 工作分支。
- Main Changes: 修改了哪些文件或规则。
- Git Commits: commit hash 和 message。
- Testing: 实际跑过的验证，或明确说明未运行。
- Next Steps: 后续动作；没有则写 `None - task complete`。

---

## Session Template

记录 session 时使用这个模板：

```markdown
## Session {N}: {Title}

**Date**: YYYY-MM-DD
**Task**: {task-name}
**Branch**: `{branch-name}`

### Summary

{One-line summary}

### Main Changes

- {Change 1}
- {Change 2}

### Git Commits

| Hash | Message |
|------|---------|
| `abc1234` | {commit message} |

### Testing

- [OK] {Test result}

### Status

[OK] **Completed** / # **In Progress** / [P] **Blocked**

### Next Steps

- {Next step 1}
- {Next step 2}
```

---

## Language

`.trellis/spec/` 规则文档必须以中文为主，详见 [文档语言规范](../spec/guides/documentation-language-policy.md)。历史 journal 可以保留当时写入的语言；新增记录优先使用中文，代码标识符、路径、命令和官方术语保留原文。
