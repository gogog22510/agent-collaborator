# Cursor (.cursorrules) Integration Snippet

If you use **Cursor** or **Windsurf**, paste the following into your project's `.cursorrules` or `.windsurfrules`:

```markdown
# Dual-Agent Architecture & Code Review Workflow
You have access to local Claude CLI helper scripts for peer review and architectural guidance.

- When exploring ideas or comparing design approaches:
  Run: `claude-brainstorm "<requirement>" [relevant_files...]`
- When evaluating pragmatic engineering feasibility or standard library alternatives:
  Run: `codex-brainstorm "<requirement>" [relevant_files...]`
- Before implementing non-trivial architecture or features:
  Run: `claude-design "<feature_or_architecture_goal>" [relevant_files...]`
- When optimizing prompts, JSON schemas, or specifications:
  Run: `claude-refine "<file_path>" "<optimization_goal>"`
- Before submitting major pull requests or marking complex tasks done:
  Run: `claude-review HEAD "<task_description>"`
- When the task is algorithmic/performance-hotspot analysis, or heavy shell/CI/terminal automation:
  Run: `codex-optimize "<task_or_requirement>" [relevant_files...]`
```
