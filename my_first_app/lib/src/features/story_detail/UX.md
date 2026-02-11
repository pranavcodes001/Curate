# Story Detail — UX Specification (refined)

Scope: conceptual UX only (no UI, no code, no state management).

## Key refinements (applied)
- **De-emphasize full comments**: The Story Detail screen should not default to showing full comment threads. Instead, show a concise, collapsed comments preview with a clear link to open the full thread or launch Explore Discussion for in-depth analysis.
- **Hierarchy clarity**:
  - **Explore discussion** is the *primary AI entry point* (opt-in). It is the recommended path for any AI-driven analysis or deep discussion insights.
  - **Summary** can be implemented either as:
    - a first step inside **Explore discussion** (preferred), or
    - a lightweight, quick-access shortcut that surfaces backend-provided summary and links to the full Explore flow.
- **AI affordances versioning**: Mark each AI feature as **v1 (must-have)** or **later** (enhancements, opt-in):
  - v1: Backend-provided summary (read-only), Explore Discussion (consent gated), provenance badges
  - Later: Highlighting/clustering of comments, interactive feedback tools, advanced filters, exportable insights

---

## Screen structure (conceptual)
1. Header (raw metadata)
   - Title, author, time, domain, score.
   - Read-only and untampered; no AI rewriting.

2. Content (raw story)
   - Story body and link preview (if appropriate).
   - Inline indicator to show AI overlays are available (off by default).

3. Comments preview (collapsed)
   - Show a short preview (e.g., top N comments by score/time) with a clear link: **View full discussion**.
   - Provide a separate prominent link/button: **Explore discussion — AI (opt-in)**.
   - Full comment thread is not shown by default to reduce noise and to signal that deep analysis belongs to the Explore flow.

4. Actions bar (explicit actions)
   - **Show summary (read-only)** — lightweight, quick view of backend summary; links into Explore discussion.
   - **Explore discussion — AI (opt-in)** — primary AI entry; opens guided exploration with consent.
   - **View full discussion** — expands to comments list (if the user prefers raw comments).

5. Trust & provenance area
   - Badges and ``See sources`` links attached to AI-generated outputs (model version, provenance). Always visible on AI outputs.

---

## UX flow updates
- Feed → Story Detail: user lands on raw story with collapsed comments preview and visible AI affordances.
- Story Detail → Summary: lightweight, fast access; visible as a shortcut and entrypoint to Explore discussion.
- Story Detail → Explore Discussion: explicit consent modal → guided question tree session.

Note: Full discussion analysis primarily lives inside Explore Discussion and not on the main Story Detail screen.

---

## AI boundaries (explicit)
- AI touches (v1):
  - Backend summary endpoint (read-only)
  - Guided analysis inside Explore Discussion (consent required)
  - Provenance metadata displayed alongside outputs
- AI does NOT touch:
  - Raw story text or comment content (no in-place edits)
  - Default feed presentation
- Trust guarantees:
  - Consent modal before any AI session
  - Persistent provenance badges and model version
  - Clear separation between raw content and AI outputs

---

## Button microcopy (refined)
- **Show summary (read-only)** — quick summary; small `model vX` badge
- **Explore discussion — AI (opt-in)** — opens consent flow, described as: "Guided analysis of this story and public comments; read-only, provenance shown"
- **View full discussion** — opens raw comments list

---

## Rationale (brief)
- Reduces clutter by hiding full comments by default and directing deep analysis to an opt-in, explainable flow.
- Ensures AI is discoverable but consensual and auditable.
- Keeps Story Detail focused and lightweight while enabling rich analysis when the user chooses it.

(End of Story Detail UX specification.)