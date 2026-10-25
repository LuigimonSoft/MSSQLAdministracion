# Integraciones del agente DBA

[English](README.md) · [Français](README.fr.md)

Son plantillas instalables; no se registran automáticamente como agentes desde esta carpeta. Cada perfil incorpora el prompt canónico completo y las instrucciones de su plataforma. El SQL se conserva exactamente y el modelo se hereda de la configuración del usuario.

| Plataforma | English | Español | Français | Carpeta de instalación en el proyecto de destino |
|---|---|---|---|---|
| GitHub Copilot (VS Code) | [Perfil](Copilot/azure-sql-dba-en.agent.md) | [Perfil](Copilot/es/azure-sql-dba-es.agent.md) | [Perfil](Copilot/fr/azure-sql-dba-fr.agent.md) | `.github/agents/` |
| Codex | [Perfil](Codex/azure-sql-dba-en.toml) | [Perfil](Codex/es/azure-sql-dba-es.toml) | [Perfil](Codex/fr/azure-sql-dba-fr.toml) | `.codex/agents/` |
| Claude Code | [Perfil](Claude/azure-sql-dba-en.md) | [Perfil](Claude/es/azure-sql-dba-es.md) | [Perfil](Claude/fr/azure-sql-dba-fr.md) | `.claude/agents/` |

Copia el archivo elegido directamente a su carpeta de instalación, conservando el nombre. Puedes instalar uno o los tres idiomas. No se necesita modificar la configuración global. El soporte puede variar por versión: utiliza un cliente compatible con el formato documentado.

## GitHub Copilot

El archivo `.agent.md` utiliza cabecera YAML con `name`, `description`, `tools` y `target: vscode`. Después de copiarlo, abre el proyecto en VS Code y selecciona `azure-sql-dba-es` (o `-en`/`-fr`) en el selector de agentes del chat. Las herramientas permiten leer archivos, buscar e investigar en la web; no incluyen ejecución de shell, edición de archivos ni conectores MCP de bases de datos. La plantilla está dirigida a VS Code, sin asumir un comportamiento idéntico en el agente cloud.

## Codex

El archivo TOML define `name`, `description` y `developer_instructions`. Colócalo en `.codex/agents/`, vuelve a abrir la sesión si hace falta y pide explícitamente a Codex que utilice `azure-sql-dba-es` para analizar el procedimiento aportado. Es un subagente personalizado: el chat principal recibe las solicitudes de diagnóstico, las comunica al usuario y continúa con los resultados en turnos posteriores. Para un diálogo directo, utiliza el [prompt español canónico](../es/AgenteDBAStoredProcedure.md) como instrucciones del chat.

El perfil desactiva shell, apps, plugins, memorias y skills incluidas mediante opciones documentadas. **Codex hereda el sandbox, los permisos y los servidores MCP de la sesión principal**: estas opciones no establecen un sandbox independiente de solo lectura ni una lista exhaustiva de herramientas permitidas. Configura la sesión principal con permisos de solo lectura y sin servidores MCP de bases de datos. No añadas `sandbox_mode` o `approval_policy` al perfil esperando que sustituyan los de la sesión principal.

## Claude Code

El Markdown utiliza la cabecera propia de Claude y una lista de herramientas de lectura, búsqueda y web. Después de instalarlo, inicia el agente como conversación principal interactiva:

```sh
claude --agent azure-sql-dba-es
```

Utiliza `azure-sql-dba-en` o `azure-sql-dba-fr` para los otros idiomas. Abre una sesión nueva si no se detecta la carpeta recién creada. Si se invoca como subagente, devuelve las solicitudes diagnósticas al chat principal; no simula esperar respuestas del usuario en segundo plano. No dispone de herramientas Bash, edición de archivos, Agent ni MCP de bases de datos.

## Sincronización de plantillas

Edita los prompts canónicos en `Agents/`, `Agents/es/` o `Agents/fr/` y ejecuta desde la raíz del repositorio:

```sh
python3 Azure-SQL/Agents/Integrations/generate_profiles.py
```

El generador sobrescribe las nueve plantillas de esta carpeta, no las copias instaladas. Copia de nuevo los perfiles actualizados a las carpetas de instalación. No modifica SQL ni ejecuta consultas. Validar formato y contenido no sustituye probar el descubrimiento y funcionamiento en cada cliente.

## Fuentes oficiales

- [Configuración de agentes de GitHub Copilot](https://docs.github.com/en/copilot/reference/custom-agents-configuration).
- [Subagentes personalizados de Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).
- [Subagentes personalizados de Claude Code](https://code.claude.com/docs/en/sub-agents).
