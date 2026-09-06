# Claude Code (CLAUDE.md) Integration Snippet

If you use **Claude Code CLI** as your primary driver, add this to your project's `CLAUDE.md`:

```markdown
## Peer Review & Design Tools
This project integrates automated multi-model helpers located at `~/.local/bin` or `.agent/skills/agent-collaborator/scripts/`:
- `claude-brainstorm "<requirement>" [files...]` - Divergent ideation & approach trade-offs
- `codex-brainstorm "<requirement>" [files...]` - Engineering feasibility & contrarian perspective (Codex)
- `claude-design "<requirement>" [files...]` - Deep architectural design pass
- `claude-refine "<file>" "<goal>"` - Spec & prompt optimization
- `claude-review [BASE_REF] "<task>"` - Pre-flight git diff code review
- `codex-optimize "<task>" [files...]` - Algorithmic/performance analysis & terminal/CI automation (Codex)
```

Codex also has a genuine **Computer Use** strength — driving a real GUI (browser, Figma, Xcode, Slack) by seeing the screen and controlling the mouse/keyboard — but only through the Codex desktop/ChatGPT app, not this headless CLI. Route tasks that truly need visual/GUI verification there instead of expecting `codex-optimize` to do it.
