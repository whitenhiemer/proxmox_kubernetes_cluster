---
title: "Fear of being replaced by AI taught me to partner with it"
description: "Twenty years into an engineering career, I started worrying AI was coming for my job. Here's what I did about it — and what I learned."
pubDate: 2026-05-16
tags: ["AI", "career", "consulting", "automation"]
---

Two years ago I started quietly worrying that AI was going to make me obsolete.

Not in a doomsday way. More like a low-grade background anxiety that showed up when I was reading about what LLMs could do — and started mentally checking off things I did at work that a model could probably handle.

I'm 20 years into infrastructure and systems engineering. Rackspace. Amazon. Salesforce GovCloud. I've built things that mattered at scale. I know this domain. And I was sitting there thinking: how much of what I do every day is pattern matching that a well-prompted model could replicate?

The honest answer was: more than I wanted to admit.

## What I did with that fear

I could have done what a lot of engineers do — dismiss it, argue about why AI can't really do X, wait to see how it plays out. That felt like a bad bet.

Instead I decided to find out exactly where the line was. Not philosophically. Concretely. What can these tools actually do? Where do they fail? What does the gap look like between "impressive demo" and "running in production"?

So I started building.

## alertmind

The first thing I built was [alertmind](https://github.com/woodhead-tech/alertmind).

I was getting paged at 2am by alerts I couldn't act on without first spending 10 minutes loading context — which runbook applies, has this fired before, is this actually critical or just noisy. That cognitive load at 2am is where mistakes happen.

I wired Claude into Alertmanager. The tool receives the webhook, enriches the alert with label context and runbook URLs, calls the Claude API for a structured triage assessment, and posts it to Discord before the on-call engineer has even opened their laptop.

I built it in a weekend. It's been running in my homelab for months, wired into a production-equivalent Prometheus stack.

Here's what I learned: the model isn't the hard part. The enrichment is. A bare alert payload is nearly useless context for an LLM. Once I started attaching structured metadata — hostname, environment, runbook URL, whether this alert has fired in the last 24 hours — the output quality jumped from "generic advice" to "actually useful."

The AI didn't replace the on-call engineer. It eliminated the first 10 minutes of cognitive overhead so the engineer could start doing real work immediately.

## ShopStack

The second thing I built was [ShopStack](https://woodhead.tech/shopstack).

I have a friend who runs a small T-shirt business. Her stack was personal Gmail, shared Google Drive mixed with family photos, and PayPal.me links. It worked until it caused problems — wrong files shared with clients, invoices chased over text message.

I offered to set it up properly. Mailcow for email at her domain. Nextcloud for file storage. Invoice Ninja with Stripe payment links. All automated — one Ansible playbook provisions the whole stack from scratch.

Total time from zero to running: 57 minutes.

I used Claude throughout the build — not to write the code for me, but to accelerate the parts where I was working in unfamiliar territory. Getting Mailcow's DKIM configuration right on the first try instead of the third. Debugging Traefik middleware ordering. Drafting the documentation.

The result wasn't "AI built it." It was "I built it faster and with fewer wrong turns because I had a capable collaborator."

## What I actually learned

The fear was directionally right, but the conclusion was wrong.

AI isn't coming for experienced engineers. It's coming for the *role* of the engineer who does repetitive, pattern-matched work without building judgment on top of it. The engineer who follows the runbook but never questions whether the runbook is right. The one who waits for someone else to define the problem.

What AI can't replicate — yet, and maybe ever — is the accumulated judgment about what's worth building in the first place. The ability to look at a system and see not just what it does but what it's going to do under load in six months. The instinct that tells you a proposed solution is elegant in the demo and a maintenance nightmare in production.

That judgment is worth more now than it was two years ago, because the execution layer is getting cheaper. An engineer with strong judgment and AI tooling punches well above their weight class.

The engineers who are actually at risk are the ones treating AI as a threat to observe rather than a tool to learn.

## What I'm doing now

I started Woodhead Tech as a consulting practice. The niche: helping engineering teams cut manual ops and integrate AI into workflows that actually run in production — not demos, not pilots.

The fear didn't go away. It turned into a forcing function. It made me actually pick up the tools and find out what they could do, instead of theorizing about it from the sidelines.

If you're an engineer sitting with that same low-grade anxiety — I'd say: good. Use it. Build something this weekend. It doesn't have to be impressive. It has to be real.

The gap between "I've been reading about AI" and "I've shipped something with AI in it" is where careers are going to diverge over the next few years.

---

If you're working through where AI actually fits in your engineering org — and where it doesn't — that's what Woodhead Tech does. [Get in touch](/contact).
