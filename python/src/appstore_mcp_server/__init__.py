"""MCP server for App Store search, rankings, and competitive analysis."""

import hashlib
import importlib.metadata
import os
import platform
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path


def _get_version():
    return importlib.metadata.version("appstore-mcp-server")


def _download_binary(version, binary_path):
    """Download the native binary from GitHub Releases with integrity verification."""
    if platform.system() != "Darwin":
        print(
            "Error: appstore-mcp-server requires macOS (Apple Silicon).",
            file=sys.stderr,
        )
        sys.exit(1)

    if platform.machine() not in ("arm64", "aarch64"):
        print(
            "Error: appstore-mcp-server requires Apple Silicon (arm64).",
            file=sys.stderr,
        )
        sys.exit(1)

    base_url = (
        f"https://github.com/drewster99/appstore-mcp-server/releases/download/"
        f"v{version}"
    )
    archive_name = f"appstore-{version}-macos-arm64.tar.gz"
    url = f"{base_url}/{archive_name}"
    checksum_url = f"{base_url}/{archive_name}.sha256"

    cache_dir = binary_path.parent
    cache_dir.mkdir(parents=True, exist_ok=True)

    tar_path = cache_dir / "download.tar.gz"

    print(f"Downloading appstore-mcp-server v{version}...", file=sys.stderr)
    try:
        urllib.request.urlretrieve(url, tar_path)
    except urllib.error.HTTPError as e:
        print(
            f"Error: Failed to download binary: {e}\n"
            f"URL: {url}\n"
            f"Ensure release v{version} exists on GitHub.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Verify SHA256 checksum
    try:
        checksum_response = urllib.request.urlopen(checksum_url)
        expected_hash = checksum_response.read().decode().strip().split()[0]

        sha256 = hashlib.sha256()
        with open(tar_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        actual_hash = sha256.hexdigest()

        if actual_hash != expected_hash:
            tar_path.unlink(missing_ok=True)
            print(
                f"Error: Checksum verification failed.\n"
                f"Expected: {expected_hash}\n"
                f"Actual:   {actual_hash}\n"
                f"The downloaded file may be corrupted or tampered with.",
                file=sys.stderr,
            )
            sys.exit(1)
    except (urllib.error.URLError, OSError):
        print(
            "Warning: Checksum file not available for this release. "
            "Skipping integrity verification.",
            file=sys.stderr,
        )

    with tarfile.open(tar_path, "r:gz") as tar:
        member = tar.getmember("appstore")
        tar.extract(member, path=cache_dir, filter="data")

    tar_path.unlink()

    binary_path.chmod(0o755)

    # Remove macOS quarantine attribute if present
    try:
        subprocess.run(
            ["xattr", "-d", "com.apple.quarantine", str(binary_path)],
            capture_output=True,
        )
    except FileNotFoundError:
        pass


def main():
    """Entry point: download binary if needed, then exec it with --mcp."""
    version = _get_version()
    cache_dir = Path.home() / ".cache" / "appstore-mcp-server" / f"v{version}"
    binary_path = cache_dir / "appstore"

    if not binary_path.exists():
        _download_binary(version, binary_path)

    # Replace this process with the native binary.
    # --mcp is auto-injected so users just run `appstore-mcp-server`.
    args = [str(binary_path), "--mcp"] + sys.argv[1:]
    os.execv(str(binary_path), args)
