# Cursor (.cursorrules) Integration Snippet

If you use **Cursor** or **Windsurf**, paste the following into your project's `.cursorrules` or `.windsurfrules`:

```markdown
# Dual-Agent Architecture & Code Review Workflow
You have access to local Claude CLI helper scripts for peer review and architectural guidance.

- Before implementing non-trivial architecture or features:
  Run: `claude-design "<feature_or_architecture_goal>" [relevant_files...]`
- When optimizing prompts, JSON schemas, or specifications:
  Run: `claude-refine "<file_path>" "<optimization_goal>"`
- Before submitting major pull requests or marking complex tasks done:
  Run: `claude-review HEAD "<task_description>"`
```
