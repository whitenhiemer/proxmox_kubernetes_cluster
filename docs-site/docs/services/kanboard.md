---
sidebar_position: 9
title: Kanboard / ClawBot
---

# Kanboard / ClawBot

LXC 211 | `192.168.86.33` | Port 8000 | [tasks.woodhead.tech](https://tasks.woodhead.tech)

Self-hosted Kanboard instance for async task delegation to ClawBot, a Claude Code agent that processes tasks from the board overnight.

## Architecture

- Kanboard runs as an official Docker image (PHP + SQLite) on a Debian LXC
- ClawBot is a Python agent running on macOS via `launchd`, polling the Kanboard JSON-RPC API every 5 minutes
- Tasks flow through four columns: **Backlog** -> **In Progress** -> **Review** -> **Done**
- ClawBot executes tasks via `claude -p --dangerously-skip-permissions` with a per-task budget cap
- Results are posted back as Kanboard comments and Discord notifications

```
You (create task)
    |
    v
Kanboard (tasks.woodhead.tech)
    |  Backlog column (FIFO)
    v
ClawBot (polls JSON-RPC API)
    |  Moves to In Progress
    v
Claude Code CLI (executes task)
    |
    +---> Kanboard (comment with result, move to Review)
    +---> Discord (webhook notification with PR link)
    +---> GitHub (PR via woodhead-tech account)
```

## Task Format

Create a task in the **Backlog** column of the ClawBot project. The description uses this format:

```
repo: <repo-name>
path: optional/specific-file.py
branch: optional-branch-name
---
Free-form instructions for Claude to execute.
```

- `repo` resolves to `~/WORKSPACE/<repo>` on the ClawBot host
- `path` and `branch` are optional header fields
- Everything after `---` is the prompt sent to Claude CLI
- If you skip the `---` separator, the entire description is treated as instructions

### Example Task

**Title:** Add retry logic to API client

**Description:**
```
repo: clawbot
path: kanboard.py
---
Add exponential backoff retry logic to the JSON-RPC call method.
Retry up to 3 times on ConnectionError or Timeout with 1s, 2s, 4s delays.
Include logging for each retry attempt.
```

## Deploy

Kanboard is deployed via Terraform + Ansible:

```bash
# Provision the LXC
make plan-lxc   # review
make apply-lxc  # create LXC 211

# Deploy Kanboard
make kanboard   # runs ansible/playbooks/setup-kanboard.yml
```

ClawBot runs as a macOS `launchd` agent on the development machine:

```bash
# Start/restart ClawBot
launchctl unload ~/Library/LaunchAgents/com.woodhead.clawbot.plist
launchctl load ~/Library/LaunchAgents/com.woodhead.clawbot.plist

# Check status
launchctl list | grep clawbot

# View logs
tail -f ~/WORKSPACE/clawbot/logs/clawbot.log

# Run health check
cd ~/WORKSPACE/clawbot && python health.py
```

## Configuration

ClawBot reads credentials from `~/PROJECT_PLANS/kanboard/credentials.env` (sourced by `run.sh`):

| Variable | Purpose |
|----------|---------|
| `KANBOARD_API_URL` | JSON-RPC endpoint (`http://192.168.86.33:8000/jsonrpc.php`) |
| `KANBOARD_CLAWBOT_USER` | Kanboard service account username |
| `KANBOARD_CLAWBOT_API_TOKEN` | Kanboard API token for authentication |
| `KANBOARD_PROJECT_ID` | Project ID (default: `1`) |
| `GITHUB_TOKEN` | GitHub classic PAT for pushing code and creating PRs |
| `GITHUB_USER` | GitHub account (`woodhead-tech`) |
| `CLAWBOT_DISCORD_WEBHOOK` | Discord webhook URL for task notifications |
| `CLAWBOT_MAX_BUDGET_USD` | Per-task token budget cap (default: `$5.00`) |
| `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` | Git identity for commits (`ClawBot` / `clawbot-0@woodhead.tech`) |

## GitHub Integration

ClawBot uses a dedicated GitHub account (`woodhead-tech`) with a classic PAT (repo scope). Fine-grained PATs cannot access collaborator repos, so a classic token is required.

PRs are created under the `woodhead-tech` account and linked in Discord notifications for review.

## Column IDs

| Column      | ID | Description |
|-------------|----|-------------|
| Backlog     | 1  | Queue of tasks waiting to be processed (FIFO) |
| In Progress | 2  | Currently being executed by ClawBot |
| Review      | 3  | Completed or failed, awaiting human review |
| Done        | 4  | Approved and closed |

## Verify

```bash
# Check Kanboard is reachable
curl -s https://tasks.woodhead.tech | head -1

# Check ClawBot is running
launchctl list | grep clawbot

# Check ClawBot logs
tail -5 ~/WORKSPACE/clawbot/logs/clawbot.log

# Run pre-flight health check
cd ~/WORKSPACE/clawbot && python health.py
```

## Troubleshooting

- **ClawBot can't find `claude` binary**: The `executor.py` checks `~/.local/bin/claude` first to avoid the `cmux` wrapper under launchd's stripped PATH.
- **GitHub push fails**: Verify the classic PAT in `credentials.env` has `repo` scope and the `woodhead-tech` account is a collaborator on the target repo.
- **Task stuck in In Progress**: Check `~/WORKSPACE/clawbot/logs/clawbot.log` for errors. The 10-minute timeout per task will kill hung Claude processes.
- **No Discord notification**: Verify `CLAWBOT_DISCORD_WEBHOOK` is set in `credentials.env` and ClawBot was restarted after changes.

## Version History

| Version | Changes |
|---------|---------|
| v0.2.0  | Added Discord PR links, per-task budget cap, health check utility |
