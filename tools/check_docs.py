#!/usr/bin/env python3
"""riscv64xO3 docs guardrails: branding, links, status words."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
# Split to keep this file itself grep-clean for the old brand.
FORBIDDEN = ["Iron" + "Core", "iron" + "core"]
ERRORS = []


def check_forbidden():
    me = pathlib.Path(__file__).name
    for p in ROOT.rglob("*"):
        if (
            ".git" in p.parts
            or "riscv-tests" in p.parts
            or "node_modules" in p.parts
            or "dist" in p.parts
            or ".astro" in p.parts
            or p.name == me
        ):
            continue
        if p.is_file() and p.suffix in {".md", ".mdx", ".adoc", ".sv", ".py", ".tcl", ".yaml", ".yml", ".html", ".js", ".mjs"}:
            try:
                t = p.read_text(errors="ignore")
            except Exception:
                continue
            for w in FORBIDDEN:
                if w in t:
                    ERRORS.append(f"{p.relative_to(ROOT)}: forbidden '{w}'")


def check_web_relative():
    web = ROOT / "web"
    # Astro source: links must be relative (no leading /). Built dist/ is skipped.
    for ext in ("*.md", "*.mdx", "*.mjs", "*.astro"):
        for p in web.rglob(ext):
            if "node_modules" in p.parts or "dist" in p.parts or ".astro" in p.parts:
                continue
            t = p.read_text(errors="ignore")
            for m in re.finditer(r'\]\(\/(?!\/)', t):
                ERRORS.append(f"{p.relative_to(ROOT)}: root-absolute markdown link '{m.group(0)}' (use relative)")
    for p in web.rglob("*.html"):
        if "node_modules" in p.parts or "dist" in p.parts or ".astro" in p.parts:
            continue
        t = p.read_text(errors="ignore")
        for m in re.finditer(r'(src|href)="/(?!/)', t):
            ERRORS.append(f"{p.relative_to(ROOT)}: root-absolute link '{m.group(0)}' (use relative)")


def check_status_exists():
    # AsciiDoc manual is the canonical entry point; the legacy
    # docs/status.md was migrated into docs/sections/01-introduction.adoc
    # and docs/sections/09-limitations.adoc.
    if not (ROOT / "docs" / "index.adoc").exists():
        ERRORS.append("docs/index.adoc missing")
    if not (ROOT / "docs" / "sections").is_dir():
        ERRORS.append("docs/sections/ missing")
    for section in sorted((ROOT / "docs" / "sections").glob("*.adoc")):
        try:
            text = section.read_text(errors="ignore")
        except Exception:
            continue
        if "Iron" + "Core" in text or "iron" + "core" in text:
            ERRORS.append(f"{section.relative_to(ROOT)}: old brand present")


def check_includes():
    # Every sections/*.adoc file must be included from docs/index.adoc so
    # chapters cannot silently drop out of the built manual.
    index = ROOT / "docs" / "index.adoc"
    sections = ROOT / "docs" / "sections"
    if not index.exists() or not sections.is_dir():
        return
    try:
        text = index.read_text(errors="ignore")
    except Exception:
        return
    for section in sorted(sections.glob("*.adoc")):
        if f"sections/{section.name}" not in text:
            ERRORS.append(f"docs/index.adoc: missing include for sections/{section.name}")


check_forbidden()
if (ROOT / "web").exists():
    check_web_relative()
check_status_exists()
check_includes()

if ERRORS:
    print("docs guardrails FAILED:")
    for e in ERRORS:
        print(f"  - {e}")
    sys.exit(1)
print("docs guardrails OK")
