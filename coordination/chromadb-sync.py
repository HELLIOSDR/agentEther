#!/usr/bin/env python3
"""
ChromaDB Synchronization for Claude Coordination Protocol

Syncs coordination state, tasks, and messages to ChromaDB for:
- Shared knowledge base across environments
- Quick querying via MCP Gateway
- Historical tracking and analytics
- AI-powered task/message search
"""

import json
import sys
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional

try:
    import chromadb
    from chromadb.config import Settings
except ImportError:
    print("❌ ChromaDB not installed. Install with: pip install chromadb")
    sys.exit(1)

# Configuration
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
STATE_FILE = SCRIPT_DIR / "state.json"
TASKS_FILE = SCRIPT_DIR / "tasks.json"
MESSAGES_DIR = SCRIPT_DIR / "messages"

# ChromaDB connection (from config or environment)
CHROMADB_HOST = os.getenv("CHROMADB_HOST", "localhost")
CHROMADB_PORT = int(os.getenv("CHROMADB_PORT", "8001"))

COLLECTION_NAME = "coordination_state"


class CoordinationSync:
    """Sync coordination data with ChromaDB"""

    def __init__(self):
        try:
            self.client = chromadb.HttpClient(
                host=CHROMADB_HOST,
                port=CHROMADB_PORT,
                settings=Settings(anonymized_telemetry=False)
            )
            self.collection = self.client.get_or_create_collection(
                name=COLLECTION_NAME,
                metadata={"description": "Claude Coordination Protocol state"}
            )
            print(f"✅ Connected to ChromaDB at {CHROMADB_HOST}:{CHROMADB_PORT}")
        except Exception as e:
            print(f"❌ Failed to connect to ChromaDB: {e}")
            print(f"💡 Make sure ChromaDB is running: docker compose up -d chromadb")
            sys.exit(1)

    def sync_state(self) -> bool:
        """Sync state.json to ChromaDB"""
        if not STATE_FILE.exists():
            print("⚠️  State file not found")
            return False

        try:
            with open(STATE_FILE, 'r') as f:
                state = json.load(f)

            # Store overall state
            self.collection.upsert(
                ids=["coordination_state"],
                documents=[json.dumps(state, indent=2)],
                metadatas=[{
                    "type": "state",
                    "version": state.get("version", "unknown"),
                    "last_update": state.get("lastUpdate", ""),
                    "timestamp": datetime.utcnow().isoformat()
                }]
            )

            # Store each environment's state separately for easier querying
            for env_name, env_data in state.get("environments", {}).items():
                self.collection.upsert(
                    ids=[f"env_{env_name}"],
                    documents=[json.dumps(env_data, indent=2)],
                    metadatas=[{
                        "type": "environment",
                        "environment": env_name,
                        "status": env_data.get("status", "unknown"),
                        "current_task": env_data.get("currentTask", ""),
                        "last_seen": env_data.get("lastSeen", ""),
                        "timestamp": datetime.utcnow().isoformat()
                    }]
                )

            print("✅ State synced to ChromaDB")
            return True

        except Exception as e:
            print(f"❌ Error syncing state: {e}")
            return False

    def sync_tasks(self) -> bool:
        """Sync tasks.json to ChromaDB"""
        if not TASKS_FILE.exists():
            print("⚠️  Tasks file not found")
            return False

        try:
            with open(TASKS_FILE, 'r') as f:
                tasks_data = json.load(f)

            tasks = tasks_data.get("tasks", [])

            if not tasks:
                print("ℹ️  No tasks to sync")
                return True

            # Store each task individually
            ids = []
            documents = []
            metadatas = []

            for task in tasks:
                task_id = task.get("id", "unknown")
                ids.append(f"task_{task_id}")

                # Create searchable document
                doc = f"""
Task: {task.get('title', '')}
Description: {task.get('description', '')}
Status: {task.get('status', '')}
Priority: {task.get('priority', '')}
Assigned to: {task.get('assignedTo', 'unassigned')}
Created by: {task.get('createdBy', '')}
Tags: {', '.join(task.get('tags', []))}
                """.strip()

                documents.append(doc)

                metadatas.append({
                    "type": "task",
                    "task_id": task_id,
                    "title": task.get("title", "")[:100],  # Truncate for metadata
                    "status": task.get("status", ""),
                    "priority": str(task.get("priority", "")),
                    "assigned_to": task.get("assignedTo", ""),
                    "created_by": task.get("createdBy", ""),
                    "created_at": task.get("createdAt", ""),
                    "timestamp": datetime.utcnow().isoformat()
                })

            self.collection.upsert(
                ids=ids,
                documents=documents,
                metadatas=metadatas
            )

            print(f"✅ Synced {len(tasks)} tasks to ChromaDB")
            return True

        except Exception as e:
            print(f"❌ Error syncing tasks: {e}")
            return False

    def sync_messages(self) -> bool:
        """Sync messages to ChromaDB"""
        if not MESSAGES_DIR.exists():
            print("⚠️  Messages directory not found")
            return False

        try:
            message_files = list(MESSAGES_DIR.glob("*.json"))

            if not message_files:
                print("ℹ️  No messages to sync")
                return True

            ids = []
            documents = []
            metadatas = []

            for msg_file in message_files:
                if msg_file.name == ".gitkeep":
                    continue

                with open(msg_file, 'r') as f:
                    message = json.load(f)

                msg_id = message.get("id", msg_file.stem)
                ids.append(f"msg_{msg_id}")

                # Create searchable document
                doc = f"""
From: {message.get('from', '')}
To: {message.get('to', '')}
Subject: {message.get('subject', '')}
Body: {message.get('body', '')}
Priority: {message.get('priority', 'normal')}
                """.strip()

                documents.append(doc)

                metadatas.append({
                    "type": "message",
                    "message_id": msg_id,
                    "from": message.get("from", ""),
                    "to": message.get("to", ""),
                    "subject": message.get("subject", "")[:100],
                    "priority": message.get("priority", "normal"),
                    "status": message.get("status", "unread"),
                    "timestamp": message.get("timestamp", ""),
                    "synced_at": datetime.utcnow().isoformat()
                })

            self.collection.upsert(
                ids=ids,
                documents=documents,
                metadatas=metadatas
            )

            print(f"✅ Synced {len(message_files)} messages to ChromaDB")
            return True

        except Exception as e:
            print(f"❌ Error syncing messages: {e}")
            return False

    def sync_all(self) -> bool:
        """Sync everything to ChromaDB"""
        print("🔄 Syncing all coordination data to ChromaDB...")
        print("")

        success = True
        success &= self.sync_state()
        success &= self.sync_tasks()
        success &= self.sync_messages()

        print("")
        if success:
            print("✅ All coordination data synced to ChromaDB")
        else:
            print("⚠️  Some data failed to sync")

        return success

    def query(self, query_text: str, n_results: int = 5) -> List[Dict[str, Any]]:
        """Query coordination data"""
        try:
            results = self.collection.query(
                query_texts=[query_text],
                n_results=n_results
            )

            return results

        except Exception as e:
            print(f"❌ Query failed: {e}")
            return []

    def get_stats(self) -> Dict[str, Any]:
        """Get collection statistics"""
        try:
            count = self.collection.count()

            # Count by type
            all_results = self.collection.get()
            metadatas = all_results.get("metadatas", [])

            stats = {
                "total": count,
                "states": sum(1 for m in metadatas if m.get("type") == "state"),
                "environments": sum(1 for m in metadatas if m.get("type") == "environment"),
                "tasks": sum(1 for m in metadatas if m.get("type") == "task"),
                "messages": sum(1 for m in metadatas if m.get("type") == "message"),
            }

            return stats

        except Exception as e:
            print(f"❌ Error getting stats: {e}")
            return {}


def main():
    """Main CLI"""
    import argparse

    parser = argparse.ArgumentParser(
        description="ChromaDB sync for Claude Coordination Protocol"
    )
    parser.add_argument(
        "action",
        choices=["sync", "query", "stats"],
        help="Action to perform"
    )
    parser.add_argument(
        "--query",
        type=str,
        help="Query text (for query action)"
    )
    parser.add_argument(
        "--results",
        type=int,
        default=5,
        help="Number of results (for query action)"
    )

    args = parser.parse_args()

    syncer = CoordinationSync()

    if args.action == "sync":
        syncer.sync_all()

    elif args.action == "query":
        if not args.query:
            print("❌ --query required for query action")
            sys.exit(1)

        print(f"🔍 Querying: {args.query}")
        print("")

        results = syncer.query(args.query, args.results)

        if results and results.get("ids"):
            for i, (id, doc, metadata) in enumerate(zip(
                results["ids"][0],
                results["documents"][0],
                results["metadatas"][0]
            ), 1):
                print(f"Result {i}: {id}")
                print(f"Type: {metadata.get('type', 'unknown')}")
                print(f"Score: {results.get('distances', [[]])[0][i-1] if results.get('distances') else 'N/A'}")
                print(f"Document:\n{doc[:200]}...")
                print("")
        else:
            print("No results found")

    elif args.action == "stats":
        print("📊 ChromaDB Collection Statistics")
        print("═" * 50)
        print("")

        stats = syncer.get_stats()

        print(f"Total documents: {stats.get('total', 0)}")
        print(f"  States: {stats.get('states', 0)}")
        print(f"  Environments: {stats.get('environments', 0)}")
        print(f"  Tasks: {stats.get('tasks', 0)}")
        print(f"  Messages: {stats.get('messages', 0)}")


if __name__ == "__main__":
    main()
