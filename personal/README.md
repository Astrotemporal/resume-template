# personal/

Drop populated yaml files here (e.g. `Firstname_Lastname_CV.yaml`,
`Firstname_Lastname_Resume.yaml`). This directory is **gitignored** —
nothing inside it is ever committed.

Use the `Template_CV.yaml` and `Template_Resume.yaml` files at the repo
root as starting points.

## Rendering

From the repo root, with the venv active:

```
make cv        # renders personal/*_CV.yaml + Template_CV.yaml
make resume    # renders personal/*_Resume.yaml + Template_Resume.yaml
make render_all
```

PDFs land next to the source yaml (inside `personal/`) and are also
gitignored. The intermediate `rendercv_output/` directory contains the
Typst source, Markdown, HTML, and PNG page previews.

## Tailoring (Stage 3 — not yet implemented)

`make tailor TARGET=<name>` will (once implemented) apply a design
overlay from `tailorings/<name>.yaml` to a base content yaml for
position-specific rendering. See the seed in ROADMAP_MASTER.md for the
career-ops branch direction.
