"""Static interests catalog (v1)."""

from typing import List, Dict


INTEREST_GROUPS: List[Dict[str, object]] = [
    {
        "group": "AI",
        "items": [
            {"name": "LLMs", "keywords": ["llm", "gpt", "transformer", "claude", "gemini"]},
            {"name": "AI Research", "keywords": ["arxiv", "paper", "benchmark", "research", "neural"]},
            {"name": "MLOps", "keywords": ["mlops", "inference", "serving", "pipeline", "deployment"]},
            {"name": "AI Safety", "keywords": ["alignment", "safety", "evals", "red team", "policy"]},
            {"name": "Prompting", "keywords": ["prompt", "prompting", "system prompt", "prompt engineering", "chain-of-thought"]},
        ],
    },
    {
        "group": "Backend",
        "items": [
            {"name": "Databases", "keywords": ["postgres", "mysql", "sqlite", "database", "sql"]},
            {"name": "Distributed Systems", "keywords": ["distributed", "consensus", "raft", "paxos", "kafka"]},
            {"name": "DevOps", "keywords": ["devops", "ci/cd", "kubernetes", "docker", "terraform"]},
            {"name": "Networking", "keywords": ["network", "tcp", "http", "dns", "bgp"]},
            {"name": "Cloud", "keywords": ["aws", "gcp", "azure", "cloud", "serverless"]},
        ],
    },
    {
        "group": "Frontend",
        "items": [
            {"name": "Web Frameworks", "keywords": ["react", "vue", "svelte", "angular", "next"]},
            {"name": "UI/UX", "keywords": ["ux", "ui", "design", "interface", "usability"]},
            {"name": "Mobile", "keywords": ["android", "ios", "flutter", "react native", "swift"]},
            {"name": "Design Systems", "keywords": ["design system", "component", "storybook", "ui kit", "tokens"]},
            {"name": "Performance", "keywords": ["performance", "web perf", "latency", "bundle", "rendering"]},
        ],
    },
    {
        "group": "Startups",
        "items": [
            {"name": "SaaS", "keywords": ["saas", "b2b", "subscription", "pricing", "churn"]},
            {"name": "Fundraising", "keywords": ["funding", "series a", "seed", "investor", "vc"]},
            {"name": "Product Strategy", "keywords": ["product", "roadmap", "strategy", "market", "pm"]},
            {"name": "Growth", "keywords": ["growth", "marketing", "seo", "distribution", "acquisition"]},
            {"name": "Hiring", "keywords": ["hiring", "jobs", "recruiting", "talent", "interview"]},
        ],
    },
    {
        "group": "Security",
        "items": [
            {"name": "AppSec", "keywords": ["security", "xss", "csrf", "auth", "vulnerability"]},
            {"name": "InfraSec", "keywords": ["infra", "zero trust", "cloud security", "iam", "k8s security"]},
            {"name": "Cryptography", "keywords": ["crypto", "encryption", "tls", "hash", "key"]},
            {"name": "Privacy", "keywords": ["privacy", "tracking", "data", "gdpr", "consent"]},
            {"name": "Vulnerabilities", "keywords": ["cve", "exploit", "bug", "rce", "patch"]},
        ],
    },
]

