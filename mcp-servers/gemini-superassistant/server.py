#!/usr/bin/env python3
"""
Gemini Superassistant MCP Server
Spectrum Protocol 2026 - agentEther Integration

Features:
- Persistent session management
- Automatic fallback to Ollama when Gemini quota exceeded
- Multi-session support
- Session persistence across restarts
"""
import os
import json
import asyncio
import httpx
from pathlib import Path
from typing import Any, List
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

API_BASE_URL = os.getenv("API_BASE_URL", "https://generativelanguage.googleapis.com/v1beta")
API_KEY = os.getenv("GEMINI_API_KEY", "")
TIMEOUT = int(os.getenv("GEMINI_TIMEOUT_MS", "60000")) / 1000
DEFAULT_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "mistral:latest")

SESSION_DIR = Path.home() / ".gemini_mcp_sessions"
SESSION_DIR.mkdir(exist_ok=True)

app = Server("gemini-superassistant")

class SessionManager:
    """Manages persistent chat sessions on disk"""

    @staticmethod
    def _path(session_id: str) -> Path:
        """Get path to session file"""
        return SESSION_DIR / f"{session_id}.json"

    @staticmethod
    def save(session_id: str, messages: list):
        """Save session to disk"""
        p = SessionManager._path(session_id)
        with open(p, "w", encoding="utf-8") as f:
            json.dump({"messages": messages}, f, ensure_ascii=False, indent=2)

    @staticmethod
    def load(session_id: str) -> list:
        """Load session from disk"""
        p = SessionManager._path(session_id)
        if p.exists():
            with open(p, "r", encoding="utf-8") as f:
                return json.load(f).get("messages", [])
        return []

    @staticmethod
    def list_sessions() -> list:
        """List all available sessions"""
        return [f.stem for f in SESSION_DIR.glob("*.json")]

    @staticmethod
    def clear(session_id: str):
        """Clear session (delete from disk)"""
        p = SessionManager._path(session_id)
        if p.exists():
            p.unlink()

@app.list_tools()
async def list_tools() -> List[Tool]:
    """Register available MCP tools"""
    return [
        Tool(
            name="gemini_chat",
            description="Superassistant: rozmowa z Gemini z trwałym kontekstem sesji",
            inputSchema={
                "type": "object",
                "properties": {
                    "prompt": {"type": "string", "description": "Twoje pytanie / polecenie"},
                    "session_id": {
                        "type": "string",
                        "description": "ID sesji (np. projekt, klient, task)",
                        "default": "default"
                    },
                    "model": {
                        "type": "string",
                        "description": "Model Gemini",
                        "default": DEFAULT_MODEL
                    }
                },
                "required": ["prompt"]
            }
        ),
        Tool(
            name="create_session",
            description="Tworzy pustą sesję superassistanta o podanym ID",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {"type": "string", "description": "Unikalne ID sesji"}
                },
                "required": ["session_id"]
            }
        ),
        Tool(
            name="list_sessions",
            description="Zwraca listę wszystkich sesji superassistanta",
            inputSchema={"type": "object", "properties": {}}
        ),
        Tool(
            name="clear_session",
            description="Czyści sesję (usuwa kontekst z dysku)",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {"type": "string", "description": "ID sesji do wyczyszczenia"}
                },
                "required": ["session_id"]
            }
        )
    ]

@app.call_tool()
async def call_tool(name: str, arguments: Any) -> List[TextContent]:
    """Handle tool calls"""
    if name == "gemini_chat":
        return await handle_gemini_chat(arguments)
    elif name == "create_session":
        sid = arguments.get("session_id")
        SessionManager.save(sid, [])
        return [TextContent(type="text", text=f"[SuperAssistant] Utworzono sesję: {sid}")]
    elif name == "list_sessions":
        sessions = SessionManager.list_sessions()
        return [TextContent(type="text", text="[SuperAssistant] Sesje: " + ", ".join(sessions))]
    elif name == "clear_session":
        sid = arguments.get("session_id")
        SessionManager.clear(sid)
        return [TextContent(type="text", text=f"[SuperAssistant] Wyczyściłem sesję: {sid}")]
    else:
        return [TextContent(type="text", text=f"[SuperAssistant] Nieznane narzędzie: {name}")]

async def call_ollama(prompt: str, history: list) -> str:
    """Fallback to local Ollama when Gemini quota exceeded"""
    ollama_url = f"{OLLAMA_URL}/api/chat"

    # Convert history to Ollama format
    messages = []
    for msg in history:
        role = "user" if msg["role"] == "user" else "assistant"
        text = msg["parts"][0]["text"]
        messages.append({"role": role, "content": text})

    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "stream": False
    }

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        resp = await client.post(ollama_url, json=payload)
        resp.raise_for_status()
        data = resp.json()
        return data["message"]["content"]

async def handle_gemini_chat(args: dict) -> List[TextContent]:
    """Handle Gemini chat with session management and Ollama fallback"""
    prompt = args.get("prompt")
    session_id = args.get("session_id", "default")
    model = args.get("model", DEFAULT_MODEL)

    history = SessionManager.load(session_id)
    history.append({"role": "user", "parts": [{"text": prompt}]})

    payload = {"contents": history}

    # Build URL with API key as query param (Google style)
    url = f"{API_BASE_URL}/models/{model}:generateContent?key={API_KEY}"

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            resp = await client.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
            )

            # If quota exceeded (429), fallback to Ollama
            if resp.status_code == 429:
                try:
                    text = await call_ollama(prompt, history)
                    history.append({"role": "model", "parts": [{"text": text}]})
                    SessionManager.save(session_id, history)
                    return [TextContent(
                        type="text",
                        text=f"[SuperAssistant][sesja={session_id}][Ollama fallback]\n\n{text}"
                    )]
                except Exception as ollama_err:
                    return [TextContent(
                        type="text",
                        text=f"[SuperAssistant] Gemini quota exceeded, Ollama fallback failed: {str(ollama_err)}"
                    )]

            resp.raise_for_status()
            data = resp.json()

        if "candidates" in data and data["candidates"]:
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            history.append({"role": "model", "parts": [{"text": text}]})
            SessionManager.save(session_id, history)
            return [TextContent(
                type="text",
                text=f"[SuperAssistant][sesja={session_id}]\n\n{text}"
            )]
        else:
            return [TextContent(type="text", text="[SuperAssistant] Brak odpowiedzi od Gemini")]

    except Exception as e:
        # Try Ollama as final fallback
        try:
            text = await call_ollama(prompt, history)
            history.append({"role": "model", "parts": [{"text": text}]})
            SessionManager.save(session_id, history)
            return [TextContent(
                type="text",
                text=f"[SuperAssistant][sesja={session_id}][Ollama fallback]\n\n{text}"
            )]
        except Exception as ollama_err:
            return [TextContent(
                type="text",
                text=f"[SuperAssistant] Błąd Gemini: {str(e)}\nBłąd Ollama: {str(ollama_err)}"
            )]

async def main():
    """Main entry point"""
    async with stdio_server() as (r, w):
        await app.run(r, w, app.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
