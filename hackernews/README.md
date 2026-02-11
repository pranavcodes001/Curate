# HN Clarity Backend — MVP v1

Minimal backend to fetch Hacker News top stories, cache them in Redis, and serve a paginated feed API.

## Prerequisites
- Python 3.11+
- Redis (local or remote)

## Quickstart (local)
1. Create virtualenv and install deps:

   python -m venv .venv
   .\.venv\Scripts\activate
   pip install -r requirements.txt

2. Start Redis (local docker):

   docker run --rm -p 6379:6379 redis:7

3. Copy env and adjust if needed:

   copy .env.example .env

4. Run the app (development):

   uvicorn app.main:app --reload

5. Run the background worker (separate terminal):

   # Powershell
   .\\scripts\\run_worker.ps1

## Notes
- This skeleton is intentionally minimal: no AI provider, no auth, SQLite for local persistence.
- Implementation is not included yet — only folders and minimal files are present.
