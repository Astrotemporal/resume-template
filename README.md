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

## Tailoring (Stage 3 — planned)

Position-specific overlays for targeted applications (e.g. quantum
engineering internship vs. quantum research):

```
tailorings/
  quantum_research.yaml      # section ordering, emphasis bank, keyword bank
  quantum_eng_intern.yaml
```

`make tailor TARGET=quantum_research` will (once implemented) layer the
overlay onto a single base content yaml and render. This scaffold is the
on-ramp for the `career-ops` PLAI branch (ROADMAP_MASTER seed #224).
Currently the target prints a not-implemented message — see the seed
notes for design direction.

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
