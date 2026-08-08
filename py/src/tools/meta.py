from pathlib import Path

from .common import write_json_file
from .models import MetadataPayload


def write_metadata(
    output: Path,
    kernel_version: str,
    kernel_name: str,
    toolchain: str,
    package_name: str,
    variant: str,
    name: str,
    out_dir: str,
    release_repo: str,
    release_branch: str,
    kernel_commit: str,
) -> None:
    payload = MetadataPayload(
        kernel_version=kernel_version,
        kernel_name=kernel_name,
        toolchain=toolchain,
        package_name=package_name,
        variant=variant,
        name=name,
        out_dir=out_dir,
        release_repo=release_repo,
        release_branch=release_branch,
        kernel_commit=kernel_commit,
    )
    write_json_file(output, payload)
