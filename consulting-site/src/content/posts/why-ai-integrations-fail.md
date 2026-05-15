---
title: "Most AI integrations in engineering orgs fail. Here's why."
description: "Three patterns that kill AI integrations before they deliver value — and the one thing the integrations that actually work have in common."
pubDate: 2026-05-14
tags: ["AI", "engineering", "systems design", "ROI"]
---

Most AI integrations in engineering orgs fail.

Not because the model isn't good enough. Because the integration was designed wrong from the start.

I've seen this pattern repeatedly — teams spend weeks getting an LLM wired into their stack, ship it with some fanfare, and then quietly stop talking about it three months later because nobody can tell if it's helping. Here are the three failure modes I keep seeing, and what the ones that actually work have in common.

## Failure mode 1: AI bolted onto a broken process

If your alert pipeline fires 400 times a day and 390 are noise, adding an LLM to summarize them doesn't fix anything. You've automated a symptom.

The AI will dutifully summarize 390 noisy alerts per day. Engineers will learn to ignore the summaries the same way they learned to ignore the raw alerts. You've added latency and cost to a broken process.

Fix the signal first. Tune your alerting until the noise ratio is acceptable, then add intelligence on top of a meaningful signal.

This applies everywhere: an LLM can't fix a broken data pipeline by summarizing the garbage coming out of it. An AI code reviewer can't rescue a codebase that has no standards to enforce. The model is a multiplier — if the input process is broken, you get faster brokenness.

## Failure mode 2: No feedback loop

The LLM makes a call. Nobody tracks whether it was right. Six months later you have no idea if it's helping or hallucinating — and no data to improve it.

This is especially common with "summarization" features. The summary looks plausible. Nobody checks if it was accurate. The team assumes it's working because it hasn't obviously broken anything.

The feedback loop doesn't need to be complex. For alert triage, the question is: did the on-call take the recommended action? Did the incident resolve faster than average? Log it. You have your feedback loop.

Without measurement, you can't iterate. You can't know if a model upgrade helped. You can't know if your prompt is drifting. You're flying blind with a system that's influencing real decisions.

## Failure mode 3: Wrong problem selected

Teams reach for AI on problems that are hard to evaluate — "summarize this doc," "explain this error," "write a status update." They skip the problems with clear inputs and measurable outputs, which is exactly where AI delivers the most ROI.

The problems that are hardest to evaluate are also the ones where AI failure is hardest to detect. You don't know the doc summary was subtly wrong until someone acts on it. You don't know the error explanation was misleading until an engineer spent two hours in the wrong direction.

The problems worth solving with AI have three properties: well-defined input, specific expected output, and a way to verify the result. "Classify this support ticket into one of 12 categories" is evaluable. "Explain this codebase to a new engineer" is not.

## What the integrations that work have in common

Alert triage works because:
- Input is well-defined (Alertmanager webhook payload has a consistent schema)
- Output is specific (severity assessment, likely cause, recommended first step)
- Verification is possible (did the recommendation match what actually fixed it?)

Code review automation works for similar reasons. Incident summarization works. Log anomaly detection works. These are all problems where you can build a ground truth dataset and measure against it.

Before you wire an LLM into anything, answer three questions:

1. What is the exact input, and is it consistent enough to be reliable?
2. What specific output do you need — not "insights," but an actual structured result?
3. How will you verify whether the output was correct, at scale?

If you can't answer all three, you're not ready to add AI yet. Fix the process, define the output, build the measurement. Then the model almost doesn't matter.

---

If you're working through what AI actually makes sense for your stack — and what doesn't — that's exactly what I do in [discovery engagements](/services). No pitch, just an honest assessment.
