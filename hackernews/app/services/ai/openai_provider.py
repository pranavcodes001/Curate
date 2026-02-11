from __future__ import annotations
import json
from typing import Any, List

import httpx

from app.config import settings
from app.services.ai.base import AIProvider
from app.services.ai.schemas import SummaryData


class OpenAIProvider(AIProvider):
    """OpenAI provider using the Responses API via HTTPX."""

    def __init__(self, api_key: str | None = None, model: str | None = None):
        self.api_key = api_key or settings.OPENAI_API_KEY
        self.model = model or settings.OPENAI_MODEL or "gpt-5-mini"
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY is required for OpenAIProvider")

    async def summarize_story(self, story_payload: dict) -> SummaryData:
        prompt = self._build_prompt(story_payload)
        data = {
            "model": self.model,
            "input": prompt,
        }

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post("https://api.openai.com/v1/responses", headers=headers, json=data)
            resp.raise_for_status()
            payload = resp.json()

        text = _extract_output_text(payload)
        summary = _parse_summary_json(text)
        return summary

    def _build_prompt(self, story_payload: dict) -> str:
        clean_payload = json.dumps(story_payload, ensure_ascii=False)
        return (
            "You are generating a concise Hacker News story summary.\n"
            "Return JSON ONLY with keys: tldr (string), key_points (list of strings), "
            "consensus (one of: positive, mixed, unclear, negative).\n"
            "Keep tldr under 1 sentence and key_points 3-5 bullets.\n"
            f"Story payload: {clean_payload}"
        )


def _extract_output_text(payload: dict) -> str:
    # New Responses API format: output -> list of messages -> content[] -> output_text
    if isinstance(payload, dict):
        output = payload.get("output", [])
        texts: List[str] = []
        for item in output:
            if item.get("type") != "message":
                continue
            for content in item.get("content", []):
                if content.get("type") == "output_text":
                    texts.append(content.get("text", ""))
        if texts:
            return "\n".join(texts).strip()

        # Fallback if response includes output_text directly
        if "output_text" in payload and isinstance(payload["output_text"], str):
            return payload["output_text"].strip()

    return ""


def _parse_summary_json(text: str) -> SummaryData:
    if not text:
        return SummaryData(tldr="TL;DR unavailable", key_points=[], consensus="unclear")

    # Try direct JSON parse
    try:
        data = json.loads(text)
    except Exception:
        # Try to extract JSON substring
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end != -1 and end > start:
            try:
                data = json.loads(text[start : end + 1])
            except Exception:
                data = None
        else:
            data = None

    if not isinstance(data, dict):
        return SummaryData(tldr=text[:200], key_points=[], consensus="unclear")

    tldr = str(data.get("tldr") or "").strip() or "TL;DR unavailable"
    key_points_raw = data.get("key_points") or []
    if not isinstance(key_points_raw, list):
        key_points_raw = [str(key_points_raw)]
    key_points = [str(k).strip() for k in key_points_raw if str(k).strip()]
    consensus = str(data.get("consensus") or "unclear").strip().lower()
    if consensus not in {"positive", "mixed", "unclear", "negative"}:
        consensus = "unclear"

    return SummaryData(tldr=tldr, key_points=key_points, consensus=consensus)
