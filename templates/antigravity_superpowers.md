# Antigravity / Superpowers Integration Snippet

If your project uses **Antigravity** or the **Superpowers** workflow, add this block to your `.agent/AGENTS.md` or system prompt:

```markdown
## Claude Collaborator Workflow (Dual-Agent Mode)

**Mandatory Rule for Design & Review**: For ANY architectural design, feature planning, prompt/spec tuning, or system exploration:
- **Always proactively consult and discuss with Claude** (`claude-collaborator` skill) to cross-reference designs, explore trade-offs, and validate assumptions before finalizing plans or writing major code.
- Use `claude_design.sh` for architectural/state design, solution comparison, and deep research before writing code.
- Use `claude_refine.sh` for prompts, schemas, specs, or domain documents.
- Use `claude_review.sh` for code review and regression checking before claiming completion of critical tasks.
- If Claude hits usage limits or connection issues, seamlessly follow the self-healing fallback protocol without halting the task.
```
