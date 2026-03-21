#!/usr/bin/env python3

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional


DEFAULT_BASE_URL = "http://127.0.0.1:8731"
DEFAULT_OWNER_ID = "client-1"
DEFAULT_TOKEN_FILE = Path.home() / "Library/Application Support/CameraBridge/auth-token"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Select a CameraBridge device, start a session, capture one photo, and stop."
    )
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="CameraBridge base URL")
    parser.add_argument("--device-id", required=True, help="Device id from GET /v1/devices")
    parser.add_argument("--owner-id", default=DEFAULT_OWNER_ID, help="Owner id for session control")
    parser.add_argument(
        "--token-file",
        default=str(DEFAULT_TOKEN_FILE),
        help="Path to the CameraBridge bearer token file",
    )
    return parser.parse_args()


def load_token(token_file: str) -> str:
    env_token = os.environ.get("CAMERABRIDGE_AUTH_TOKEN")
    if env_token:
        return env_token.strip()

    token = Path(token_file).read_text(encoding="utf-8").strip()
    if not token:
        raise RuntimeError(f"Token file is empty: {token_file}")
    return token


def api_request(
    base_url: str,
    method: str,
    path: str,
    token: Optional[str] = None,
    body: Optional[dict] = None,
) -> dict:
    data = None
    headers = {"Accept": "application/json"}

    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    if token is not None:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        payload = error.read().decode("utf-8")
        raise RuntimeError(f"{method} {path} failed with {error.code}: {payload}") from error


def pretty_print(label: str, payload: dict) -> None:
    print(f"{label}:")
    print(json.dumps(payload, indent=2, sort_keys=True))


def main() -> int:
    args = parse_args()

    try:
        token = load_token(args.token_file)
    except Exception as error:
        print(f"Failed to load auth token: {error}", file=sys.stderr)
        return 1

    try:
        permissions = api_request(args.base_url, "GET", "/v1/permissions")
        devices = api_request(args.base_url, "GET", "/v1/devices")
        session_before = api_request(args.base_url, "GET", "/v1/session")

        stopped_existing_session = None
        if (
            session_before.get("state") == "running"
            and session_before.get("owner_id") == args.owner_id
        ):
            stopped_existing_session = api_request(
                args.base_url,
                "POST",
                "/v1/session/stop",
                token=token,
                body={"owner_id": args.owner_id},
            )

        select_device = api_request(
            args.base_url,
            "POST",
            "/v1/session/select-device",
            token=token,
            body={"device_id": args.device_id, "owner_id": args.owner_id},
        )
        start_session = api_request(
            args.base_url,
            "POST",
            "/v1/session/start",
            token=token,
            body={"owner_id": args.owner_id},
        )
        capture = api_request(
            args.base_url,
            "POST",
            "/v1/capture/photo",
            token=token,
            body={"owner_id": args.owner_id},
        )
        stop_session = api_request(
            args.base_url,
            "POST",
            "/v1/session/stop",
            token=token,
            body={"owner_id": args.owner_id},
        )
    except Exception as error:
        print(error, file=sys.stderr)
        return 1

    pretty_print("Permission status", permissions)
    pretty_print("Devices", devices)
    pretty_print("Initial session state", session_before)
    if stopped_existing_session is not None:
        pretty_print("Stopped existing session", stopped_existing_session)
    pretty_print("Selected device", select_device)
    pretty_print("Started session", start_session)
    pretty_print("Captured photo", capture)
    pretty_print("Stopped session", stop_session)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
