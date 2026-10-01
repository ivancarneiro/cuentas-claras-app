import logging
import os
import time
from typing import Any, Dict, List, Optional

import requests
from flask import Blueprint, Response, jsonify, redirect, request

from config import Config

version_bp = Blueprint("version", __name__)
logger = logging.getLogger("cuentasclaras.version")

_cache: Dict[str, Any] = {"data": None, "ts": 0}
CACHE_TTL_SECONDS = 60


def parse_version(v_str: Optional[str]) -> List[int]:
    """Parse semver string like '1.0.5', 'v1.0.5+6' into a list of integers."""
    if not v_str:
        return [0, 0, 0]
    cleaned = v_str.strip().lstrip("vV").split("+")[0].split("-")[0]
    parts: List[int] = []
    for part in cleaned.split("."):
        try:
            parts.append(int(part))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return parts[:3]


def is_newer(remote_v: str, local_v: str) -> bool:
    """Check if remote_v is strictly greater than local_v."""
    return parse_version(remote_v) > parse_version(local_v)


def get_cached_release() -> Optional[Dict[str, Any]]:
    """Fetch latest release from GitHub API with memory caching."""
    now = time.time()
    if _cache["data"] is not None and (now - _cache["ts"]) < CACHE_TTL_SECONDS:
        return _cache["data"]

    repo = getattr(Config, "GITHUB_REPO", "ivancarneiro/cuentas-claras-app")
    token = getattr(Config, "GITHUB_TOKEN", None) or os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")

    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "CuentasClarasApp",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    url = f"https://api.github.com/repos/{repo}/releases/latest"
    try:
        resp = requests.get(url, headers=headers, timeout=8)
        if resp.status_code == 200:
            data = resp.json()
            _cache["data"] = data
            _cache["ts"] = now
            return data
        else:
            logger.warning(
                "GitHub releases API returned status=%d for repo=%s",
                resp.status_code,
                repo,
            )
    except Exception as e:
        logger.error("Exception fetching latest release from GitHub: %s", e)

    return _cache["data"]


@version_bp.route("/latest", methods=["GET"])
def check_latest_version():
    """
    Check if a newer version of the application is available.
    Accepts `current_version` query parameter (e.g. ?current_version=1.0.4).
    """
    current_version = request.args.get("current_version", "").strip()
    release = get_cached_release()

    default_version = getattr(Config, "LATEST_APP_VERSION", "1.0.5")
    latest_version_tag = default_version
    release_name = f"Cuentas Claras v{default_version}"
    release_notes = ""
    published_at = None
    apk_filename = f"cuentas-claras-v{default_version}.apk"
    apk_size = None

    if release:
        tag_name = release.get("tag_name", default_version)
        latest_version_tag = tag_name.lstrip("vV")
        release_name = release.get("name", release_name)
        release_notes = release.get("body", "")
        published_at = release.get("published_at")

        assets = release.get("assets", [])
        apk_asset = next((a for a in assets if a.get("name", "").endswith(".apk")), None)
        if apk_asset:
            apk_filename = apk_asset.get("name", apk_filename)
            apk_size = apk_asset.get("size")

    update_required = False
    if current_version:
        update_required = is_newer(latest_version_tag, current_version)

    download_url = f"{request.host_url.rstrip('/')}/api/version/download"

    return jsonify(
        {
            "latest_version": latest_version_tag,
            "current_version": current_version or None,
            "update_required": update_required,
            "download_url": download_url,
            "apk_filename": apk_filename,
            "apk_size": apk_size,
            "release_name": release_name,
            "release_notes": release_notes,
            "published_at": published_at,
        }
    )


@version_bp.route("/download", methods=["GET"])
def download_apk():
    """
    Proxies/redirects to the APK asset download using server authentication.
    Works seamlessly with private GitHub repositories without exposing credentials.
    """
    release = get_cached_release()

    repo = getattr(Config, "GITHUB_REPO", "ivancarneiro/cuentas-claras-app")
    token = getattr(Config, "GITHUB_TOKEN", None) or os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")

    if release:
        assets = release.get("assets", [])
        apk_asset = next((a for a in assets if a.get("name", "").endswith(".apk")), None)
        if apk_asset and token:
            asset_id = apk_asset.get("id")
            gh_asset_url = f"https://api.github.com/repos/{repo}/releases/assets/{asset_id}"
            headers = {
                "Authorization": f"Bearer {token}",
                "Accept": "application/octet-stream",
                "User-Agent": "CuentasClarasApp",
            }
            try:
                # GitHub will reply with 302 Found and a temporary pre-signed AWS S3 URL in Location
                resp = requests.get(gh_asset_url, headers=headers, allow_redirects=False, timeout=12)
                if resp.status_code in (301, 302, 307, 308) and "Location" in resp.headers:
                    return redirect(resp.headers["Location"], code=302)
                elif resp.status_code == 200:
                    return Response(
                        resp.iter_content(chunk_size=16384),
                        content_type="application/vnd.android.package-archive",
                        headers={
                            "Content-Disposition": f"attachment; filename={apk_asset.get('name', 'cuentas-claras.apk')}"
                        },
                    )
            except Exception as e:
                logger.error("Error redirecting to GitHub release asset: %s", e)

        if apk_asset and apk_asset.get("browser_download_url"):
            return redirect(apk_asset["browser_download_url"], code=302)

    # Fallback to direct release URL on GitHub
    fallback_url = f"https://github.com/{repo}/releases/latest"
    return redirect(fallback_url, code=302)
