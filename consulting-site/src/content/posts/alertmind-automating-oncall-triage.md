---
title: "I automated the first 10 minutes of every on-call response"
description: "How I built alertmind — an AI-powered alert triage tool in Go that reduces on-call cognitive load by posting structured triage summaries before the engineer even opens their laptop."
pubDate: 2026-05-14
tags: ["on-call", "AI", "Go", "alertmind", "observability"]
---

I got paged at 2am one too many times. So I automated the first 10 minutes of every on-call response.

## The real problem with on-call

The problem isn't that alerts fire at 2am. That's expected. The problem is what happens next.

You're half asleep. You open Slack. You're staring at a wall of labels — `severity=critical`, `job=api-server`, `instance=10.0.1.42:8080` — trying to remember which runbook applies, whether this has fired before, and whether it's actually critical or just the same noisy alert from last Tuesday.

That cognitive load is where mistakes happen. You either spiral into a rabbit hole that doesn't matter, or you dismiss something you shouldn't have.

The first 10 minutes of an incident are the most expensive. You're context-switching from sleep, you have no mental model loaded, and the clock is ticking.

## What I built

[alertmind](https://github.com/woodhead-tech/alertmind) sits between Alertmanager and your Slack. When an alert fires, it:

1. Receives the webhook payload from Alertmanager
2. Enriches the alert with additional context (runbook URLs, label summaries)
3. Calls the Claude API with a structured prompt asking for a triage analysis
4. Posts a formatted summary to Slack or Discord before you've even unlocked your phone

The on-call engineer wakes up to something like:

> **Severity:** Critical  
> **Likely cause:** API server OOM — memory usage has been climbing for 6 hours, likely a leak in the request handler introduced in the last deploy.  
> **Recommended first step:** Check recent deploys, then `kubectl top pods -n api` to confirm memory pressure. Rollback to previous image if confirmed.

Instead of a raw JSON payload.

## Why Go, why Claude

Go because the entire thing is a lightweight HTTP server. No runtime dependencies, compiles to a single binary, easy to deploy anywhere. The binary is under 15MB.

Claude because the structured output quality is genuinely better than alternatives for this use case — I'm asking it to reason about system state and produce a specific JSON schema, not generate prose. `claude-haiku-4-5` is fast enough that the triage summary arrives before you've had time to read the original alert.

## Architecture

```
Alertmanager → POST /webhook → alertmind → Claude API
                                         → Slack (Block Kit)
                                         → Discord (embeds)
```

The `internal/enricher` package builds the LLM prompt from the alert payload. It injects label context, runbook URLs if configured, and recent alert history if the same alert has fired before.

The `internal/llm` package makes a direct HTTP call to the Anthropic Messages API — no SDK, just `net/http`. Keeps the dependency surface minimal.

## What it cost to build

A weekend. Seriously. The core webhook receiver and Claude integration took about 4 hours. The Slack Block Kit formatting took another 2 because their API is fussy. The test suite and Docker packaging took most of Saturday.

It's been running in my homelab for months, wired into a production-equivalent Prometheus + Alertmanager stack. The Discord notifications work. The triage quality is high enough that I've caught things I would have missed at 2am.

## The repo

It's open source: [github.com/woodhead-tech/alertmind](https://github.com/woodhead-tech/alertmind)

Copy-paste Alertmanager config is in the README. Should take under an hour to get running if you already have Alertmanager.

If you're running an engineering team and want this wired into your stack without the setup overhead — that's the kind of thing I help with. [Get in touch](/contact).
