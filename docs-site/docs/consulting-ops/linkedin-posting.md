---
sidebar_position: 5
title: LinkedIn Posting
---

# LinkedIn Posting Runbook

Human-executable. No AI required. Covers the full posting workflow from pulling
the draft to logging it as posted.

**Cadence:** 2x per week. Tuesday and Friday, 8–10am local time.
**Schedule:** `~/WOODHEAD_CONSULTING/linkedin/schedule.md`
**Posts:** `~/WOODHEAD_CONSULTING/linkedin/posts/`

---

## Step 1 — Find What to Post

Open `linkedin/schedule.md`. Find the first unposted item in the Queue section
(no ✅ next to it).

Check the target day — Tuesday or Friday. Post within that day's window (8–10am).
If you missed the window, post the next business morning. Don't skip — just post it.

Upcoming queue (as of 2026-05-16):
- **Post 11** — `11-fear-of-ai-partner.md` — Tuesday, broad reach. Post this one first.
- **Post 04** — `04-platform-vs-product-ai.md` — Friday, engineering ICP
- **Post 05** — `05-amazon-outage-lessons.md` — Tuesday
- Continue through the queue in order

---

## Step 2 — Prepare the Post Text

Open the post file from `linkedin/posts/`. The content below the `---` divider is
the post body. Everything above (Type, Target, Anchor) is metadata — do not post it.

**Formatting for LinkedIn:**

- LinkedIn ignores Markdown. No bold, no headers, no bullet syntax renders.
- Line breaks are real line breaks — paste as-is and they'll show.
- URLs paste as plain text but LinkedIn will generate a preview card from the anchor link.
- The closing question (last line of every post) should always be its own paragraph.

**Character limit:** 3,000 characters. All current posts are well under this.

**One quick check before posting:**
- Does the anchor URL in the post still resolve? Open it in a browser.
- Is the closing question still relevant / not dated?

No edits needed for most posts — they're written ready to go.

---

## Step 3 — Post on LinkedIn

1. Go to linkedin.com → click "Start a post" at the top of the feed
2. Paste the post body (below the `---` in the post file)
3. Do NOT attach an image unless the post file notes one
4. Do NOT add hashtags — they're not included in these posts by design
5. Set audience: **Anyone** (not "Connections only")
6. Click **Post**

Copy the post URL immediately after it publishes:
- Click on the post timestamp (e.g., "Just now") → copy the URL from the browser bar
- URL format: `https://www.linkedin.com/posts/...`

---

## Step 4 — Engage for the First 60 Minutes

LinkedIn's algorithm weights early engagement heavily. The first hour after posting
determines reach. Stay near your phone or computer.

**What to do:**

1. Reply to every comment within the first 60 minutes — even a short reply counts
2. If someone asks a question: answer it directly and add one sentence of context
3. If someone shares their own experience: acknowledge it specifically, not generically
4. Do not reply with just "Thanks!" — add something real

**Engagement goal:** at least 3 meaningful comment exchanges in the first hour.

**What not to do:**

- Don't ask friends or family to like/comment (looks inauthentic to the algorithm and your ICP)
- Don't edit the post after publishing (resets distribution)
- Don't delete and repost if it's underperforming — just learn and move on

**If a comment is a potential lead:**

If someone describes a real problem that matches your offer, reply with substance
and then send them a DM:
> "Saw your comment on the post — sounds like you might be dealing with exactly
> this. Happy to dig into it if useful. No pitch, just a conversation."

Then follow the inbound lead response runbook: [Inbound Lead Response](./inbound-lead-response)

---

## Step 5 — Log It as Posted

Open `linkedin/schedule.md`. Mark the post as posted:

1. Move it from the Queue section to the Posted section (or add ✅ next to it)
2. Add the post URL next to the entry
3. Note the date posted

Example entry after posting:
```
**Post 11 — Tue 2026-05-19** `posts/11-fear-of-ai-partner.md` ✅ POSTED
URL: https://www.linkedin.com/posts/brandon-woodward-...
```

---

## Step 6 — 48-Hour Check (optional but useful)

Two days after posting, check impressions and comments:

- Click the post → "X impressions" below it → note the number
- Log it in the Metrics section of `schedule.md` if tracking

**Rough benchmarks (early stage, under 500 followers):**

| Result | What it means |
|--------|---------------|
| Under 200 impressions | Low reach — hook may not be landing, or low engagement in first hour |
| 200–500 impressions | Normal for a new account |
| 500–1,000 impressions | Good — content is resonating |
| 1,000+ impressions | Strong — consider a follow-up post or repurpose to blog |

Don't chase impressions in the first 60 days. Consistency matters more than any
single post's performance.

---

## SMB Posts (ShopStack audience)

Posts marked "SMB audience" in the schedule (`03-shopstack-announcement.md`,
`04-tshirt-case-study.md`) should also be shared in Facebook groups after posting
on LinkedIn. See [Facebook Content](./facebook-content).

These posts don't end with a question for engineers — adjust the closing line if
it reads too technical for the Facebook audience.

---

## When You've Run Out of Queued Posts

All 11 posts will eventually be posted. When the queue is empty:

1. Check the "Post Ideas — Not Yet Written" section at the bottom of `schedule.md`
2. Write the next post using a post from that list as the starting point
3. Or: take a recent client interaction / lesson learned and write a new post from it

**Post structure that works (based on the existing queue):**
- Line 1: Hook — one punchy sentence, specific claim or contrarian take
- Lines 2–4: Setup the tension or context
- Lines 5–8: The insight or story
- Lines 9–12: The takeaway — what this means practically
- Last line: A direct question to the reader

Keep it under 300 words. Shorter posts get more reads.

---

## Quick Reference

| What | Where |
|------|-------|
| Schedule | `linkedin/schedule.md` |
| Post files | `linkedin/posts/` |
| Next post | Post 11 (Tuesday), Post 04 (Friday) |
| Posting time | 8–10am local |
| Audience setting | Anyone |
| First-hour goal | 3+ comment exchanges |
| Log after posting | Add ✅ + URL + date to schedule.md |
