# Claude Code (CLAUDE.md) Integration Snippet

If you use **Claude Code CLI** as your primary driver, add this to your project's `CLAUDE.md`:

```markdown
## Peer Review & Design Tools
This project integrates automated multi-model helpers located at `~/.local/bin` or `.agent/skills/agent-collaborator/scripts/`:
- `claude-brainstorm [--model <model>] "<requirement>" [files...]` - Divergent ideation & approach trade-offs
- `codex-brainstorm [--model <model>] "<requirement>" [files...]` - Engineering feasibility & contrarian perspective (Codex)
- `claude-design [--model <model>] "<requirement>" [files...]` - Deep architectural design pass
- `claude-refine [--model <model>] "<file>" "<goal>"` - Spec & prompt optimization
- `claude-review [--model <model>] [BASE_REF] "<task>"` - Pre-flight git diff code review
- `codex-optimize [--model <model>] "<task>" [files...]` - Algorithmic/performance analysis & terminal/CI automation (Codex)
*(All tools support `--model <name>` / `-m <name>` or env vars `CLAUDE_MODEL`, `CODEX_MODEL`, `AGENT_MODEL`)*
```

Codex also has a genuine **Computer Use** strength — driving a real GUI (browser, Figma, Xcode, Slack) by seeing the screen and controlling the mouse/keyboard — but only through the Codex desktop/ChatGPT app, not this headless CLI. Route tasks that truly need visual/GUI verification there instead of expecting `codex-optimize` to do it.
