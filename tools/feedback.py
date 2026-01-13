#!/usr/bin/env python3
"""
Feedback System for Spectrum Protocol 2026
Supports Discord, Slack, Email, and custom webhooks
"""

import os
import sys
import json
import requests
from datetime import datetime
from typing import Optional, Dict, Any
from enum import Enum

class FeedbackLevel(Enum):
    """Feedback severity levels"""
    INFO = "info"
    SUCCESS = "success"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"

class FeedbackChannel(Enum):
    """Available feedback channels"""
    DISCORD = "discord"
    SLACK = "slack"
    EMAIL = "email"
    WEBHOOK = "webhook"

# Configuration from environment
DISCORD_WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL", "")
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
EMAIL_TO = os.getenv("EMAIL_TO", "")
CUSTOM_WEBHOOK_URL = os.getenv("CUSTOM_WEBHOOK_URL", "")

# Environment info
ENVIRONMENT = os.getenv("ENVIRONMENT", "production")
PROJECT_NAME = "Spectrum Protocol 2026"

def get_emoji(level: FeedbackLevel) -> str:
    """Get emoji for feedback level"""
    emojis = {
        FeedbackLevel.INFO: "ℹ️",
        FeedbackLevel.SUCCESS: "✅",
        FeedbackLevel.WARNING: "⚠️",
        FeedbackLevel.ERROR: "❌",
        FeedbackLevel.CRITICAL: "🚨"
    }
    return emojis.get(level, "📢")

def get_color(level: FeedbackLevel) -> int:
    """Get Discord embed color for feedback level"""
    colors = {
        FeedbackLevel.INFO: 3447003,      # Blue
        FeedbackLevel.SUCCESS: 3066993,   # Green
        FeedbackLevel.WARNING: 16776960,  # Yellow
        FeedbackLevel.ERROR: 15158332,    # Red
        FeedbackLevel.CRITICAL: 10038562  # Dark red
    }
    return colors.get(level, 0)

def send_discord(
    title: str,
    message: str,
    level: FeedbackLevel = FeedbackLevel.INFO,
    fields: Optional[Dict[str, str]] = None
) -> bool:
    """Send feedback to Discord webhook"""
    if not DISCORD_WEBHOOK_URL:
        return False

    try:
        embed = {
            "title": f"{get_emoji(level)} {title}",
            "description": message,
            "color": get_color(level),
            "timestamp": datetime.utcnow().isoformat(),
            "footer": {
                "text": f"{PROJECT_NAME} - {ENVIRONMENT}"
            }
        }

        if fields:
            embed["fields"] = [
                {"name": k, "value": v, "inline": True}
                for k, v in fields.items()
            ]

        payload = {
            "embeds": [embed],
            "username": PROJECT_NAME
        }

        response = requests.post(
            DISCORD_WEBHOOK_URL,
            json=payload,
            timeout=10
        )
        response.raise_for_status()
        return True

    except Exception as e:
        print(f"Discord error: {e}", file=sys.stderr)
        return False

def send_slack(
    title: str,
    message: str,
    level: FeedbackLevel = FeedbackLevel.INFO,
    fields: Optional[Dict[str, str]] = None
) -> bool:
    """Send feedback to Slack webhook"""
    if not SLACK_WEBHOOK_URL:
        return False

    try:
        color_map = {
            FeedbackLevel.INFO: "#36a64f",
            FeedbackLevel.SUCCESS: "#2eb886",
            FeedbackLevel.WARNING: "#ffcc00",
            FeedbackLevel.ERROR: "#ff0000",
            FeedbackLevel.CRITICAL: "#8b0000"
        }

        attachment = {
            "fallback": f"{title}: {message}",
            "color": color_map.get(level, "#cccccc"),
            "title": f"{get_emoji(level)} {title}",
            "text": message,
            "footer": f"{PROJECT_NAME} - {ENVIRONMENT}",
            "ts": int(datetime.utcnow().timestamp())
        }

        if fields:
            attachment["fields"] = [
                {"title": k, "value": v, "short": True}
                for k, v in fields.items()
            ]

        payload = {
            "attachments": [attachment]
        }

        response = requests.post(
            SLACK_WEBHOOK_URL,
            json=payload,
            timeout=10
        )
        response.raise_for_status()
        return True

    except Exception as e:
        print(f"Slack error: {e}", file=sys.stderr)
        return False

def send_email(
    title: str,
    message: str,
    level: FeedbackLevel = FeedbackLevel.INFO,
    fields: Optional[Dict[str, str]] = None
) -> bool:
    """Send feedback via email"""
    if not all([SMTP_USER, SMTP_PASSWORD, EMAIL_TO]):
        return False

    try:
        import smtplib
        from email.mime.text import MIMEText
        from email.mime.multipart import MIMEMultipart

        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = f"{get_emoji(level)} {PROJECT_NAME}: {title}"
        msg['From'] = SMTP_USER
        msg['To'] = EMAIL_TO

        # HTML body
        html = f"""
        <html>
            <body>
                <h2>{get_emoji(level)} {title}</h2>
                <p><strong>Level:</strong> {level.value.upper()}</p>
                <p><strong>Environment:</strong> {ENVIRONMENT}</p>
                <p><strong>Message:</strong></p>
                <p>{message}</p>
        """

        if fields:
            html += "<h3>Details:</h3><ul>"
            for key, value in fields.items():
                html += f"<li><strong>{key}:</strong> {value}</li>"
            html += "</ul>"

        html += f"""
                <hr>
                <p><small>Sent from {PROJECT_NAME} Feedback System</small></p>
            </body>
        </html>
        """

        msg.attach(MIMEText(html, 'html'))

        # Send email
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, EMAIL_TO, msg.as_string())

        return True

    except Exception as e:
        print(f"Email error: {e}", file=sys.stderr)
        return False

def send_webhook(
    title: str,
    message: str,
    level: FeedbackLevel = FeedbackLevel.INFO,
    fields: Optional[Dict[str, str]] = None
) -> bool:
    """Send feedback to custom webhook"""
    if not CUSTOM_WEBHOOK_URL:
        return False

    try:
        payload = {
            "title": title,
            "message": message,
            "level": level.value,
            "environment": ENVIRONMENT,
            "project": PROJECT_NAME,
            "timestamp": datetime.utcnow().isoformat(),
            "fields": fields or {}
        }

        response = requests.post(
            CUSTOM_WEBHOOK_URL,
            json=payload,
            timeout=10
        )
        response.raise_for_status()
        return True

    except Exception as e:
        print(f"Webhook error: {e}", file=sys.stderr)
        return False

def send_feedback(
    title: str,
    message: str,
    level: FeedbackLevel = FeedbackLevel.INFO,
    fields: Optional[Dict[str, str]] = None,
    channels: Optional[list] = None
) -> Dict[str, bool]:
    """
    Send feedback to multiple channels

    Args:
        title: Feedback title
        message: Feedback message
        level: Severity level
        fields: Additional fields
        channels: List of channels to send to (None = all configured)

    Returns:
        Dict of channel: success status
    """
    results = {}

    if channels is None:
        # Try all configured channels
        if DISCORD_WEBHOOK_URL:
            results['discord'] = send_discord(title, message, level, fields)
        if SLACK_WEBHOOK_URL:
            results['slack'] = send_slack(title, message, level, fields)
        if all([SMTP_USER, SMTP_PASSWORD, EMAIL_TO]):
            results['email'] = send_email(title, message, level, fields)
        if CUSTOM_WEBHOOK_URL:
            results['webhook'] = send_webhook(title, message, level, fields)
    else:
        # Send to specified channels
        for channel in channels:
            if channel == 'discord':
                results['discord'] = send_discord(title, message, level, fields)
            elif channel == 'slack':
                results['slack'] = send_slack(title, message, level, fields)
            elif channel == 'email':
                results['email'] = send_email(title, message, level, fields)
            elif channel == 'webhook':
                results['webhook'] = send_webhook(title, message, level, fields)

    # Always log to console
    print(f"[{level.value.upper()}] {title}: {message}")
    if fields:
        for key, value in fields.items():
            print(f"  {key}: {value}")

    return results

def main():
    """CLI interface for feedback system"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Send feedback via Discord, Slack, Email, or Webhook"
    )
    parser.add_argument("title", help="Feedback title")
    parser.add_argument("message", help="Feedback message")
    parser.add_argument(
        "--level",
        choices=["info", "success", "warning", "error", "critical"],
        default="info",
        help="Feedback level"
    )
    parser.add_argument(
        "--channels",
        nargs="+",
        choices=["discord", "slack", "email", "webhook"],
        help="Channels to send to (default: all configured)"
    )
    parser.add_argument(
        "--field",
        action="append",
        help="Additional field in format key:value"
    )

    args = parser.parse_args()

    # Parse fields
    fields = {}
    if args.field:
        for field in args.field:
            if ':' in field:
                key, value = field.split(':', 1)
                fields[key] = value

    # Send feedback
    level = FeedbackLevel(args.level)
    results = send_feedback(
        args.title,
        args.message,
        level,
        fields if fields else None,
        args.channels
    )

    # Print results
    print("\nResults:")
    for channel, success in results.items():
        status = "✅" if success else "❌"
        print(f"  {status} {channel}")

    # Exit with error if all failed
    if not any(results.values()):
        sys.exit(1)

if __name__ == "__main__":
    main()
