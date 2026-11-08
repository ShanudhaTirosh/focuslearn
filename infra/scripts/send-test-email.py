#!/usr/bin/env python3
"""Send one test email using the SMTP settings in infra/docker/.env. Standard library only. Never prints the password.

Usage: python3 infra/scripts/send-test-email.py --to you@example.com
Options: --env PATH   settings file (default infra/docker/.env)
         --security starttls|ssl|none   (default: ssl if port 465, otherwise starttls)
         --host / --port   override for local testing
"""
import argparse
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from email.utils import formataddr, formatdate, make_msgid


def read_env(path):
    cfg = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"')
    return cfg


def build_message(cfg, to):
    sender = cfg["SMTP_ADMIN_EMAIL"]
    msg = EmailMessage()
    msg["From"] = formataddr((cfg.get("SMTP_SENDER_NAME", "FocusLearn"), sender))
    msg["To"] = to
    msg["Subject"] = "FocusLearn SMTP test"
    msg["Date"] = formatdate(localtime=False)
    msg["Message-ID"] = make_msgid(domain=sender.split("@", 1)[1])
    msg["Auto-Submitted"] = "auto-generated"
    msg.set_content("This is a test message from the FocusLearn server.\n"
                    "If you can read it, the SMTP settings work. No action is needed.\n")
    return msg


def send(cfg, to, security=None, host=None, port=None):
    host = host or cfg["SMTP_HOST"]
    port = int(port or cfg.get("SMTP_PORT", "587"))
    security = security or ("ssl" if port == 465 else "starttls")
    ctx = ssl.create_default_context()  # certificate verification stays ON
    msg = build_message(cfg, to)
    if security == "ssl":
        server = smtplib.SMTP_SSL(host, port, context=ctx, timeout=30)
    else:
        server = smtplib.SMTP(host, port, timeout=30)
    with server:
        server.ehlo()
        if security == "starttls":
            server.starttls(context=ctx)
            server.ehlo()
        if cfg.get("SMTP_USER"):
            server.login(cfg["SMTP_USER"], cfg["SMTP_PASS"])
        refused = server.send_message(msg)
    return security, refused


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--to", required=True)
    ap.add_argument("--env", default=os.path.join(here, "..", "docker", ".env"))
    ap.add_argument("--security", choices=["starttls", "ssl", "none"])
    ap.add_argument("--host")
    ap.add_argument("--port")
    a = ap.parse_args()
    cfg = read_env(a.env)
    for k in ("SMTP_ADMIN_EMAIL", "SMTP_PASS"):
        if not cfg.get(k):
            print(f"Missing {k} in {a.env}", file=sys.stderr)
            return 2
    if not (a.host or cfg.get("SMTP_HOST")):
        print("Missing SMTP_HOST", file=sys.stderr)
        return 2
    try:
        sec, refused = send(cfg, a.to, a.security, a.host, a.port)
    except Exception as e:  # report the class and message, never credentials
        print(f"FAIL  {type(e).__name__}: {e}", file=sys.stderr)
        return 1
    if refused:
        print(f"FAIL  recipient refused: {list(refused)}", file=sys.stderr)
        return 1
    print(f"OK    accepted by {a.host or cfg['SMTP_HOST']} (security={sec}). Check the inbox AND the spam folder.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
