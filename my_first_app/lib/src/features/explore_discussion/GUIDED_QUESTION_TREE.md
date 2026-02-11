# Explore Discussion — Guided Question Tree (conceptual)

Scope: Concept-level guided question tree for the Explore Discussion flow (no UI, no code).

Principles:
- Guided (not free-form): users are presented with curated strands of inquiry.
- Transparent & auditable: every AI response includes provenance and model metadata.
- Safe defaults: consent required; limited branching to reduce hallucination risk.

## Session entry
1. **Consent & Scope** (mandatory)
   - Confirm user consents to analysis of story and public comments.
   - Display what data is used, privacy notes, and the provenance policy.

2. **Quick Start Options (choose one)**
   - Quick summary (v1) — short backend-provided summary + link into deeper nodes.
   - Guided walkthrough (start here) — step-by-step topics.
   - Ask a specific pre-defined question (select from a list) — constrained question templates.

---

## High-level tree (nodes & sample prompts)

Root
├─ A: Overview & TL;DR (v1)
│   └─ A1: "Give me a concise summary of the story and main points." (output: 2–3 bullets) 
│       └─ A1a: "Show provenance and source excerpts." (shows links, model version)
│
├─ B: Technical Analysis (v1)
│   ├─ B1: "What technical details or claims are made in the story?" (bulleted claims)
│   ├─ B2: "Which claims are supported by comments or linked sources?" (matched evidence)
│   └─ B3 (later): "Flag any possible inaccuracies or missing context." (requires extra verification step)
│
├─ C: Community Sentiment & Consensus (v1)
│   ├─ C1: "What are the main viewpoints in the discussion?" (clustered sentiment / positions)
│   ├─ C2: "Which comments represent the most common perspectives?" (representative excerpts)
│   └─ C3 (later): "Provide an interactive map of arguments and support levels." (visualization placeholder)
│
├─ D: Counterarguments & Critique (v1)
│   ├─ D1: "What reasonable counterarguments exist?" (bullet list)
│   └─ D2 (later): "Rate counterargument strength and cite supporting comments." (scoring + citations)
│
├─ E: Related Resources & Context (v1)
│   ├─ E1: "List reputable sources or docs referenced in the discussion." (links + short note)
│   └─ E2 (later): "Fetch background context (prior coverage, related HN threads)." (expanded search)
│
├─ F: Actionable Insights (later)
│   ├─ F1: "What practical takeaways or checkpoints should a reader consider?" (bullets)
│   └─ F2: "List follow-up experiments / questions to validate claims." (list)
│
└─ G: Verification & Misinfo Check (v1)
    ├─ G1: "Are there claims that look unsupported or questionable?" (flagged items)
    └─ G2 (later): "Run targeted verification against known sources and cite results." (verification pass)

---

## Node behavior & constraints
- Each node returns: concise answer, supporting excerpts (if applicable), and provenance metadata (source links, model id/version).
- Nodes may offer **follow-up suggestions** (two or three next-step questions) to keep the user in a guided flow.
- Limit free-form input in v1; provide curated question templates to reduce hallucination risk.
- Track minimal session context (what nodes visited, user selections) to maintain coherence without storing raw comments beyond the session (privacy note).

## Example micro-flow
1. User selects **Guided walkthrough** → show A (Overview & TL;DR)
2. User taps **Technical Analysis** → show B1 and B2 with supporting excerpts
3. User requests **Verification** on a flagged claim → show G1 with recommended resources and a suggested follow-up.

## Outputs & provenance
- All outputs must include a provenance section: which comments were used, backend summary reference (if used), model version, and a short explanation of the method (e.g., "This answer is synthesized from the top 50 comments and the backend summary").
- Provide a `See original` link next to every excerpt so users can inspect the unmodified source.

## V1 vs Later feature map
- V1 (must-have): Consent flow, Overview/TL;DR, Technical Analysis (claims + evidence), Community Sentiment summary, Counterarguments (basic), Related Resources list, Verification flags, Provenance display, Summary as first-step.
- Later: Comment clustering/visualization, interactive feedback tooling, scoring/ranking of arguments, export/shareable insights, deeper verification automation, personalization of guided questions.

---

## Safety & quality notes
- Keep question templates conservative — avoid ambiguous prompts that encourage hallucination.
- Validate outputs by surfacing exact excerpts and links; give users the tools to verify independently.
- Provide an easy exit and a clear label indicating this is an AI-assisted interpretation, not an authoritative rewrite.

(End of guided question tree specification.)