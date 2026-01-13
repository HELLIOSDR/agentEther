#!/usr/bin/env python3
"""
OpenAI ChatGPT MCP Server

Provides access to OpenAI's ChatGPT models via MCP protocol
with conversation history, function calling, and streaming support.
"""

import asyncio
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

try:
    import openai
except ImportError:
    print("Error: openai package not installed")
    print("Install with: pip install openai")
    exit(1)

# Configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4-turbo-preview")
OPENAI_TEMPERATURE = float(os.getenv("OPENAI_TEMPERATURE", "0.7"))
OPENAI_MAX_TOKENS = int(os.getenv("OPENAI_MAX_TOKENS", "4096"))

# Session storage
SESSION_DIR = Path.home() / ".openai_mcp_sessions"
SESSION_DIR.mkdir(exist_ok=True)

# Initialize OpenAI client
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY
    client = openai.OpenAI(api_key=OPENAI_API_KEY)
else:
    print("Warning: OPENAI_API_KEY not set")
    client = None

# Initialize MCP server
app = Server("openai-assistant")


class SessionManager:
    """Manage chat sessions with disk persistence"""

    @staticmethod
    def save(session_id: str, messages: list) -> None:
        """Save session to disk"""
        session_file = SESSION_DIR / f"{session_id}.json"
        with open(session_file, 'w', encoding='utf-8') as f:
            json.dump({
                "session_id": session_id,
                "messages": messages,
                "updated_at": datetime.utcnow().isoformat()
            }, f, indent=2)

    @staticmethod
    def load(session_id: str) -> list:
        """Load session from disk"""
        session_file = SESSION_DIR / f"{session_id}.json"
        if session_file.exists():
            with open(session_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get("messages", [])
        return []

    @staticmethod
    def list() -> List[str]:
        """List all session IDs"""
        return [f.stem for f in SESSION_DIR.glob("*.json")]

    @staticmethod
    def delete(session_id: str) -> bool:
        """Delete a session"""
        session_file = SESSION_DIR / f"{session_id}.json"
        if session_file.exists():
            session_file.unlink()
            return True
        return False


async def call_openai(
    messages: List[Dict[str, str]],
    model: str = OPENAI_MODEL,
    temperature: float = OPENAI_TEMPERATURE,
    max_tokens: int = OPENAI_MAX_TOKENS,
    stream: bool = False
) -> str:
    """Call OpenAI API with messages"""
    if not client:
        return "Error: OpenAI client not initialized. Please set OPENAI_API_KEY."

    try:
        if stream:
            # Streaming response
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True
            )

            full_response = ""
            for chunk in response:
                if chunk.choices[0].delta.content:
                    full_response += chunk.choices[0].delta.content

            return full_response
        else:
            # Non-streaming response
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens
            )

            return response.choices[0].message.content

    except openai.APIError as e:
        return f"OpenAI API Error: {e}"
    except openai.RateLimitError:
        return "Error: OpenAI rate limit exceeded. Please try again later."
    except openai.APIConnectionError:
        return "Error: Failed to connect to OpenAI API. Please check your internet connection."
    except Exception as e:
        return f"Error: {str(e)}"


@app.list_tools()
async def list_tools() -> List[Tool]:
    """List available OpenAI tools"""
    return [
        Tool(
            name="openai_chat",
            description="Chat with OpenAI ChatGPT models with conversation history",
            inputSchema={
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "The message to send to ChatGPT"
                    },
                    "session_id": {
                        "type": "string",
                        "description": "Session ID for conversation continuity",
                        "default": "default"
                    },
                    "system_prompt": {
                        "type": "string",
                        "description": "Optional system prompt to set behavior"
                    },
                    "model": {
                        "type": "string",
                        "description": "Model to use",
                        "enum": ["gpt-4-turbo-preview", "gpt-4", "gpt-3.5-turbo", "gpt-3.5-turbo-16k"],
                        "default": OPENAI_MODEL
                    },
                    "temperature": {
                        "type": "number",
                        "description": "Temperature for response randomness (0.0-2.0)",
                        "minimum": 0.0,
                        "maximum": 2.0,
                        "default": OPENAI_TEMPERATURE
                    },
                    "stream": {
                        "type": "boolean",
                        "description": "Use streaming response",
                        "default": False
                    }
                },
                "required": ["prompt"]
            }
        ),
        Tool(
            name="openai_create_session",
            description="Create a new chat session",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {
                        "type": "string",
                        "description": "Session ID to create"
                    },
                    "system_prompt": {
                        "type": "string",
                        "description": "Optional system prompt for this session"
                    }
                },
                "required": ["session_id"]
            }
        ),
        Tool(
            name="openai_list_sessions",
            description="List all chat sessions",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="openai_clear_session",
            description="Clear a chat session history",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {
                        "type": "string",
                        "description": "Session ID to clear"
                    }
                },
                "required": ["session_id"]
            }
        ),
        Tool(
            name="openai_delete_session",
            description="Delete a chat session",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {
                        "type": "string",
                        "description": "Session ID to delete"
                    }
                },
                "required": ["session_id"]
            }
        )
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> List[TextContent]:
    """Handle tool calls"""

    try:
        if name == "openai_chat":
            session_id = arguments.get("session_id", "default")
            prompt = arguments["prompt"]
            system_prompt = arguments.get("system_prompt")
            model = arguments.get("model", OPENAI_MODEL)
            temperature = arguments.get("temperature", OPENAI_TEMPERATURE)
            stream = arguments.get("stream", False)

            # Load session history
            history = SessionManager.load(session_id)

            # Build messages
            messages = []

            # Add system prompt if provided or if it's in history
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            elif history and history[0].get("role") == "system":
                messages.append(history[0])

            # Add conversation history (skip system prompt if present)
            start_idx = 1 if history and history[0].get("role") == "system" else 0
            messages.extend(history[start_idx:])

            # Add new user message
            messages.append({"role": "user", "content": prompt})

            # Call OpenAI
            response = await call_openai(messages, model, temperature, stream=stream)

            # Update history
            history.append({"role": "user", "content": prompt})
            history.append({"role": "assistant", "content": response})

            # Save session
            SessionManager.save(session_id, history)

            return [TextContent(type="text", text=response)]

        elif name == "openai_create_session":
            session_id = arguments["session_id"]
            system_prompt = arguments.get("system_prompt")

            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})

            SessionManager.save(session_id, messages)

            return [TextContent(
                type="text",
                text=f"Session '{session_id}' created successfully"
            )]

        elif name == "openai_list_sessions":
            sessions = SessionManager.list()

            if not sessions:
                return [TextContent(
                    type="text",
                    text="No sessions found"
                )]

            session_list = "\n".join(f"- {s}" for s in sessions)
            return [TextContent(
                type="text",
                text=f"Active sessions:\n{session_list}"
            )]

        elif name == "openai_clear_session":
            session_id = arguments["session_id"]

            # Keep system prompt if it exists
            history = SessionManager.load(session_id)
            if history and history[0].get("role") == "system":
                SessionManager.save(session_id, [history[0]])
            else:
                SessionManager.save(session_id, [])

            return [TextContent(
                type="text",
                text=f"Session '{session_id}' cleared"
            )]

        elif name == "openai_delete_session":
            session_id = arguments["session_id"]

            if SessionManager.delete(session_id):
                return [TextContent(
                    type="text",
                    text=f"Session '{session_id}' deleted"
                )]
            else:
                return [TextContent(
                    type="text",
                    text=f"Session '{session_id}' not found"
                )]

        else:
            return [TextContent(
                type="text",
                text=f"Unknown tool: {name}"
            )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"Error executing tool {name}: {str(e)}"
        )]


async def main():
    """Run the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
