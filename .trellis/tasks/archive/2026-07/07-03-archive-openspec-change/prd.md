# Archive OpenSpec change

## Goal

归档一个已完成的 OpenSpec change，并在归档前确认 delta specs 已同步到 `openspec/specs/`（即“提取 spec”）。归档完成后提交相关变更，保持 Trellis 和 OpenSpec 状态一致。

## Background

- 用户要求“提交归档代码，提取spec”。
- `openspec` CLI 当前不可用：`zsh: command not found: openspec`。本任务需要用文件系统和现有 spec 文件手动完成等价检查。
- 当前 active OpenSpec changes：
  - `clarify-public-api-vs-platform-dependencies`
  - `simplify-native-layering`
- 用户已确认采用推荐项：归档 `clarify-public-api-vs-platform-dependencies`。
- 工作区已有无关未跟踪文件：`remove_watermark.py`、`watermark_mask.png`、`watermark_removed.png`。它们不属于本任务，不能提交或删除。

## Requirements

- 让用户明确选择要归档的 OpenSpec change；不能猜测。
- 检查所选 change 的 `tasks.md` 是否全部完成。
- 对比所选 change 的 `specs/**/spec.md` 与 `openspec/specs/**/spec.md`，把尚未同步的规范内容提取/合并到主 spec。
- 归档所选 change 到 `openspec/changes/archive/YYYY-MM-DD-<change>/`。
- 提交本任务相关变更，不包含无关 watermark 文件。
- 如发现任务未完成、spec 冲突或归档目标已存在，停止并报告。

## Acceptance Criteria

- [x] 用户已选择具体 OpenSpec change。
- [x] 所选 change 的任务完成状态已检查。
- [x] 所选 change 的 delta specs 已同步到主 `openspec/specs/`，或确认无需同步。
- [x] 所选 change 已移动到 `openspec/changes/archive/2026-07-03-<change>/`。
- [x] 创建提交，且提交内容只包含本任务相关文件。
- [x] Trellis task 归档并记录 session。

## Result

- Archived change: `clarify-public-api-vs-platform-dependencies`
- Archive path: `openspec/changes/archive/2026-07-03-clarify-public-api-vs-platform-dependencies/`
- Tasks status: all tasks in `tasks.md` were checked and complete.
- Specs synced:
  - `openspec/specs/ci-enforced-consumer-verification/spec.md`
  - `openspec/specs/git-consumer-dependency-boundary/spec.md`
  - `openspec/specs/platform-runtime-verification/spec.md`
- Remaining active change: `simplify-native-layering`

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
