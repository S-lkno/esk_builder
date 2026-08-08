from pathlib import Path

import requests
from pydantic import ValidationError

from .common import die, env
from .models import TelegramDocumentRequest, TelegramMessageRequest, TelegramResponse


def tg_api_url(method: str) -> str:
    return f"https://api.telegram.org/bot{env('TG_BOT_TOKEN')}/{method}"


def send_message(text: str) -> None:
    payload = TelegramMessageRequest(chat_id=env("TG_CHAT_ID"), text=text)
    try:
        response = requests.post(
            tg_api_url("sendMessage"),
            json=payload.model_dump(mode="json"),
            timeout=30,
        )
        response.raise_for_status()
    except requests.RequestException as e:
        die(f"sendMessage request failed: {e}")

    try:
        data = TelegramResponse.model_validate_json(response.text)
    except ValidationError as e:
        die(f"sendMessage returned invalid JSON: {e}")
    if not data.ok:
        die(f"sendMessage failed: {data.description or 'Unknown error'}")


def send_document(file_path: Path, caption: str) -> None:
    if not file_path.exists():
        die(f"File not found: {file_path}")

    payload = TelegramDocumentRequest(chat_id=env("TG_CHAT_ID"), caption=caption)
    with file_path.open("rb") as handle:
        try:
            response = requests.post(
                tg_api_url("sendDocument"),
                data=payload.model_dump(mode="json"),
                files={"document": (file_path.name, handle)},
                timeout=180,
            )
            response.raise_for_status()
        except requests.RequestException as e:
            die(f"sendDocument request failed: {e}")

    try:
        data = TelegramResponse.model_validate_json(response.text)
    except ValidationError as e:
        die(f"sendDocument returned invalid JSON: {e}")
    if not data.ok:
        die(f"sendDocument failed: {data.description or 'Unknown error'}")
