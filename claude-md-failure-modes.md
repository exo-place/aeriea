# CLAUDE.md failure modes

Notes for a future session redesigning the scaffolding CLAUDE.md and its forks.
Not a prescription. Not a draft of a replacement. A record of what's broken so the
next attempt doesn't start from zero.

## Observed failure modes

- Delegated implementation 3+ times in a single session on uncertain specs. Each
  delegation ended in a "premise wrong, stopped" report after the agent burned
  quota proving the prompt's assumptions were broken.
- Reactive CLAUDE.md additions accreted across multiple sessions, producing
  contradictory rules and a file too large to internalize.
- The model treated CLAUDE.md as scripture: when its behavior conflicted with the
  user's intent, it blamed itself for not following the rules harder, rather than
  diagnosing the artifact as broken.
- The model generated material reactively to every prompt — including prompts
  that were tests of judgment where "I don't know" or stopping was correct.

## Mechanisms in the current rules that produce those failures

- **"When in doubt, delegate."** Launders uncertainty into committed work. The
  agent inherits the prompt as ground truth; whatever uncertainty the orchestrator
  had is gone by the time the agent starts. This rule directly caused the
  premise-wrong loop.
- **"Corrections mean a rule is missing or wrong. Write it before proceeding."**
  Guarantees monotonic file growth. Every correction adds a rule, the file gets
  longer, harder to internalize, more self-contradictory. Encodes the bandaid
  pattern as a rule.
- **"Edits you're committing to stay inline."** Context poisoning through
  read+reason+iterate cycles. By the time you've read enough to make the edit,
  the damage is done. The "I'm committing to this" framing is just delegation
  laundering with extra steps.
- **"Don't hedge" combined with "confident assertions require proof of work."**
  Produces fake confidence in practice. Hedging is socially punished by the
  first rule; proof is expensive. The path of least resistance is confident
  wrongness.

## Constraints any replacement must respect

- Delegation criterion is *poison risk*, not *uncertainty*. Uncertain work stays
  with the orchestrator (or with the user) until the spec is solid; only then
  does it delegate. Exploration (which by nature poisons context) goes in
  subagents regardless of certainty.
- No rule-on-correction reflex. Corrections are conversation, not file edits.
  Diagnosis of recurring failures may eventually warrant a rule, but only after
  the pattern is clear across sessions — not reactively in the moment.
- The file must have a bound. Some forcing function against monotonic growth.
  Open question what that is.
- "I don't know" and "stop" must be first-class outputs, not failure states the
  model rationalizes away.

## What this file deliberately does not contain

- New rules.
- Drafts of replacement CLAUDE.md content.
- Prescriptions for how the redesign should be structured.

Those are the design work, and the design work happens with a clear head in a
fresh session reading these notes as input — not at the bottom of the session
that produced the failures.
