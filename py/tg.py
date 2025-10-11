import os
import sys
from pathlib import Path
import requests

def die(reason):
    print(f"[ERROR] {reason}", file=sys.stderr)
    sys.exit(1)

def env(name, default = None): 
    val = os.environ.get(name)
    if val is None or val == "":
        if default is not None:
            return default
        die(f"Cannot get environment variable: {name}")
    return val

BOT_TOKEN = env("TG_BOT_TOKEN")
CHAT_ID = env("TG_CHAT_ID")

def tg_api_url(method):
    return f"https://api.telegram.org/bot{BOT_TOKEN}/{method}"

def read_stdin():
    return sys.stdin.read().rstrip()

def tg_send_message(text):
    payload = {
        "chat_id": CHAT_ID,
        "parse_mode": "MarkdownV2",
        "disable_web_page_preview": "true",
        "text": text
    }
    resp = requests.post(url=tg_api_url("sendMessage"), json=payload, timeout=30)
    resp.raise_for_status()
    j = resp.json()
    if not j.get("ok"):
        die(f"sendMessage failed: {j.get('description', 'Unknown error')}")

def tg_send_document(file_path: Path, caption) -> None:
    if not file_path.exists():
        die(f"File not found: {file_path}")

    payload = {
        "chat_id": CHAT_ID,
        "parse_mode": "MarkdownV2",
        "caption": caption,
        "disable_web_page_preview": "true",
    }
    with file_path.open("rb") as f:
        r = requests.post(
            tg_api_url("sendDocument"),
            data=payload,
            files={"document": (file_path.name, f)},
            timeout=180,
        )
    r.raise_for_status()
    j = r.json()
    if not j.get("ok"):
        die(f"sendDocument failed: {j.get('description', 'Unknown error')}")

def usage() -> None:
    print(
        "Usage:\n"
        "  tg.py msg            # reads caption from stdin\n"
        "  tg.py doc <file>     # reads caption from stdin, uploads file\n",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    if len(sys.argv) < 2:
        usage()

    cmd = sys.argv[1]
    text = read_stdin()
    if not text:
        die("stdin is empty")

    if cmd == "msg":
        tg_send_message(text)
        return

    if cmd == "doc":
        if len(sys.argv) < 3:
            usage()
        tg_send_document(Path(sys.argv[2]), text)
        return

    usage()

if __name__ == "__main__":
    main()