.PHONY: setup doctor test
UV ?= uv
PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PYTHON ?= python3
RUN_PYTHON = $(UV) run --locked --project "$(PROJECT_ROOT)" $(PYTHON)
setup:
	$(UV) sync --locked --project "$(PROJECT_ROOT)"
	$(RUN_PYTHON) -c "import sys; assert sys.version_info >= (3, 11), 'Python 3.11+ required'; print('PASS setup: standard-library starter, no packages required')"
doctor: setup
	@echo "Scaffold only: see README for implementation prerequisites."
test:
	@echo "NOT IMPLEMENTED: this repository is a scaffold; no component test exists yet."
	@exit 2
