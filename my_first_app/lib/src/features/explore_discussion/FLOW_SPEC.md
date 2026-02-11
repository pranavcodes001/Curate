# Explore Discussion — Non-Visual Flow Specification

Scope: Map the guided question tree to concrete user/system flows. Conceptual only — no UI, no code, no API implementation.

Goals:
- Keep the flow implementation-agnostic
- Make v1 (must-have) vs later features explicit
- Clarify what is precomputed vs computed on-demand and what the “discussion database” should provide

---

## Key conventions
- "User action": what the user does (taps/selects/etc.) — conceptual only.
- "System action": what the system reads/queries/decides in response.
- "Expected output shape": conceptual structure (not JSON, no UI) returned to the caller.
- "Cached vs computed": whether the response is typically served from precomputed artifacts, session cache, or computed on-demand.
- v1 vs Later: each step is annotated as **v1** or **later** depending on whether it is required in the initial release.

---

## 1) Entering Explore Discussion (session start)

Step 1 — User: Tap **Explore discussion — AI (opt-in)** from Story Detail
- System action:
  - Show consent prompt (local copy). If user declines, abort and return to Story Detail.
  - If user accepts, set session consent flag (in-memory/session store) and proceed.
  - Query the Discussion DB for available precomputed artifacts for this story: backend summary, claim index, top-comment references, provenance map.
- Expected output shape (initial node):
  - session: {consent: true}
  - initialContext: { summary?: text? , precomputedFlags: {summary: bool, claimsIndex: bool} }
  - suggested next steps: list of node labels (Overview, Technical Analysis, Community Sentiment, Verification)
- Cached vs computed:
  - Consent flow: local (no backend) — **v1**
  - Backend summary: if precomputed in DB, returned immediately — **v1 (backend-provided summary)**
  - If no summary precomputed, mark `summary: null` and schedule an on-demand compute (see below) — **v1 (on-demand fallback)**

Step 2 — User: Choose Quick Start option (e.g., Quick summary, Guided walkthrough, or pick a node)
- System action:
  - If Quick summary chosen and precomputed summary exists: return precomputed summary and provenance.
  - If summary not precomputed: schedule on-demand summary compute (backend or server-side compute) and inform user of expected wait/streaming progress.
  - If Guided walkthrough chosen: open the root node using available summary and top-comment references as context.
- Expected output shape (Quick summary):
  - { summary: bullets, provenance: {modelId, modelVersion, sourceRefs}} plus suggestions (next nodes)
- Cached vs computed:
  - Precomputed summary: **cached (discussion DB)** — **v1**
  - On-demand summary: **computed on-demand** by backend/compute service — **v1 fallback**

Notes:
- Precomputing summaries for active stories improves latency; the app must gracefully fall back to compute-on-demand when needed.
- Always attach provenance metadata to any summary returned.

---

## 2) Moving between guided nodes (node navigation)

Generic node interaction model (applies to Overview, Technical Analysis, Sentiment, etc.)

Step N — User: Select a guided node (e.g., Technical Analysis)
- System action:
  - Check session cache for node result.
  - If not cached, query Discussion DB for relevant precomputed artifacts for that node (e.g., claimsIndex, topCommentIds). If relevant artifacts exist, retrieve and synthesize node response from them.
  - If required artifacts do not exist or are stale, request on-demand computation (server-side summarization/extraction over comments + story text).
  - Always attach provenance pointers (comment ids, excerpt indices, model id/version, and an explanation of how the answer was formed).
- Expected output shape (node result):
  - { nodeId, answer: short bullets or paragraph, supportingExcerpts: [ {commentId, excerptText, location} ], provenance: { sources: [urls/commentIds], modelInfo }, suggestedFollowUps: [nodeIds] }
- Cached vs computed:
  - Node results can be cached in-session to reduce repeated compute for the same user session — **v1**
  - Discussion DB may contain precomputed claim extractions and top excerpt lists (optional but recommended for performance) — **v1 (if available), later: heavier extractions**
  - Ad-hoc extraction and analysis for missing artifacts are computed on-demand — **v1 fallback**

Special constraints for v1:
- Limit the scope of analysis to top-K comments and the backend summary to reduce compute and hallucination risk.
- Use curated, template-driven prompts for node computations to keep outputs predictable.

Later enhancements:
- Node caching persisted to Discussion DB for reuse across sessions (later).
- Interactive features (feedback, score adjustment) are **later** features.

---

## 3) Viewing provenance (drill into sources)

Step P — User: Request "See sources" or "View original" for a given excerpt or node
- System action:
  - Resolve the excerpt's source references (comment id, link to external article) via the Discussion DB.
  - Return the minimal original context needed for verification (e.g., full comment text or source snippet and link).
- Expected output shape (provenance block):
  - { excerptSource: { type: comment|external, id|url }, fullText: string, meta: { author, time }, modelInfo: { modelId, modelVersion, explanationOfMethod } }
- Cached vs computed:
  - Source text is stored in the canonical discussion DB (precomputed/cached) — **v1**
  - Provenance metadata (modelId, method) is generated at the time of node computation and persisted with the node result where possible — **v1**

Notes:
- Always provide direct links or IDs so users can inspect the raw, unmodified content in its original form.

---

## 4) Exiting back to raw Story Detail

Step X — User: Exit/Back
- System action:
  - End the session view, clear any ephemeral session cache unless user chose to save a session (save feature is **later**).
  - Persist minimal telemetry: consent flag, visited node ids (for analytics) — anonymized as needed.
- Expected output shape (return payload to Story Detail):
  - { lastVisitedNodeId?: string, sessionSummaryReference?: id? }
- Cached vs computed:
  - Session cache: ephemeral (in-memory) — **v1**
  - Persisted session artifacts: **later**, only if user explicitly saves the analysis

Notes:
- Back navigation returns user to the raw Story Detail which remains unchanged; any AI artifacts are overlays or separate documents, not in-place edits.

---

## 5) Data & caching policy (how Discussion DB supports flows)

Suggested minimal Discussion DB artifacts (v1 focus):
- Canonical story snapshot (story text + comment list with ids and timestamps) — **v1**
- Backend-provided summary (if available) + provenance info — **v1**
- Top-comment references (pre-ranked by score/time heuristics) — **v1 (recommended for performance)**
- Node result cache (session-level or short-lived DB cache) storing: nodeId, answer, supportingExcerpts, provenance — **v1 (session)**

Later artifacts (optional for performance/usability):
- Persistent node results and claim-index for reuse across users and sessions — **later**
- Clustered comment groups and visualization-ready metadata — **later**

Caching strategy (implementation-agnostic):
- Use the Discussion DB for canonical and precomputed items; keep session cache for transient, per-user node results.
- For v1, prefer returning existing DB artifacts quickly and falling back to an on-demand compute; persist the result in session cache.

---

## 6) Backend precompute vs on-demand (explicit mapping)
- Precomputed (recommended for low-latency v1 flows):
  - Backend-provided summary — **v1**
  - Top-comment indices and minimal claim extractions — **v1 (recommended)**
  - Canonical story snapshot — **v1**
- On-demand compute (used as fallback or for lower-traffic items):
  - Node-specific synthesis when precomputed artifacts are missing — **v1 fallback**
  - Verification passes that require external source checks — **v1 (where feasible)** or **later** if heavy external queries are required

Rationale: precomputing small, high-value artifacts avoids latency and reduces hallucination risk by limiting the input set for node computations.

---

## 7) v1 vs Later feature map (explicit)
- v1 (must-have):
  - Consent & opt-in flow
  - Quick summary (backend-provided) and summary-as-first-step
  - Guided nodes with curated templates (Overview, Technical Analysis, Community Sentiment, Verification flags)
  - Provenance display with links to original content
  - Session caching of visited nodes
- Later (enhancements):
  - Persistent DB caches of node results and claim indices for cross-session reuse
  - Interactive feedback tools and corrections
  - Comment clustering / visualization
  - Exportable insights and sharing

---

## 8) Small example micro-flow (concise)
1. User opens Explore and consents.
2. System returns precomputed summary (from DB) + suggested nodes. (fast)
3. User selects Technical Analysis.
4. System finds no precomputed node result, fetches top-K comments from Discussion DB and runs a constrained summarization job (on-demand); returns answer + excerpts + provenance; caches in-session.
5. User taps "See sources" on an excerpt; system returns the original comment text and link from the Discussion DB.
6. User exits — session cache is discarded; minimal telemetry persisted for analytics.

---

## Implementation notes (non-prescriptive)
- Keep node computations reproducible by storing their provenance and input references (comment ids + snapshot timestamps) with their results.
- Limit free-form inputs in v1; prefer template-driven nodes to keep the system predictable and auditable.
- Respect privacy and retention policies: do not persist raw comment text for longer than necessary, and provide a mechanism for anonymized telemetry where required.

---

End of flow specification. Stop here and request confirmation before proceeding to consent text, micro-flows, or test cases.