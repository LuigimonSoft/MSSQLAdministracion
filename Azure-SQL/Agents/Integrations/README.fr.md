# Intégrations de l’agent DBA

[English](README.md) · [Español](README.es.md)

Ces modèles sont à installer ; ils ne sont pas automatiquement enregistrés comme agents depuis ce dossier. Chaque profil contient le prompt canonique complet et les instructions propres à sa plateforme. Le SQL est conservé exactement et le modèle hérite de la configuration utilisateur.

| Plateforme | English | Español | Français | Dossier d’installation dans le projet cible |
|---|---|---|---|---|
| GitHub Copilot (VS Code) | [Profil](Copilot/azure-sql-dba-en.agent.md) | [Profil](Copilot/es/azure-sql-dba-es.agent.md) | [Profil](Copilot/fr/azure-sql-dba-fr.agent.md) | `.github/agents/` |
| Codex | [Profil](Codex/azure-sql-dba-en.toml) | [Profil](Codex/es/azure-sql-dba-es.toml) | [Profil](Codex/fr/azure-sql-dba-fr.toml) | `.codex/agents/` |
| Claude Code | [Profil](Claude/azure-sql-dba-en.md) | [Profil](Claude/es/azure-sql-dba-es.md) | [Profil](Claude/fr/azure-sql-dba-fr.md) | `.claude/agents/` |

Copier le fichier choisi directement dans son dossier d’installation en conservant son nom. Installer une langue ou les trois. Aucune modification de configuration globale n’est nécessaire. La prise en charge varie selon la version : utiliser un client compatible avec le format documenté.

## GitHub Copilot

Le fichier `.agent.md` utilise un en-tête YAML avec `name`, `description`, `tools` et `target: vscode`. Après copie, ouvrir le projet dans VS Code et sélectionner `azure-sql-dba-fr` (ou `-en`/`-es`) dans le sélecteur d’agents du chat. Les outils permettent lecture, recherche et consultation web, sans shell, modification de fichiers ni connecteur MCP de base de données. Ce modèle cible VS Code sans présumer un comportement identique dans l’agent cloud.

## Codex

Le fichier TOML définit `name`, `description` et `developer_instructions`. Le placer dans `.codex/agents/`, rouvrir la session si nécessaire et demander explicitement à Codex d’utiliser `azure-sql-dba-fr` pour analyser la procédure fournie. Il s’agit d’un sous-agent personnalisé : la conversation principale transmet les demandes diagnostiques à l’utilisateur puis poursuit avec les résultats aux tours suivants. Pour un dialogue direct, utiliser le [prompt français canonique](../fr/AgentDBAProcedureStockee.md) comme instructions du chat.

Le profil désactive shell, apps, plugins, mémoires et skills intégrées via les options documentées. **Codex hérite du sandbox, des autorisations et des serveurs MCP de la session principale** : ces options ne créent ni sandbox indépendant en lecture seule ni liste exhaustive d’outils autorisés. Configurer la session principale en lecture seule et sans serveurs MCP de base de données. Ne pas ajouter `sandbox_mode` ou `approval_policy` au profil en pensant remplacer ceux de la session principale.

## Claude Code

Le Markdown utilise l’en-tête propre à Claude et une liste d’outils de lecture, recherche et web. Après installation, démarrer l’agent comme conversation principale interactive :

```sh
claude --agent azure-sql-dba-fr
```

Utiliser `azure-sql-dba-en` ou `azure-sql-dba-es` pour les autres langues. Démarrer une nouvelle session si le nouveau dossier n’est pas détecté. Comme sous-agent, il renvoie les demandes diagnostiques à la conversation principale sans simuler une attente de réponses utilisateur en arrière-plan. Il ne dispose pas d’outils Bash, de modification de fichiers, Agent ou MCP de base de données.

## Synchronisation des modèles

Modifier les prompts canoniques dans `Agents/`, `Agents/es/` ou `Agents/fr/`, puis exécuter depuis la racine du dépôt :

```sh
python3 Azure-SQL/Agents/Integrations/generate_profiles.py
```

Le générateur remplace les neuf modèles de ce dossier, pas les copies installées. Recopier les profils actualisés dans les dossiers d’installation. Il ne modifie pas le SQL et n’exécute aucune requête. Valider le format et le contenu ne remplace pas un essai de découverte et de fonctionnement dans chaque client.

## Sources officielles

- [Configuration des agents GitHub Copilot](https://docs.github.com/en/copilot/reference/custom-agents-configuration).
- [Sous-agents personnalisés Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).
- [Sous-agents personnalisés Claude Code](https://code.claude.com/docs/en/sub-agents).
