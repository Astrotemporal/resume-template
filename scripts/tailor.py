#!/usr/bin/env python3
"""Resume tailoring: projection of a base CV yaml through a tailoring spec.

Deterministic yaml → yaml. Reads a projection spec that declares which
sections, entries, and highlights survive from the base CV, with optional
design overrides and cv-field overrides. Emits a derived yaml that
``rendercv render`` can consume directly.

Design rule: the base CV is the SSOT for *content*. Projection specs
subtract, reorder, replace — never invent content. If a spec wants a
claim that isn't in the base CV, the user must first add it to the base
CV (honest-by-construction).

Usage:
    python scripts/tailor.py <target>

where <target> resolves to:
    personal/tailorings/<target>.projection.yaml     (preferred)
    tailorings/<target>.projection.yaml              (fallback, committed examples)

The projection spec declares:

    base:           path to base CV yaml (repo-relative)
    output:         path to derived yaml to write (repo-relative)
    cv_overrides:   dict shallow-merged into base.cv (e.g. override location)
    sections:       ordered dict — only these sections survive, in this order.
                    each value is either:
                        "all"                        (keep the section verbatim)
                        dict with optional keys:
                          include:                   "all" or list of match_keys
                          max_highlights_per_entry:  int
                          highlight_augments:        list of per-entry rules
                                                     (prepend_highlights / replace_highlights)
    design:         full design block that REPLACES base.design (not merged).

    match_key format by section type:
      experience / research_experience / teaching_experience / activities:
          "<company> / <position>"   (both required; exact match)
      projects:
          "<name>"                   (exact)
      certifications:
          "<company> / <position>"
      awards:
          "<name>"
      education:
          "<institution>"

See personal/tailorings/mit_ra_ji.projection.yaml for a concrete example.
"""
from __future__ import annotations

import argparse
import copy
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: PyYAML not installed. Run `make install` first.\n")
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_yaml(path: Path) -> dict:
    with path.open() as fh:
        return yaml.safe_load(fh)


def _dump_yaml(data: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as fh:
        yaml.safe_dump(
            data,
            fh,
            sort_keys=False,
            allow_unicode=True,
            width=1000,
            default_flow_style=False,
        )


def _entry_match_key(section_name: str, entry: dict) -> str:
    """Derive a match_key for filtering/augmenting entries within a section."""
    if section_name == "projects":
        return entry.get("name", "")
    if section_name == "awards":
        return entry.get("name", "")
    if section_name == "education":
        return entry.get("institution", "")
    # experience / research_experience / teaching_experience / activities /
    # certifications all share ``company`` + ``position``.
    company = entry.get("company", "")
    position = entry.get("position", "")
    if company and position:
        return f"{company} / {position}"
    return company or position or ""


def _filter_entries(
    section_name: str, entries: list[dict], include: str | list[str]
) -> list[dict]:
    if include == "all":
        return list(entries)
    if not isinstance(include, list):
        raise ValueError(
            f"section '{section_name}': include must be 'all' or list, got {type(include).__name__}"
        )
    wanted = set(include)
    kept = [e for e in entries if _entry_match_key(section_name, e) in wanted]
    found_keys = {_entry_match_key(section_name, e) for e in kept}
    missing = wanted - found_keys
    if missing:
        raise ValueError(
            f"section '{section_name}': include keys not found in base CV: {sorted(missing)}"
        )
    # Preserve the order given in ``include``.
    by_key = {_entry_match_key(section_name, e): e for e in kept}
    return [by_key[k] for k in include if k in by_key]


def _cap_highlights(entry: dict, max_n: int) -> dict:
    out = copy.deepcopy(entry)
    hl = out.get("highlights")
    if isinstance(hl, list) and len(hl) > max_n:
        out["highlights"] = hl[:max_n]
    return out


def _apply_augment(entry: dict, augment: dict) -> dict:
    """Apply prepend_highlights / replace_highlights to a single entry."""
    out = copy.deepcopy(entry)
    hl = list(out.get("highlights") or [])
    if "replace_highlights" in augment:
        hl = list(augment["replace_highlights"])
    if "prepend_highlights" in augment:
        hl = list(augment["prepend_highlights"]) + hl
    if "append_highlights" in augment:
        hl = hl + list(augment["append_highlights"])
    out["highlights"] = hl
    return out


def _augment_entries(
    section_name: str, entries: list[dict], augments: list[dict]
) -> list[dict]:
    """Apply a list of per-entry augments, matching by match_key."""
    out = [copy.deepcopy(e) for e in entries]
    for aug in augments:
        key = aug.get("match")
        if not key:
            raise ValueError(
                f"section '{section_name}' highlight_augments: every augment must have a 'match' key"
            )
        matched = False
        for i, entry in enumerate(out):
            if _entry_match_key(section_name, entry) == key:
                out[i] = _apply_augment(entry, aug)
                matched = True
                break
        if not matched:
            raise ValueError(
                f"section '{section_name}' augment match_key not found: {key!r}"
            )
    return out


def _apply_section(
    section_name: str, entries: list[dict], rules: str | dict
) -> list[dict]:
    if rules == "all":
        return list(entries)
    if not isinstance(rules, dict):
        raise ValueError(
            f"section '{section_name}': rules must be 'all' or dict, got {type(rules).__name__}"
        )
    include = rules.get("include", "all")
    filtered = _filter_entries(section_name, entries, include)
    augments = rules.get("highlight_augments") or []
    if augments:
        filtered = _augment_entries(section_name, filtered, augments)
    cap = rules.get("max_highlights_per_entry")
    if cap is not None:
        filtered = [_cap_highlights(e, cap) for e in filtered]
    return filtered


def tailor(spec_path: Path) -> Path:
    spec = _load_yaml(spec_path)

    base_rel = spec.get("base")
    if not base_rel:
        raise ValueError(f"{spec_path}: missing required field 'base'")
    output_rel = spec.get("output")
    if not output_rel:
        raise ValueError(f"{spec_path}: missing required field 'output'")

    base_path = (REPO_ROOT / base_rel).resolve()
    output_path = (REPO_ROOT / output_rel).resolve()

    base = _load_yaml(base_path)
    if "cv" not in base:
        raise ValueError(f"{base_path}: not a rendercv yaml (missing 'cv' key)")

    out: dict = {"cv": copy.deepcopy(base["cv"])}

    # cv shallow-merge overrides (name, location, email, phone, etc.)
    cv_overrides = spec.get("cv_overrides") or {}
    if cv_overrides:
        for k, v in cv_overrides.items():
            out["cv"][k] = v

    # Section projection
    base_sections = base["cv"].get("sections") or {}
    spec_sections = spec.get("sections")
    if spec_sections is not None:
        out_sections: dict = {}
        for sec_name, rules in spec_sections.items():
            if sec_name not in base_sections:
                raise ValueError(
                    f"{spec_path}: section '{sec_name}' not found in base CV. "
                    f"Base sections: {sorted(base_sections.keys())}"
                )
            out_sections[sec_name] = _apply_section(
                sec_name, base_sections[sec_name], rules
            )
        out["cv"]["sections"] = out_sections

    # Design replacement (NOT merge — resume and CV use different themes)
    if "design" in spec:
        out["design"] = spec["design"]
    elif "design" in base:
        out["design"] = base["design"]

    # Locale propagation
    if "locale" in spec:
        out["locale"] = spec["locale"]
    elif "locale" in base:
        out["locale"] = base["locale"]

    # Provenance banner (comment block prepended to the output file below)
    _dump_yaml(out, output_path)
    _prepend_provenance(output_path, spec_path, base_path)
    return output_path


def _prepend_provenance(output_path: Path, spec_path: Path, base_path: Path) -> None:
    banner = (
        "# ==========================================================================\n"
        "# GENERATED by scripts/tailor.py — DO NOT EDIT BY HAND.\n"
        f"# Base CV:         {base_path.relative_to(REPO_ROOT) if base_path.is_relative_to(REPO_ROOT) else base_path}\n"
        f"# Projection spec: {spec_path.relative_to(REPO_ROOT) if spec_path.is_relative_to(REPO_ROOT) else spec_path}\n"
        "# Re-run:          make tailor TARGET=<name>\n"
        "# ==========================================================================\n"
    )
    body = output_path.read_text()
    output_path.write_text(banner + body)


def _resolve_spec(target: str) -> Path:
    candidates = [
        REPO_ROOT / "personal" / "tailorings" / f"{target}.projection.yaml",
        REPO_ROOT / "tailorings" / f"{target}.projection.yaml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    sys.stderr.write(
        f"ERROR: no projection spec found for target '{target}'.\nLooked in:\n"
    )
    for c in candidates:
        sys.stderr.write(f"  - {c}\n")
    sys.exit(2)


def main() -> None:
    ap = argparse.ArgumentParser(description="Project a base CV yaml through a tailoring spec.")
    ap.add_argument("target", help="Spec name (without .projection.yaml suffix).")
    args = ap.parse_args()

    spec_path = _resolve_spec(args.target)
    output = tailor(spec_path)
    rel = output.relative_to(REPO_ROOT) if output.is_relative_to(REPO_ROOT) else output
    print(f"tailor: wrote {rel}")


if __name__ == "__main__":
    main()
