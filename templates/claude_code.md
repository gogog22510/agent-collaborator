# Claude Code (CLAUDE.md) Integration Snippet

If you use **Claude Code CLI** as your primary driver, add this to your project's `CLAUDE.md`:

```markdown
## Peer Review & Design Tools
This project integrates automated multi-model helpers located at `~/.local/bin` or `.agent/skills/claude-collaborator/scripts/`:
- `claude-design "<requirement>" [files...]` - Deep architectural design pass
- `claude-refine "<file>" "<goal>"` - Spec & prompt optimization
- `claude-review [BASE_REF] "<task>"` - Pre-flight git diff code review
```
