---
sidebar_position: 10
title: Claude OS
---

# Claude OS

LXC 215 | `192.168.86.37` | Port 8051 (API), 5173 (Frontend) | [claude-os.woodhead.tech](https://claude-os.woodhead.tech)

AI memory and knowledge system for Claude Code. Provides an MCP server that persists session context, task history, and project knowledge across Claude Code sessions via a FastAPI backend and Redis-backed RQ workers.

## Architecture

- **MCP/API server** (`claude-os-api.service`): FastAPI on port 8051, exposes MCP tools and REST endpoints
- **RQ workers** (`claude-os-workers.service`): Background workers for real-time learning queues (`claude-os:learning`, `claude-os:prompts`, `claude-os:ingest`)
- **React frontend** (`claude-os-frontend.service`): Vite dev server on port 5173, proxied via Traefik
- **Redis**: Local Redis instance used as the RQ broker
- **SQLite**: Persistent store at `/opt/claude-os/data/claude-os.db`
- **Python venv**: `/opt/claude-os/venv` (FastAPI, RQ, httpx, etc.)
- **MCP client**: Runs locally on the dev machine (`/home/bwoodwar/claude-os/mcp_server/claude_code_mcp.py`), stdio process that proxies to the remote API

```
Claude Code (local)
    |
    v
claude_code_mcp.py (stdio, local venv)
    |  CLAUDE_OS_API=http://192.168.86.37:8051
    v
claude-os-api (FastAPI, LXC 215)
    |
    +---> Redis -> RQ Workers (background learning)
    |
    +---> SQLite (persistent knowledge store)
```

## Deploy

```bash
# Provision the LXC
make apply-lxc

# Deploy Claude OS (with OpenAI)
make claude-os OPENAI_API_KEY=sk-...

# Deploy with local Ollama inference (CPU-only, slow)
make claude-os INSTALL_OLLAMA=true

# Deploy with both
make claude-os OPENAI_API_KEY=sk-... INSTALL_OLLAMA=true
```

## MCP Configuration

The MCP server runs locally as a stdio process and proxies to the remote API. Register it once with Claude Code:

```bash
claude mcp add code-forge \
  -e CLAUDE_OS_API=http://192.168.86.37:8051 \
  -s user \
  -- /home/bwoodwar/claude-os/venv/bin/python3 \
     /home/bwoodwar/claude-os/mcp_server/claude_code_mcp.py
```

The local venv only needs `mcp` and `httpx` (not the full `requirements.txt`).

## Verify

```bash
# API health
curl http://192.168.86.37:8051/docs

# Service status
ssh root@192.168.86.37 'systemctl status claude-os-api claude-os-workers claude-os-frontend'

# Logs
ssh root@192.168.86.37 'journalctl -u claude-os-api -f'
ssh root@192.168.86.37 'journalctl -u claude-os-workers -f'
```

## Troubleshooting

- **API unreachable**: Check `claude-os-api.service` status; Redis must be running (`systemctl status redis-server`)
- **MCP not available in Claude Code**: Verify the registration with `claude mcp list`; check `CLAUDE_OS_API` env var is set
- **Workers not processing**: Check RQ queues via the API or `journalctl -u claude-os-workers`
- **Git pull fails on re-deploy**: Safe directory config is handled in the playbook; re-running `make claude-os` will pull latest
