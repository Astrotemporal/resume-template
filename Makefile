# resume-template Makefile
# ------------------------
# Local workflow:
#   make install      create venv, install rendercv[full]
#   make cv           render every *_CV.yaml (root + personal/)
#   make resume       render every *_Resume.yaml (root + personal/)
#   make render_all   render both
#   make tailor TARGET=<name>
#                     Stage 3 — not yet implemented; see README
#   make clean        remove rendercv_output/ and rendered PDFs
#
# The GitHub Actions workflow uses `make cv` and `make resume` directly.

VENV        := resumecv
PY          := $(VENV)/bin/python
RENDERCV    := $(VENV)/bin/rendercv

# Resolve a Python >=3.12 interpreter for venv creation.
# Precedence: pyenv (via .python-version), python3.13, python3.12.
# Don't trust a bare `python3` shim — PYENV_VERSION from a parent shell
# can silently point it at 3.11, which rendercv 2.4+ rejects.
PYTHON_BOOTSTRAP := $(shell \
	{ \
		if command -v pyenv >/dev/null 2>&1; then \
			unset PYENV_VERSION; \
			pyenv which python3.13 2>/dev/null \
				|| pyenv which python3.12 2>/dev/null; \
		fi; \
		command -v python3.13 2>/dev/null; \
		command -v python3.12 2>/dev/null; \
	} | head -1)

# Discover yamls at the repo root AND in personal/ (gitignored).
CV_YAMLS     := $(wildcard *_CV.yaml) $(wildcard personal/*_CV.yaml)
RESUME_YAMLS := $(wildcard *_Resume.yaml) $(wildcard personal/*_Resume.yaml)

.PHONY: install cv resume render_all tailor clean help

help:
	@echo "Targets: install | cv | resume | render_all | tailor TARGET=<name> | clean"
	@echo ""
	@echo "Discovered CV yamls:     $(CV_YAMLS)"
	@echo "Discovered resume yamls: $(RESUME_YAMLS)"
	@echo "Available tailoring specs:"
	@ls personal/tailorings/*.projection.yaml tailorings/*.projection.yaml 2>/dev/null | \
		sed 's|.*/||; s|\.projection\.yaml||' | sed 's|^|  - |' || echo "  (none)"

$(VENV)/bin/rendercv:
	@if [ -z "$(PYTHON_BOOTSTRAP)" ]; then \
		echo "ERROR: no Python >=3.12 found. Install python3.13 (e.g. \`pyenv install 3.13.5\`)."; \
		exit 1; \
	fi
	@echo "Bootstrapping venv with $(PYTHON_BOOTSTRAP)"
	"$(PYTHON_BOOTSTRAP)" -m venv $(VENV)
	$(PY) -m pip install --upgrade pip
	$(PY) -m pip install -r requirements.txt

install: $(VENV)/bin/rendercv
	@echo "rendercv installed: $$($(RENDERCV) --version 2>&1 | head -1)"

# Render each CV yaml, writing the PDF next to its source (not in rendercv_output/).
# --pdf-path is resolved RELATIVE to the input yaml's directory, so we pass
# the basename only, not the repo-relative path.
cv: $(VENV)/bin/rendercv
	@if [ -z "$(CV_YAMLS)" ]; then \
		echo "No *_CV.yaml files found (root or personal/)."; exit 0; \
	fi
	@for yaml in $(CV_YAMLS); do \
		basename=$$(basename "$$yaml" .yaml); \
		echo ">>> rendering $$yaml -> $$(dirname "$$yaml")/$$basename.pdf"; \
		$(RENDERCV) render "$$yaml" --pdf-path "$$basename.pdf" || exit 1; \
	done

resume: $(VENV)/bin/rendercv
	@if [ -z "$(RESUME_YAMLS)" ]; then \
		echo "No *_Resume.yaml files found (root or personal/)."; exit 0; \
	fi
	@for yaml in $(RESUME_YAMLS); do \
		basename=$$(basename "$$yaml" .yaml); \
		echo ">>> rendering $$yaml -> $$(dirname "$$yaml")/$$basename.pdf"; \
		$(RENDERCV) render "$$yaml" --pdf-path "$$basename.pdf" || exit 1; \
	done

render_all: cv resume

# Project the base CV yaml through a tailoring spec and render the derived PDF.
# Spec is resolved by scripts/tailor.py:
#   personal/tailorings/$(TARGET).projection.yaml   (preferred)
#   tailorings/$(TARGET).projection.yaml            (committed examples)
tailor: $(VENV)/bin/rendercv
	@if [ -z "$(TARGET)" ]; then \
		echo "usage: make tailor TARGET=<name>   (spec resolved under [personal/]tailorings/<name>.projection.yaml)"; \
		exit 2; \
	fi
	$(PY) scripts/tailor.py "$(TARGET)"
	@# Find what tailor.py just wrote (grab from the spec file) and render it.
	@spec="personal/tailorings/$(TARGET).projection.yaml"; \
	if [ ! -f "$$spec" ]; then spec="tailorings/$(TARGET).projection.yaml"; fi; \
	out=$$($(PY) -c "import yaml,sys; print(yaml.safe_load(open('$$spec'))['output'])"); \
	basename=$$(basename "$$out" .yaml); \
	echo ">>> rendering $$out -> $$(dirname "$$out")/$$basename.pdf"; \
	$(RENDERCV) render "$$out" --pdf-path "$$basename.pdf"

clean:
	rm -rf rendercv_output/
	rm -f *.pdf personal/*.pdf
