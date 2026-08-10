#!/usr/bin/env python3
"""Render the generated sections of docs/context/ from the repo itself.

Each block is delimited by BEGIN/END markers. Prose outside the markers is never
touched, and hand-written text *inside* a block is preserved across runs, keyed
by the row it belongs to — so the enumeration stays true to disk while the
editorial voice stays human.

That hand-written text lives nowhere else, so wiping a block would destroy it.
Before writing, each block is compared against the last committed version: if a
row that still exists on disk has lost its prose, the run stops unless --force.

Add a block by appending to BLOCKS. Everything else is shared.
"""

from __future__ import annotations

import argparse
import difflib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTEXT = ROOT / "docs" / "context"

# --------------------------------------------------------------------------
# apps — kubernetes/apps/{ns}/{app}/ks.yaml
# --------------------------------------------------------------------------

# Rendered in this order regardless of declaration order, so flags read the same
# everywhere. oidc is last: it is not a component, it is a CR in the app dir.
FLAG_ORDER = ["kopiur", "cnpg", "auth", "zeroscaler", "oidc"]
COMPONENT_FLAGS = {
    "kopiur": r"components/kopiur/backup\b",
    "cnpg": r"components/cnpg\b",
    "auth": r"components/auth\b",
    "zeroscaler": r"components/zeroscaler\b",
}

APP_RE = re.compile(r"^- (?P<key>\S+)(?P<rest>.*)$")
DESC_RE = re.compile(r"_\((?P<text>.*)\)_")


def apps_scan() -> dict[str, dict[str, list[str]]]:
    found: dict[str, dict[str, list[str]]] = {}
    for ks in (ROOT / "kubernetes" / "apps").glob("*/**/ks.yaml"):
        rel = ks.parent.relative_to(ROOT / "kubernetes" / "apps")
        namespace, app = rel.parts[0], "/".join(rel.parts[1:])
        if not app:
            continue
        text = ks.read_text()
        flags = [f for f, pat in COMPONENT_FLAGS.items() if re.search(pat, text)]
        if any(ks.parent.glob("**/pocketidoidcclient*.yaml")):
            flags.append("oidc")
        found.setdefault(namespace, {})[app] = sorted(flags, key=FLAG_ORDER.index)
    return found


def apps_keys() -> set[str]:
    return {f"{ns}/{app}" for ns, apps in apps_scan().items() for app in apps}


def apps_keep(block: list[str]) -> dict[str, str]:
    """namespace/app -> hand-written description."""
    kept: dict[str, str] = {}
    namespace = None
    for line in block:
        if line.startswith("## "):
            namespace = line[3:].strip()
        elif (m := APP_RE.match(line)) and namespace:
            if desc := DESC_RE.search(m.group("rest")):
                kept[f"{namespace}/{m.group('key')}"] = desc.group("text")
    return kept


def apps_render(kept: dict[str, str]) -> list[str]:
    found = apps_scan()
    lines: list[str] = []
    for namespace in sorted(found):
        lines += [f"## {namespace}", ""]
        for app in sorted(found[namespace]):
            parts = [f"- {app}"]
            if desc := kept.get(f"{namespace}/{app}"):
                parts.append(f"_({desc})_")
            if flags := found[namespace][app]:
                parts.append(f"[{', '.join(flags)}]")
            lines.append(" ".join(parts))
        lines.append("")
    return lines[:-1]


# --------------------------------------------------------------------------
# stacks — docker/{host}/NN-{stack}/docker-compose.yaml
# --------------------------------------------------------------------------

ROW_RE = re.compile(r"^\|\s*(?P<num>\S+)\s*\|(?P<service>[^|]*)\|\s*`(?P<file>[^`]+)`")


def stacks_scan(host: str) -> list[tuple[str, str]]:
    """(number, compose path) for each numbered stack on a host."""
    found = []
    for stack in sorted((ROOT / "docker" / host).glob("[0-9]*")):
        if (stack / "docker-compose.yaml").is_file():
            found.append((stack.name.split("-", 1)[0], f"{stack.name}/docker-compose.yaml"))
    if not found:
        sys.exit(f"docker/{host}: no numbered stacks found")
    return found


def stacks_keep(block: list[str]) -> dict[str, str]:
    """compose path -> hand-written Service cell."""
    return {
        m.group("file"): m.group("service").strip()
        for line in block
        if (m := ROW_RE.match(line))
    }


def stacks_keys(host: str):
    return lambda: {path for _, path in stacks_scan(host)}


def stacks_render(host: str):
    def render(kept: dict[str, str]) -> list[str]:
        rows = [(num, kept.get(path, ""), f"`{path}`") for num, path in stacks_scan(host)]
        header = ("#", "Service", "Compose file")
        # Floor of 3 matches prettier's minimum separator width, so formatting
        # the file on save doesn't fight the generator.
        width = [max(3, *(len(r[i]) for r in [header, *rows])) for i in range(3)]
        out = ["| " + " | ".join(header[i].ljust(width[i]) for i in range(3)) + " |"]
        out.append("| " + " | ".join("-" * width[i] for i in range(3)) + " |")
        out += ["| " + " | ".join(r[i].ljust(width[i]) for i in range(3)) + " |" for r in rows]
        return out

    return render


# --------------------------------------------------------------------------
# registry
# --------------------------------------------------------------------------

BLOCKS = [
    ("02_apps_inventory.md", "apps", apps_keep, apps_render, apps_keys),
    ("07_docker_hosts.md", "stacks:truenas", stacks_keep, stacks_render("truenas"), stacks_keys("truenas")),
    ("07_docker_hosts.md", "stacks:clonenas", stacks_keep, stacks_render("clonenas"), stacks_keys("clonenas")),
    ("07_docker_hosts.md", "stacks:vps", stacks_keep, stacks_render("vps"), stacks_keys("vps")),
]


def block_of(doc: str, name: str, required: bool = True) -> list[str] | None:
    begin, end = f"<!-- BEGIN GENERATED: {name} -->", f"<!-- END GENERATED: {name} -->"
    lines = doc.split("\n")
    try:
        return lines[lines.index(begin) + 1 : lines.index(end)]
    except ValueError:
        # A committed version predating the markers has no block to compare against.
        if not required:
            return None
        sys.exit(f"missing {begin} / {end} markers")


def splice(doc: str, name: str, body: list[str]) -> str:
    begin, end = f"<!-- BEGIN GENERATED: {name} -->", f"<!-- END GENERATED: {name} -->"
    lines = doc.split("\n")
    start, stop = lines.index(begin), lines.index(end)
    return "\n".join(lines[: start + 1] + [""] + body + [""] + lines[stop:])


def committed(filename: str) -> str | None:
    """The last committed version of a context file, or None if unavailable."""
    rel = (CONTEXT / filename).relative_to(ROOT)
    result = subprocess.run(
        ["git", "show", f"HEAD:{rel}"],
        cwd=ROOT, capture_output=True, text=True,
    )
    return result.stdout if result.returncode == 0 else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if a committed file is stale, without writing",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="write even when hand-written prose would be lost",
    )
    args = parser.parse_args()

    stale = False
    for filename in dict.fromkeys(name for name, *_ in BLOCKS):
        path = CONTEXT / filename
        current = path.read_text()
        was = committed(filename)
        updated, losses = current, {}

        for target, name, keep, render, keys in BLOCKS:
            if target != filename:
                continue
            kept = keep(block_of(current, name))
            # Prose in the last commit, for a row that still exists on disk but
            # has lost its text in the working copy, is about to be destroyed.
            if was is not None and (before := block_of(was, name, required=False)):
                on_disk = keys()
                losses |= {
                    key: text
                    for key, text in keep(before).items()
                    if key in on_disk and key not in kept
                }
            updated = splice(updated, name, render(kept))

        if losses and not (args.force or args.check):
            print(f"error: {len(losses)} hand-written entries would be lost from {filename}:")
            for key, text in sorted(losses.items())[:10]:
                print(f"  {key} — {text}")
            if len(losses) > 10:
                print(f"  … and {len(losses) - 10} more")
            print(
                f"\nThe block is the only place these are stored.\n"
                f"Recover with `git checkout docs/context/{filename}`,\n"
                f"or pass --force to drop them deliberately."
            )
            return 1

        if updated == current:
            print(f"ok    docs/context/{filename}")
            continue
        if args.check:
            stale = True
            print("\n".join(difflib.unified_diff(
                current.split("\n"), updated.split("\n"),
                fromfile=f"committed/{filename}", tofile=f"disk/{filename}",
                lineterm="",
            )))
            print(f"stale docs/context/{filename}")
        else:
            path.write_text(updated)
            print(f"wrote docs/context/{filename}")

    if stale:
        print("\nRun `just docs generate` to update.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
