#!/usr/bin/env python3
"""
Claude API (Anthropic) MCP Server

Provides access to Anthropic's Claude models via MCP protocol
with conversation history and advanced features.
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
    import anthropic
except ImportError:
    print("Error: anthropic package not installed")
    print("Install with: pip install anthropic")
    exit(1)

# Configuration
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-3-5-sonnet-20241022")
CLAUDE_MAX_TOKENS = int(os.getenv("CLAUDE_MAX_TOKENS", "4096"))
CLAUDE_TEMPERATURE = float(os.getenv("CLAUDE_TEMPERATURE", "1.0"))

# Session storage
SESSION_DIR = Path.home() / ".claude_api_mcp_sessions"
SESSION_DIR.mkdir(exist_ok=True)

# Initialize Anthropic client
if ANTHROPIC_API_KEY:
    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
else:
    print("Warning: ANTHROPIC_API_KEY not set")
    client = None

# Initialize MCP server
app = Server("claude-api")


class SessionManager:
    """Manage chat sessions with disk persistence"""

    @staticmethod
    def save(session_id: str, messages: list, system: str = None) -> None:
        """Save session to disk"""
        session_file = SESSION_DIR / f"{session_id}.json"
        with open(session_file, 'w', encoding='utf-8') as f:
            json.dump({
                "session_id": session_id,
                "system": system,
                "messages": messages,
                "updated_at": datetime.utcnow().isoformat()
            }, f, indent=2)

    @staticmethod
    def load(session_id: str) -> tuple:
        """Load session from disk, returns (system, messages)"""
        session_file = SESSION_DIR / f"{session_id}.json"
        if session_file.exists():
            with open(session_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get("system"), data.get("messages", [])
        return None, []

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


async def call_claude(
    messages: List[Dict[str, Any]],
    system: Optional[str] = None,
    model: str = CLAUDE_MODEL,
    max_tokens: int = CLAUDE_MAX_TOKENS,
    temperature: float = CLAUDE_TEMPERATURE
) -> str:
    """Call Claude API with messages"""
    if not client:
        return "Error: Claude client not initialized. Please set ANTHROPIC_API_KEY."

    try:
        kwargs = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature
        }

        if system:
            kwargs["system"] = system

        response = client.messages.create(**kwargs)

        # Extract text from response
        if response.content:
            return response.content[0].text
        return "No response generated"

    except anthropic.APIError as e:
        return f"Claude API Error: {e}"
    except anthropic.RateLimitError:
        return "Error: Claude rate limit exceeded. Please try again later."
    except anthropic.APIConnectionError:
        return "Error: Failed to connect to Claude API. Please check your internet connection."
    except Exception as e:
        return f"Error: {str(e)}"


@app.list_tools()
async def list_tools() -> List[Tool]:
    """List available Claude API tools"""
    return [
        Tool(
            name="claude_chat",
            description="Chat with Anthropic's Claude models with conversation history",
            inputSchema={
                "type": "object",
                "properties": {
                    "prompt": {
                        "type": "string",
                        "description": "The message to send to Claude"
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
                        "enum": [
                            "claude-3-5-sonnet-20241022",
                            "claude-3-opus-20240229",
                            "claude-3-sonnet-20240229",
                            "claude-3-haiku-20240307"
                        ],
                        "default": CLAUDE_MODEL
                    },
                    "temperature": {
                        "type": "number",
                        "description": "Temperature for response randomness (0.0-1.0)",
                        "minimum": 0.0,
                        "maximum": 1.0,
                        "default": CLAUDE_TEMPERATURE
                    },
                    "max_tokens": {
                        "type": "integer",
                        "description": "Maximum tokens in response",
                        "minimum": 1,
                        "maximum": 8192,
                        "default": CLAUDE_MAX_TOKENS
                    }
                },
                "required": ["prompt"]
            }
        ),
        Tool(
            name="claude_create_session",
            description="Create a new Claude chat session",
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
            name="claude_list_sessions",
            description="List all Claude chat sessions",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="claude_clear_session",
            description="Clear a Claude chat session history",
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
            name="claude_delete_session",
            description="Delete a Claude chat session",
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
        if name == "claude_chat":
            session_id = arguments.get("session_id", "default")
            prompt = arguments["prompt"]
            system_prompt = arguments.get("system_prompt")
            model = arguments.get("model", CLAUDE_MODEL)
            temperature = arguments.get("temperature", CLAUDE_TEMPERATURE)
            max_tokens = arguments.get("max_tokens", CLAUDE_MAX_TOKENS)

            # Load session history
            saved_system, history = SessionManager.load(session_id)

            # Use provided system prompt or saved one
            system = system_prompt or saved_system

            # Add new user message
            history.append({"role": "user", "content": prompt})

            # Call Claude
            response = await call_claude(
                history,
                system,
                model,
                max_tokens,
                temperature
            )

            # Update history
            history.append({"role": "assistant", "content": response})

            # Save session
            SessionManager.save(session_id, history, system)

            return [TextContent(type="text", text=response)]

        elif name == "claude_create_session":
            session_id = arguments["session_id"]
            system_prompt = arguments.get("system_prompt")

            SessionManager.save(session_id, [], system_prompt)

            return [TextContent(
                type="text",
                text=f"Claude session '{session_id}' created successfully"
            )]

        elif name == "claude_list_sessions":
            sessions = SessionManager.list()

            if not sessions:
                return [TextContent(
                    type="text",
                    text="No Claude sessions found"
                )]

            session_list = "\n".join(f"- {s}" for s in sessions)
            return [TextContent(
                type="text",
                text=f"Active Claude sessions:\n{session_list}"
            )]

        elif name == "claude_clear_session":
            session_id = arguments["session_id"]

            # Keep system prompt if it exists
            system, _ = SessionManager.load(session_id)
            SessionManager.save(session_id, [], system)

            return [TextContent(
                type="text",
                text=f"Claude session '{session_id}' cleared"
            )]

        elif name == "claude_delete_session":
            session_id = arguments["session_id"]

            if SessionManager.delete(session_id):
                return [TextContent(
                    type="text",
                    text=f"Claude session '{session_id}' deleted"
                )]
            else:
                return [TextContent(
                    type="text",
                    text=f"Claude session '{session_id}' not found"
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
