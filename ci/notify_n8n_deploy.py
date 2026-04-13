#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from typing import Any, Optional


def getenv(name: str, default: Optional[str] = None) -> Optional[str]:
    v = os.environ.get(name)
    if v is None or v.strip() == "":
        return default
    return v


def git_out(args: list[str], cwd: str) -> Optional[str]:
    try:
        return subprocess.check_output(
            ["git", "-C", cwd] + args,
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=60,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return None


def parse_commits_file(path: Optional[str]) -> list[dict[str, Any]]:
    if not path or not os.path.isfile(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)
    except (OSError, json.JSONDecodeError):
        return []
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for c in raw:
        if not isinstance(c, dict):
            continue
        author = c.get("author") or {}
        if not isinstance(author, dict):
            author = {}
        out.append(
            {
                "id": c.get("id"),
                "message": (c.get("message") or "").strip(),
                "timestamp": c.get("timestamp"),
                "authorName": author.get("name"),
                "authorEmail": author.get("email"),
                "added": c.get("added") if isinstance(c.get("added"), list) else [],
                "modified": c.get("modified") if isinstance(c.get("modified"), list) else [],
                "removed": c.get("removed") if isinstance(c.get("removed"), list) else [],
            }
        )
    return out


def git_changed_files(repo: str, git_range: str) -> list[dict[str, str]]:
    if not git_range or ".." not in git_range:
        return []
    out = git_out(["diff", "--name-status", git_range], repo)
    if not out:
        return []
    rows: list[dict[str, str]] = []
    for line in out.splitlines():
        parts = line.split("\t", 2)
        if len(parts) >= 2:
            rows.append({"status": parts[0], "path": parts[-1]})
    return rows


def git_log_oneline(repo: str, git_range: str, limit: int = 50) -> list[dict[str, str]]:
    if not git_range or ".." not in git_range:
        return []
    fmt = "%H%x09%s%x09%an"
    log = git_out(
        ["log", f"--max-count={limit}", f"--format={fmt}", git_range],
        repo,
    )
    if not log:
        return []
    commits: list[dict[str, str]] = []
    for line in log.splitlines():
        bits = line.split("\t", 2)
        if len(bits) >= 2:
            commits.append(
                {
                    "sha": bits[0],
                    "subject": bits[1],
                    "author": bits[2] if len(bits) > 2 else "",
                }
            )
    return commits


def main() -> int:
    url = getenv("N8N_DEPLOY_WEBHOOK_URL")
    if not url:
        api = getenv("N8N_API_URL")
        if api:
            url = f"{api.rstrip('/')}/webhook/jenkins-deploy-notify"
    if not url:
        print("notify_n8n_deploy: sem URL (N8N_DEPLOY_WEBHOOK_URL ou N8N_API_URL)", file=sys.stderr)
        return 0

    infra_root = getenv("INFRA_ROOT", "/infra-deploy") or "/infra-deploy"
    app_slug = getenv("NOTIFY_APP_SLUG")
    app_repo = getenv("NOTIFY_APP_REPO_DIR")
    if not app_repo and app_slug:
        sub = getenv("NOTIFY_APP_GIT_SUBDIR") or app_slug
        cand = os.path.join(infra_root, "stacks", "apps", app_slug, sub)
        if os.path.isdir(os.path.join(cand, ".git")):
            app_repo = cand

    git_range = getenv("NOTIFY_GIT_RANGE") or getenv("DEPLOY_SUBPATH_GIT_RANGE")
    git_before = getenv("NOTIFY_GIT_BEFORE") or getenv("GIT_BEFORE")
    git_after = getenv("NOTIFY_GIT_AFTER") or getenv("GIT_AFTER")
    git_ref = getenv("NOTIFY_GIT_REF") or getenv("GIT_REF")
    repo_full = getenv("NOTIFY_REPO_FULL") or getenv("REPO_FULL")

    commits_file = getenv("NOTIFY_COMMITS_FILE") or getenv("COMMITS_PAYLOAD_FILE")
    commits_github = parse_commits_file(commits_file)

    changed_app: list[dict[str, str]] = []
    log_app: list[dict[str, str]] = []
    if app_repo and git_range:
        changed_app = git_changed_files(app_repo, git_range)
        log_app = git_log_oneline(app_repo, git_range)

    infra_sha = git_out(["rev-parse", "HEAD"], infra_root)
    infra_msg = git_out(["log", "-1", "--format=%s"], infra_root)
    infra_files: list[dict[str, str]] = []
    infra_range = getenv("NOTIFY_INFRA_GIT_RANGE")
    if infra_range and ".." in infra_range:
        infra_files = git_changed_files(infra_root, infra_range)

    payload: dict[str, Any] = {
        "source": "jenkins",
        "event": "deploy_finished",
        "jenkins": {
            "jobName": getenv("JOB_NAME"),
            "buildNumber": getenv("BUILD_NUMBER"),
            "buildUrl": getenv("BUILD_URL"),
            "buildTag": getenv("BUILD_TAG"),
            "nodeName": getenv("NODE_NAME"),
            "executorNumber": getenv("EXECUTOR_NUMBER"),
            "result": getenv("NOTIFY_BUILD_RESULT") or getenv("BUILD_RESULT") or "UNKNOWN",
            "appSlug": app_slug,
        },
        "git": {
            "ref": git_ref,
            "before": git_before,
            "after": git_after,
            "range": git_range,
            "repository": repo_full,
        },
        "commitsFromWebhook": commits_github,
        "commitsInAppRepo": log_app,
        "changedFilesApp": changed_app,
        "infra": {
            "root": infra_root,
            "revision": infra_sha,
            "lastCommitSubject": infra_msg,
            "changedFiles": infra_files,
            "gitRange": infra_range,
        },
        "message": getenv("NOTIFY_MESSAGE"),
    }

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            _ = resp.read()
    except urllib.error.HTTPError as e:
        print(f"notify_n8n_deploy: HTTP {e.code}", file=sys.stderr)
        if os.environ.get("N8N_DEPLOY_NOTIFY_FAIL_BUILD") == "1":
            return 1
        return 0
    except urllib.error.URLError as e:
        print(f"notify_n8n_deploy: {e}", file=sys.stderr)
        if os.environ.get("N8N_DEPLOY_NOTIFY_FAIL_BUILD") == "1":
            return 1
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
