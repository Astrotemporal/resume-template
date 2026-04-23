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
cv: $(VENV)/bin/rendercv
	@if [ -z "$(CV_YAMLS)" ]; then \
		echo "No *_CV.yaml files found (root or personal/)."; exit 0; \
	fi
	@for yaml in $(CV_YAMLS); do \
		base=$${yaml%.yaml}; \
		echo ">>> rendering $$yaml -> $$base.pdf"; \
		$(RENDERCV) render "$$yaml" --pdf-path "$$base.pdf" || exit 1; \
	done

resume: $(VENV)/bin/rendercv
	@if [ -z "$(RESUME_YAMLS)" ]; then \
		echo "No *_Resume.yaml files found (root or personal/)."; exit 0; \
	fi
	@for yaml in $(RESUME_YAMLS); do \
		base=$${yaml%.yaml}; \
		echo ">>> rendering $$yaml -> $$base.pdf"; \
		$(RENDERCV) render "$$yaml" --pdf-path "$$base.pdf" || exit 1; \
	done

render_all: cv resume

# Stage 3 placeholder — see README "Tailoring" section.
tailor:
	@if [ -z "$(TARGET)" ]; then \
		echo "usage: make tailor TARGET=<name>  (e.g. quantum_research, quantum_eng_intern)"; exit 2; \
	fi
	@echo "tailor: Stage 3 not yet implemented."
	@echo "  planned: apply tailorings/$(TARGET).yaml as a --design overlay"
	@echo "  onto personal/base_content.yaml, emit personal/*_$(TARGET)_Resume.yaml,"
	@echo "  then render via \`make resume\`."
	@exit 1

clean:
	rm -rf rendercv_output/
	rm -f *.pdf personal/*.pdf
