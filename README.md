# resume-template

Typst-based CV and resume rendering via [rendercv](https://rendercv.com).
Populated yamls live in a gitignored `personal/` directory; CI renders
PDFs on push and uploads them as workflow artifacts, which downstream
repos (e.g. portfoliorum) pull via cross-repo artifact fetch.

## What's here

```
Template_CV.yaml       academic / comprehensive starting point (sb2nov theme)
Template_Resume.yaml   industry / one-page starting point (engineeringresumes)
personal/              drop populated yamls here — gitignored
Makefile               install / cv / resume / render_all / tailor / clean
requirements.txt       rendercv[full]>=2.8
.python-version        3.13.5 (pyenv auto-switch)
.github/workflows/     renders on *.yaml push, uploads PDFs as artifacts
```

## Prerequisites

- Python **3.13+** (rendercv 2.8 requires ≥3.12). If using pyenv,
  `.python-version` will pick up `3.13.5` automatically.
- No LaTeX installation needed — rendercv v2 is Typst-based and ships
  the Typst binary as a Python dependency.

## Initial setup

```bash
make install       # creates ./resumecv venv and installs rendercv[full]
```

This produces `resumecv/bin/rendercv`. The venv is gitignored.

## Authoring a CV or resume

1. Copy a template into `personal/`, renaming with your name:

   ```bash
   cp Template_CV.yaml     personal/Firstname_Lastname_CV.yaml
   cp Template_Resume.yaml personal/Firstname_Lastname_Resume.yaml
   ```

2. Edit the `cv.*` and `design.*` fields. The two templates demonstrate
   different shapes:

   | File                    | Theme                | Pages | Typical audience          |
   |-------------------------|----------------------|-------|---------------------------|
   | `Template_CV.yaml`      | sb2nov               | 2–3   | academic, research, grad applications |
   | `Template_Resume.yaml`  | engineeringresumes   | 1     | internships, industry     |

   Keep them as **two files** rather than one — they drift in content
   (the CV keeps activities, teaching, awards; the resume trims to
   strongest experience + projects + skills).

3. Render:

   ```bash
   make cv            # every *_CV.yaml (root + personal/) → *_CV.pdf next to source
   make resume        # every *_Resume.yaml → *_Resume.pdf
   make render_all    # both
   ```

   The intermediate `rendercv_output/` directory contains the Typst
   source, Markdown export, HTML (Grammarly-friendly), and per-page PNGs.

## Schema quick reference (v2.8)

Top-level keys: `cv`, `design`, `locale`, `rendercv_settings`.

- `cv.sections` is a free-form dict; each key is an arbitrary section
  title, each value is a list of entries. Entry types: `BulletEntry`,
  `TextEntry`, `EducationEntry`, `ExperienceEntry`, `NormalEntry`,
  `OneLineEntry`, `PublicationEntry`.
- `design.theme` selects one of:
  `classic`, `ember`, `engineeringclassic`, `engineeringresumes`,
  `harvard`, `ink`, `moderncv`, `opal`, `sb2nov`. Remaining fields under
  `design.*` are theme-specific — the two templates show typical shapes.
- `locale.language` must be set (`english` is the standard choice).
- Page numbering and "last updated" notes are controlled via
  `design.templates.footer` and `design.templates.top_note` template
  strings (placeholders: `NAME`, `PAGE_NUMBER`, `TOTAL_PAGES`,
  `LAST_UPDATED`, `CURRENT_DATE`).

Full field docs: <https://docs.rendercv.com/user_guide/yaml_input_structure/>

## Tailoring

Position-specific resumes are **derived** from the base CV via a projection
spec. The CV is the SSOT for content; projection specs subtract, reorder,
and optionally replace highlights — they never invent content. If a spec
needs a claim that isn't in the CV, the CV gets updated first.

### Workflow

1. Author a projection spec at `personal/tailorings/<name>.projection.yaml`
   (or `tailorings/<name>.projection.yaml` for shareable examples).
2. `make tailor TARGET=<name>` — runs `scripts/tailor.py` to emit the
   derived yaml at the path declared in the spec's `output:` field, then
   renders it to PDF alongside.

### Spec anatomy

```yaml
base:   personal/Gregory_Sinaga_CV.yaml
output: personal/Gregory_Sinaga_<Target>_Resume.yaml

cv_overrides: {location: "City, State"}   # optional — shallow-merged

sections:
  education: all                          # keep verbatim
  research_experience: all
  experience:
    include:
      - "Company / Position"              # allowlist by match_key
    max_highlights_per_entry: 3
    highlight_augments:
      - match: "Company / Position"
        replace_highlights: ["..."]       # or prepend_highlights / append_highlights

design: {theme: engineeringresumes, ...}  # replaces base.design entirely
locale: {language: english}
```

Match-key format by section type: see `scripts/tailor.py` module docstring.

### What the script does (and doesn't)

- **Does:** subtract sections, subtract entries, order sections per spec,
  cap highlights, replace/prepend highlights on matched entries, merge
  `cv_overrides`, replace `design` and `locale`.
- **Doesn't:** invent content, rewrite tone, reorder entries within a
  kept allowlist beyond the order you specify, or call an LLM. The
  pipeline is deterministic and reproducible — same CV + same spec
  produces the same derived yaml, byte-for-byte.

### career-ops connection

The seed at `ROADMAP_MASTER.md` #224 is the "PLAI career-ops branch"
vision: LLM-driven CV-to-JD matching that produces projection specs
automatically. This repo implements the *rendering* half; the LLM-authored
*specification* half can layer on later (see PLAI ideas_inbox seed
2026-04-23 on adapter + prompt vendoring from santifer/career-ops).

## CI / cross-repo integration

`.github/workflows/render.yaml` triggers on `*.yaml` push, runs
`make cv` + `make resume`, and uploads two artifacts: `cv` and
`resume`. Downstream repos (e.g. portfoliorum) watch this workflow via
`workflow_run` and `gh run download` the artifacts into their own
deploy path.

## Cleanup

```bash
make clean         # removes rendercv_output/ and all rendered PDFs
```
