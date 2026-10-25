# DBA agent integrations

[Español](README.es.md) · [Français](README.fr.md)

These are installable templates, not automatically registered agents. Each profile embeds the complete canonical prompt plus platform instructions. The SQL is preserved exactly; models are inherited from your settings.

| Platform | English | Español | Français | Installation directory in the destination project |
|---|---|---|---|---|
| GitHub Copilot (VS Code) | [Profile](Copilot/azure-sql-dba-en.agent.md) | [Perfil](Copilot/es/azure-sql-dba-es.agent.md) | [Profil](Copilot/fr/azure-sql-dba-fr.agent.md) | `.github/agents/` |
| Codex | [Profile](Codex/azure-sql-dba-en.toml) | [Perfil](Codex/es/azure-sql-dba-es.toml) | [Profil](Codex/fr/azure-sql-dba-fr.toml) | `.codex/agents/` |
| Claude Code | [Profile](Claude/azure-sql-dba-en.md) | [Perfil](Claude/es/azure-sql-dba-es.md) | [Profil](Claude/fr/azure-sql-dba-fr.md) | `.claude/agents/` |

Copy the selected file directly into the destination directory, keeping its filename. You can install one language or all three. No changes to global user configuration are needed. Client support can vary by version; use a release supporting the linked configuration format.

## GitHub Copilot

The `.agent.md` file uses YAML frontmatter with `name`, `description`, `tools` and `target: vscode`. After copying it, open the workspace in VS Code and select `azure-sql-dba-en` (or `-es`/`-fr`) from the chat agent selector. The tools list permits file reading, searching and web research, without shell execution, file editing or database MCP tools. This template targets VS Code rather than claiming identical cloud-agent behavior.

## Codex

The TOML file defines `name`, `description` and `developer_instructions`. Place it in `.codex/agents/`, reopen the session if needed, and explicitly ask Codex to use `azure-sql-dba-en` to analyze the supplied procedure. This is a custom subagent; the parent chat receives requests for user-run diagnostics and relays them to the user across successive turns. For a direct interactive conversation, use the [canonical English prompt](../StoredProcedureDBAAgent.md) as the chat instructions instead.

The profile disables shell, apps, plugins, memories and bundled skills through documented settings. **Codex inherits the parent sandbox, permissions and MCP servers**: these settings do not establish an independent read-only sandbox or a complete tool allowlist. Configure the parent session with read-only permissions and without database MCP servers. Do not put `sandbox_mode` or `approval_policy` in the agent profile expecting them to override the parent session.

## Claude Code

The Markdown file uses Claude's frontmatter and a read/search/web tool allowlist. After installation, start the interactive agent as the main conversation:

```sh
claude --agent azure-sql-dba-en
```

Use `azure-sql-dba-es` or `azure-sql-dba-fr` for the other languages. Start a new session if the new agent directory is not detected. If delegated as a subagent instead, it returns diagnostic requests to the main conversation; it does not pretend to wait for user input in a background task. The profile grants no Bash, file editing, Agent or database MCP tools.

## Synchronizing the templates

Edit the canonical prompts in `Agents/`, `Agents/es/` or `Agents/fr/`, then run from the repository root:

```sh
python3 Azure-SQL/Agents/Integrations/generate_profiles.py
```

The generator overwrites the nine generated templates here, not installed copies. Copy updated profiles to the client installation directories again. It does not modify SQL or run database queries. Schema and content checks are separate from testing discovery and execution in each client.

## Official sources

- [GitHub Copilot custom agent configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration).
- [Codex custom subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents).
- [Claude Code custom subagents](https://code.claude.com/docs/en/sub-agents).
