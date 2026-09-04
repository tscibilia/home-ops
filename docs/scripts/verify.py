#!/usr/bin/env python3
"""Assert that the exact identifiers in docs/context/ still exist in the repo.

Not a prose linter. It checks only claims that name a real thing — a component,
a storage class, a cluster, a probe job, a substitution default, an aKeyless
path — because those are the claims that go silently wrong. Both sides of every
comparison are derived from the repo; nothing is hardcoded here.

A doc sometimes names an identifier on purpose to say it is wrong. Suppress a
single token with an HTML comment anywhere in the file:

    <!-- verify-ignore: akeyless /kubernetes/kopiur -->
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTEXT = ROOT / "docs" / "context"
COMPONENTS = ROOT / "kubernetes" / "components"

CHECKS: list[tuple[str, str, object]] = []


def check(slug: str, description: str):
    def register(fn):
        CHECKS.append((slug, description, fn))
        return fn

    return register


def context_text() -> str:
    return "\n".join(p.read_text() for p in sorted(CONTEXT.glob("*.md")))


def ignored(slug: str) -> set[str]:
    return set(re.findall(rf"<!--\s*verify-ignore:\s*{slug}\s+(\S+)\s*-->", context_text()))


def section(filename: str, heading: str) -> str:
    """The text under a heading, up to the next heading of the same level."""
    text = (CONTEXT / filename).read_text()
    match = re.search(rf"^(#+) {re.escape(heading)}\s*$", text, re.M)
    if not match:
        sys.exit(f"{filename}: no heading '{heading}'")
    rest = text[match.end():]
    nxt = re.search(rf"^#{{1,{len(match.group(1))}}} ", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def yaml_text(*globs: str) -> str:
    out = []
    for pattern in globs:
        for path in ROOT.glob(pattern):
            out.append(path.read_text())
    return "\n".join(out)


def uncommented(text: str) -> str:
    """Drop YAML comment lines — a disabled block is not a live claim."""
    return "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("#"))


@check("components", "components named in docs exist in kubernetes/components/")
def components_exist():
    on_disk = {
        str(k.parent.relative_to(COMPONENTS))
        for k in COMPONENTS.rglob("kustomization.yaml")
        if "kind: Component" in k.read_text()
    }
    table = section("components.md", "Kustomize Components") or context_text()
    named = set(re.findall(r"`([a-z]+(?:/[a-z]+)?)`", table)) & {
        *on_disk, *{f"{d}/{s}" for d in on_disk for s in ("backup", "secret")}
    }
    named |= set(re.findall(r"components/([a-z]+(?:/[a-z]+)?)\b", context_text())) & on_disk

    skip = ignored("components")
    return (
        [f"docs name components/{c}, not on disk" for c in sorted(named - on_disk - skip)]
        + [f"components/{c} exists but no context file mentions it" for c in sorted(on_disk - named - skip)]
    )


@check("storageclass", "storage classes in storage.md are referenced by a manifest")
def storage_classes():
    manifests = yaml_text("kubernetes/**/*.yaml")
    named = re.findall(r"^\| `([a-z0-9-]+)`\s*\|", section("storage.md", "Storage Classes"), re.M)
    skip = ignored("storageclass")
    return [
        f"storage.md lists `{cls}` as a storage class; no manifest mentions it"
        for cls in named if cls not in skip and cls not in manifests
    ]


def cnpg_on_disk() -> set[str]:
    """Directories that actually hold a CNPG Cluster, not every subdirectory.

    apps/database/cnpg/ also contains app/ and barman-cloud/, which are the
    operator and its plugin rather than clusters.
    """
    root = ROOT / "kubernetes" / "apps" / "database" / "cnpg"
    found = set()
    for d in sorted(root.iterdir()):
        manifest = d / "cluster.yaml"
        if d.is_dir() and manifest.exists() and re.search(r"^kind: Cluster$", manifest.read_text(), re.M):
            found.add(d.name)
    return found


def cnpg_in_table() -> set[str]:
    return set(re.findall(r"^\| `([a-z0-9-]+)`\s*\|", section("storage.md", "CNPG (PostgreSQL)"), re.M))


@check("cnpg", "CNPG cluster names in docs exist under apps/database/cnpg/")
def cnpg_clusters():
    named = cnpg_in_table()
    # "cluster" can lead or trail the name: pgsql-cluster, pgcluster-default.
    named |= set(re.findall(r"CNPG_NAME:[^\n#]*?\b([a-z0-9-]*cluster[a-z0-9-]*)\b", context_text()))
    skip = ignored("cnpg")
    return [
        f"docs name CNPG cluster `{c}`, no directory under apps/database/cnpg/"
        for c in sorted(named - cnpg_on_disk() - skip)
    ]


@check("cnpg-undocumented", "every CNPG cluster on disk is listed in storage.md")
def cnpg_clusters_documented():
    """The reverse of the check above.

    That one only proves a documented cluster exists. It says nothing about a
    cluster that exists and was never written down, which is how
    pgcluster-timescale stayed absent from storage.md from the day it was added.
    """
    skip = ignored("cnpg-undocumented")
    return [
        f"CNPG cluster `{c}` exists under apps/database/cnpg/, not in storage.md's table"
        for c in sorted(cnpg_on_disk() - cnpg_in_table() - skip)
    ]


@check("probe", "zeroscaler probe jobNames in docs exist as Probe CRs")
def probe_jobs():
    defined = set(re.findall(r"jobName:\s*([a-z_]+)", yaml_text("kubernetes/**/probes.yaml")))
    named = set(re.findall(r"`(nfs[a-z_]*probe)`", context_text()))
    named |= set(re.findall(r"ZEROSCALER_JOB_NAME:\s*([a-z_]+)", context_text()))
    skip = ignored("probe")
    return [
        f"docs name probe job `{j}`, no Probe CR declares it"
        for j in sorted(named - defined - skip)
    ]


@check("defaults", "substitution defaults in components.md match the component YAML")
def substitution_defaults():
    on_disk = dict(re.findall(
        r"\$\{([A-Z_]+):=([^}]*)\}", uncommented(yaml_text("kubernetes/components/**/*.yaml"))
    ))
    doc = (CONTEXT / "components.md").read_text()
    skip = ignored("defaults")

    failures = []
    for line in doc.split("\n"):
        row = re.match(r"^\|\s*`\$?\{?([A-Z_]+)\}?`\s*\|\s*`([^`]*)`", line)
        if row and row.group(1) in on_disk and on_disk[row.group(1)] != row.group(2):
            failures.append(
                f"{row.group(1)}: docs say `{row.group(2)}`, component says `{on_disk[row.group(1)]}`"
            )
    mentioned = set(re.findall(r"`\$?\{?([A-Z_]+)\}?`", doc))
    failures += [
        f"{v} has a default in the component YAML but components.md never mentions it"
        for v in sorted(set(on_disk) - mentioned - skip)
    ]
    return failures


@check("akeyless", "aKeyless paths named in docs are referenced by a manifest")
def akeyless_paths():
    referenced = set(re.findall(
        r"(?:key|remoteKey):\s*(/[a-z0-9/_-]+)", yaml_text("kubernetes/**/*.yaml", "docker/**/*.yaml")
    ))
    named = set(re.findall(
        r"`(/(?:kubernetes|database|security|network|observability|cloud-providers)/[a-z0-9/_-]+)`",
        context_text(),
    ))
    skip = ignored("akeyless")
    return [
        f"docs name aKeyless path `{p}`, no manifest reads or writes it"
        for p in sorted(named - referenced - skip)
    ]


def main() -> int:
    failures = 0
    for slug, description, fn in CHECKS:
        problems = fn()
        if problems:
            failures += len(problems)
            print(f"FAIL  {description}")
            for problem in problems:
                print(f"        {problem}")
            print(f"        (suppress a deliberate mention with <!-- verify-ignore: {slug} <token> -->)")
        else:
            print(f"ok    {description}")

    if failures:
        print(f"\n{failures} identifier(s) named in docs/context/ no longer resolve.")
        return 1
    print(f"\n{len(CHECKS)} checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
