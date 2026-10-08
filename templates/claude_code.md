# Claude Code (CLAUDE.md) Integration Snippet

If you use **Claude Code CLI** as your primary driver, add this to your project's `CLAUDE.md`:

```markdown
## Peer Review & Design Tools
This project integrates automated multi-model helpers located at `~/.local/bin` or `.agent/skills/agent-collaborator/scripts/`:
- `claude-brainstorm [--model <model>] [-c] "<requirement>" [files...]` - Divergent ideation & approach trade-offs
- `codex-brainstorm [--model <model>] [-c] "<requirement>" [files...]` - Engineering feasibility & contrarian perspective (Codex)
- `claude-design [--model <model>] [-c] "<requirement>" [files...]` - Deep architectural design pass
- `claude-refine [--model <model>] [-c] "<file>" "<goal>" [ref_files...]` - Spec & prompt optimization
- `claude-review [--model <model>] [-c] [BASE_REF] "<task>"` - Pre-flight git diff code review
- `claude-followup [--model <model>] "<prompt>" [files...]` - Multi-turn session continuation (Claude)
- `codex-followup [--model <model>] "<prompt>" [files...]` - Multi-turn session continuation (Codex)
- `codex-optimize [--model <model>] [-c] "<task>" [files...]` - Algorithmic/performance analysis & terminal/CI automation (Codex)
*(All tools support `--model <name>` / `-m <name>` or env vars `CLAUDE_MODEL`, `CODEX_MODEL`, `AGENT_MODEL`, and `-c|--continue` for session continuation)*
```

Codex also has a genuine **Computer Use** strength — driving a real GUI (browser, Figma, Xcode, Slack) by seeing the screen and controlling the mouse/keyboard — but only through the Codex desktop/ChatGPT app, not this headless CLI. Route tasks that truly need visual/GUI verification there instead of expecting `codex-optimize` to do it.
