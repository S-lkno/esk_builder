import fnmatch

from pydantic import TypeAdapter, ValidationError

from .common import die, get_json_text
from .models import GitHubRelease


def parse_tag(tag: str) -> tuple[int, int]:
    tag = tag.strip()
    if tag[:1] in ("v", "V"):
        tag = tag[1:]
    major, minor = tag.split(".")
    return int(major), int(minor)


def asset_url(data: GitHubRelease, pattern: str) -> str:
    matches: list[tuple[str, str]] = []
    for asset in data.assets:
        if fnmatch.fnmatch(asset.name, pattern):
            matches.append((asset.name, asset.browser_download_url))

    if not matches:
        die(f"No release asset found matching pattern: {pattern}")

    if len(matches) > 1:
        names = ", ".join(name for name, _ in matches)
        die(f"Multiple release assets matched pattern {pattern}: {names}")

    return matches[0][1]


def asset_url_json(stdin_text: str, pattern: str) -> str:
    try:
        data = GitHubRelease.model_validate_json(stdin_text)
    except ValidationError as e:
        die(f"Invalid GitHub release JSON: {e}")

    return asset_url(data, pattern)


def asset_url_api(api_url: str, pattern: str) -> str:
    try:
        data = GitHubRelease.model_validate_json(get_json_text(api_url))
    except ValidationError as e:
        die(f"GitHub release API did not return a valid release object: {e}")
    return asset_url(data, pattern)


def next_tag(repo: str) -> str:
    try:
        data = TypeAdapter(list[GitHubRelease]).validate_json(
            get_json_text(f"https://api.github.com/repos/{repo}/releases?per_page=100")
        )
    except ValidationError as e:
        die(f"GitHub releases API did not return a valid release list: {e}")

    tags = [item.tag_name for item in data if item.tag_name]

    if not tags:
        return "v1.0"

    latest = max(tags, key=parse_tag)
    major, minor = parse_tag(latest)

    if minor >= 9:
        major += 1
        minor = 0
    else:
        minor += 1

    return f"v{major}.{minor}"
