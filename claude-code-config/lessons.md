# Lessons Learned

> Recorded after user corrections. Format: date, context, mistake, rule.
> **This file (`~/.claude/lessons.md`) stores global, cross-project lessons only.**
> Project-specific preferences belong in the project's `MEMORY.md` — see CLAUDE.md § Storage Decision.

---

## 2026-05-24
**Context**: Token optimization audit — user wanted Claude to match Qwen's efficiency.
**Mistake**: Default model was Opus (most expensive), effortLevel was xhigh, adaptive thinking was disabled, 27 plugins enabled, deep-reason and adversarial-review auto-triggered on every task. Combined cost was ~15-25x what it needed to be for routine work.
**Rule**: 
- Default model: Haiku. Escalate to Sonnet for multi-step work, Opus only for critical reasoning.
- effortLevel: medium. Let Claude scale depth to task complexity.
- Never set `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` — let Claude skip thinking on trivial tasks.
- deep-reason and adversarial-review are opt-in only, not auto-triggered.
- Keep plugins minimal — only enable what you actively use.
- Agents are opt-in, not automatic.

---

<!-- Lessons are recorded during actual usage sessions. This template file ships empty. -->

<!--
Example lessons (invisible to `cat`, visible in editors):

## 2025-01-15
**Context**: Editing Python files
**Mistake**: Used `print()` for debugging in production code
**Rule**: Always use `logging` module instead of `print()`. Remove all `print()` before committing.

## 2025-02-03
**Context**: Running shell commands on user's machine
**Mistake**: Modified ~/.bashrc without being asked
**Rule**: Never modify shell config files (~/.bashrc, ~/.profile, ~/.zshrc) unless the user explicitly requests it. Prefer user-space alternatives.
-->
