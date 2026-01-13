#!/usr/bin/env python3
"""
Claude Coordination MCP Server

Provides MCP tools for cross-environment coordination:
- Query coordination state
- Send messages
- Create/manage tasks
- Check environment status
"""

import asyncio
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

# Paths
PROJECT_DIR = Path(__file__).parent.parent.parent
COORDINATION_DIR = PROJECT_DIR / "coordination"
STATE_FILE = COORDINATION_DIR / "state.json"
TASKS_FILE = COORDINATION_DIR / "tasks.json"
CONFIG_FILE = COORDINATION_DIR / "config.json"

# Initialize MCP server
app = Server("coordination")


def read_json_file(filepath: Path) -> Dict[str, Any]:
    """Read and parse JSON file"""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}


def run_script(script_name: str, args: List[str] = None) -> Dict[str, Any]:
    """Run a coordination script"""
    script_path = COORDINATION_DIR / script_name

    if not script_path.exists():
        return {"error": f"Script not found: {script_name}"}

    try:
        cmd = [str(script_path)]
        if args:
            cmd.extend(args)

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )

        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode,
            "success": result.returncode == 0
        }
    except subprocess.TimeoutExpired:
        return {"error": "Script execution timed out"}
    except Exception as e:
        return {"error": str(e)}


@app.list_tools()
async def list_tools() -> List[Tool]:
    """List available coordination tools"""
    return [
        Tool(
            name="get_coordination_state",
            description="Get current coordination state across all environments",
            inputSchema={
                "type": "object",
                "properties": {
                    "environment": {
                        "type": "string",
                        "description": "Optional: specific environment (swissai, anthropic) or 'all'",
                        "default": "all"
                    }
                }
            }
        ),
        Tool(
            name="send_coordination_message",
            description="Send a message to another environment",
            inputSchema={
                "type": "object",
                "properties": {
                    "to": {
                        "type": "string",
                        "description": "Target environment (swissai, anthropic, all)",
                        "enum": ["swissai", "anthropic", "all"]
                    },
                    "subject": {
                        "type": "string",
                        "description": "Message subject"
                    },
                    "body": {
                        "type": "string",
                        "description": "Message body"
                    },
                    "priority": {
                        "type": "string",
                        "description": "Priority level",
                        "enum": ["normal", "high", "urgent"],
                        "default": "normal"
                    }
                },
                "required": ["to", "subject", "body"]
            }
        ),
        Tool(
            name="list_coordination_tasks",
            description="List coordination tasks with optional filters",
            inputSchema={
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "description": "Filter by status",
                        "enum": ["pending", "in_progress", "completed"]
                    },
                    "assigned_to": {
                        "type": "string",
                        "description": "Filter by assigned environment"
                    },
                    "priority": {
                        "type": "integer",
                        "description": "Filter by priority (1-5)",
                        "minimum": 1,
                        "maximum": 5
                    }
                }
            }
        ),
        Tool(
            name="create_coordination_task",
            description="Create a new coordination task",
            inputSchema={
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Task title"
                    },
                    "description": {
                        "type": "string",
                        "description": "Task description"
                    },
                    "priority": {
                        "type": "integer",
                        "description": "Priority (1=highest, 5=lowest)",
                        "minimum": 1,
                        "maximum": 5,
                        "default": 2
                    },
                    "assign_to": {
                        "type": "string",
                        "description": "Assign to environment (optional)"
                    },
                    "tags": {
                        "type": "string",
                        "description": "Comma-separated tags"
                    }
                },
                "required": ["title"]
            }
        ),
        Tool(
            name="accept_coordination_task",
            description="Accept and start working on a task",
            inputSchema={
                "type": "object",
                "properties": {
                    "task_id": {
                        "type": "string",
                        "description": "Task ID to accept"
                    }
                },
                "required": ["task_id"]
            }
        ),
        Tool(
            name="complete_coordination_task",
            description="Mark a task as completed",
            inputSchema={
                "type": "object",
                "properties": {
                    "task_id": {
                        "type": "string",
                        "description": "Task ID to complete"
                    },
                    "comment": {
                        "type": "string",
                        "description": "Optional completion comment"
                    }
                },
                "required": ["task_id"]
            }
        ),
        Tool(
            name="check_environment_status",
            description="Check if an environment is active and what it's working on",
            inputSchema={
                "type": "object",
                "properties": {
                    "environment": {
                        "type": "string",
                        "description": "Environment name (swissai, anthropic)",
                        "enum": ["swissai", "anthropic"]
                    }
                },
                "required": ["environment"]
            }
        ),
        Tool(
            name="sync_coordination_state",
            description="Sync coordination state to Google Drive and ChromaDB",
            inputSchema={
                "type": "object",
                "properties": {
                    "include_chromadb": {
                        "type": "boolean",
                        "description": "Also sync to ChromaDB",
                        "default": True
                    }
                }
            }
        )
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> List[TextContent]:
    """Handle tool calls"""

    try:
        if name == "get_coordination_state":
            state = read_json_file(STATE_FILE)
            env = arguments.get("environment", "all")

            if env != "all" and "environments" in state:
                if env in state["environments"]:
                    result = {
                        "environment": env,
                        "data": state["environments"][env],
                        "last_update": state.get("lastUpdate")
                    }
                else:
                    result = {"error": f"Environment not found: {env}"}
            else:
                result = state

            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2)
            )]

        elif name == "send_coordination_message":
            args = [
                "--to", arguments["to"],
                "--subject", arguments["subject"],
                "--body", arguments["body"]
            ]

            if "priority" in arguments:
                args.extend(["--priority", arguments["priority"]])

            result = run_script("send-message.sh", args)

            return [TextContent(
                type="text",
                text=result.get("stdout", "") or result.get("error", "Unknown error")
            )]

        elif name == "list_coordination_tasks":
            args = []

            if "status" in arguments:
                args.extend(["--status", arguments["status"]])
            if "assigned_to" in arguments:
                args.extend(["--assigned-to", arguments["assigned_to"]])
            if "priority" in arguments:
                args.extend(["--priority", str(arguments["priority"])])

            result = run_script("list-tasks.sh", args)

            return [TextContent(
                type="text",
                text=result.get("stdout", "") or result.get("error", "Unknown error")
            )]

        elif name == "create_coordination_task":
            args = ["--title", arguments["title"]]

            if "description" in arguments:
                args.extend(["--desc", arguments["description"]])
            if "priority" in arguments:
                args.extend(["--priority", str(arguments["priority"])])
            if "assign_to" in arguments:
                args.extend(["--assign", arguments["assign_to"]])
            if "tags" in arguments:
                args.extend(["--tags", arguments["tags"]])

            result = run_script("create-task.sh", args)

            return [TextContent(
                type="text",
                text=result.get("stdout", "") or result.get("error", "Unknown error")
            )]

        elif name == "accept_coordination_task":
            result = run_script("accept-task.sh", [arguments["task_id"]])

            return [TextContent(
                type="text",
                text=result.get("stdout", "") or result.get("error", "Unknown error")
            )]

        elif name == "complete_coordination_task":
            args = [arguments["task_id"]]
            if "comment" in arguments:
                args.append(arguments["comment"])

            result = run_script("complete-task.sh", args)

            return [TextContent(
                type="text",
                text=result.get("stdout", "") or result.get("error", "Unknown error")
            )]

        elif name == "check_environment_status":
            state = read_json_file(STATE_FILE)
            env = arguments["environment"]

            if "environments" in state and env in state["environments"]:
                env_data = state["environments"][env]

                status_text = f"""
Environment: {env}
Status: {env_data.get('status', 'unknown')}
Current Task: {env_data.get('currentTask') or 'none'}
Last Seen: {env_data.get('lastSeen') or 'never'}
Branch: {env_data.get('branch', 'unknown')}
Commit: {env_data.get('commit', 'unknown')}
Region: {env_data.get('region', 'unknown')}
                """.strip()

                return [TextContent(type="text", text=status_text)]
            else:
                return [TextContent(
                    type="text",
                    text=f"Environment not found: {env}"
                )]

        elif name == "sync_coordination_state":
            # Run sync-all.sh
            result = run_script("sync-all.sh")

            output = result.get("stdout", "")

            # Also sync to ChromaDB if requested
            if arguments.get("include_chromadb", True):
                chromadb_result = run_script("chromadb-sync.py", ["sync"])
                output += "\n" + chromadb_result.get("stdout", "")

            return [TextContent(type="text", text=output)]

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
