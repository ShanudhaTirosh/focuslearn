"""Offline test: send-test-email.py against a local stub SMTP server. No network, no real credentials."""
import base64
import importlib.util
import os
import socketserver
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "send-test-email.py")
received = {"auth": None, "data": "", "mail_from": None, "rcpt": []}


class Handler(socketserver.StreamRequestHandler):
    def reply(self, s):
        self.wfile.write((s + "\r\n").encode())

    def handle(self):
        self.reply("220 stub ESMTP")
        while True:
            line = self.rfile.readline().decode(errors="replace").rstrip("\r\n")
            if not line:
                return
            up = line.upper()
            if up.startswith("EHLO"):
                self.wfile.write(b"250-stub\r\n250-AUTH PLAIN LOGIN\r\n250 8BITMIME\r\n")
            elif up.startswith("AUTH PLAIN"):
                parts = base64.b64decode(line.split(" ", 2)[2]).split(b"\0")
                received["auth"] = (parts[1].decode(), parts[2].decode())
                self.reply("235 ok")
            elif up.startswith("MAIL FROM"):
                received["mail_from"] = line
                self.reply("250 ok")
            elif up.startswith("RCPT TO"):
                received["rcpt"].append(line)
                self.reply("250 ok")
            elif up == "DATA":
                self.reply("354 go")
                buf = b""
                while not buf.endswith(b"\r\n.\r\n"):
                    buf += self.rfile.readline()
                received["data"] = buf.decode(errors="replace")
                self.reply("250 queued")
            elif up == "QUIT":
                self.reply("221 bye")
                return
            else:
                self.reply("250 ok")


def main():
    srv = socketserver.ThreadingTCPServer(("127.0.0.1", 0), Handler)
    srv.daemon_threads = True
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    secret = "S3cr3t-PASS-do-not-print"
    with tempfile.NamedTemporaryFile("w", suffix=".env", delete=False) as f:
        f.write(f'SMTP_ADMIN_EMAIL=no-reply@eduapp.example.com\nSMTP_HOST=127.0.0.1\nSMTP_PORT={port}\n'
                f'SMTP_USER=login@smtp-example.com\nSMTP_PASS={secret}\nSMTP_SENDER_NAME=FocusLearn\n')
        env = f.name
    try:
        r = subprocess.run([sys.executable, SCRIPT, "--to", "student@example.org", "--env", env, "--security", "none"],
                           capture_output=True, text=True, timeout=30)
    finally:
        os.unlink(env)
    srv.shutdown()

    failures = []
    def check(name, cond):
        print(("PASS  " if cond else "FAIL  ") + name)
        if not cond:
            failures.append(name)

    check("script exits 0", r.returncode == 0)
    check("login used the configured user and password", received["auth"] == ("login@smtp-example.com", secret))
    check("envelope sender is the configured address", "no-reply@eduapp.example.com" in (received["mail_from"] or ""))
    check("recipient accepted", any("student@example.org" in x for x in received["rcpt"]))
    check("From header has sender name", "From: FocusLearn <no-reply@eduapp.example.com>" in received["data"])
    check("Message-ID uses the sending domain", "@eduapp.example.com>" in received["data"].split("Message-ID:")[-1][:80])
    check("password never printed", secret not in r.stdout and secret not in r.stderr)

    # missing password must fail cleanly
    with tempfile.NamedTemporaryFile("w", suffix=".env", delete=False) as f:
        f.write("SMTP_ADMIN_EMAIL=a@b.c\nSMTP_HOST=127.0.0.1\n")
        env2 = f.name
    r2 = subprocess.run([sys.executable, SCRIPT, "--to", "x@y.z", "--env", env2], capture_output=True, text=True)
    os.unlink(env2)
    check("missing SMTP_PASS exits 2", r2.returncode == 2)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
