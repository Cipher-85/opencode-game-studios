---
name: handoff
description: Use when the user wants to pause, stop, checkpoint, or resume later.
---

# Handoff

Review only the current working-tree diff, then commit and push automatically.
Use a fresh same-session reasoning pass, not an independent reviewer.
Resume the reviewer with its prior history via task_id: "prev" so it inherits the author's conversation.
If the reviewer is unavailable, continue with a same-session review.
