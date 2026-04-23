DROPBOX_FOLDER ?= dropbox
UNPUBLISHED_FOLDER ?= unpublished
PUBLISHED_FOLDER ?= published
ARCHIVE_FOLDER ?= archive
SCHEMA ?= schema/schema.yaml
OUT_FOLDER ?= build
ONTOLOGY_LABEL ?= terms.ttl
TARGET_CLASS ?= matrix_subclasses
BASE_NAMESPACE ?= http://w3id.org/peh/terms/
TERM_PARENT_CLASS ?= http://w3id.org/peh/terms/Matrix
MINT_NAMESPACE ?= http://w3id.org/peh/matrices/
COMBINED_DATA ?= $(OUT_FOLDER)/combined.yaml
DRY ?=

DATA_FILES = $(sort $(wildcard $(DROPBOX_FOLDER)/*.yaml))

.PHONY: help print-data prepare aggregate mint build graph2assertions \
	process-dropbox archive-dropbox publish-nanopubs mark-published \
	publish-pipeline pipeline test-flow clean

help:
	@echo "Targets:"
	@echo "  make pipeline                  # process dropbox -> unpublished + archive"
	@echo "  make publish-pipeline          # publish unpublished assertions + move to published"
	@echo "  make publish-pipeline DRY=--dry-run"
	@echo "  make test-flow                 # local end-to-end dry-run test"

print-data:
	@echo "$(DATA_FILES)"

prepare:
	mkdir -p $(OUT_FOLDER) $(UNPUBLISHED_FOLDER) $(PUBLISHED_FOLDER) $(ARCHIVE_FOLDER)

aggregate: prepare
	@if [ -z "$(DATA_FILES)" ]; then \
		echo "No YAML files found in $(DROPBOX_FOLDER). Skipping aggregation."; \
		exit 0; \
	fi
	uv run pubmate-yamlconcat \
		--target $(TARGET_CLASS) \
		$(COMBINED_DATA) \
		$(DATA_FILES)

mint: aggregate
	@if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No combined YAML available. Skipping mint."; \
		exit 0; \
	fi
	uv run pubmate-mint \
		--data $(COMBINED_DATA) \
		--target $(TARGET_CLASS) \
		--namespace "$(MINT_NAMESPACE)" \
		--verbose \
		--force \
		--preflabel label \
		$(DRY)

build: mint
	@if [ ! -f "$(COMBINED_DATA)" ]; then \
		echo "No combined YAML available. Skipping RDF conversion."; \
		exit 0; \
	fi
	echo "Building $(ONTOLOGY_LABEL)"
	uv run linkml-convert \
		--target-class Container \
		-s $(SCHEMA) \
		-o $(OUT_FOLDER)/$(ONTOLOGY_LABEL) \
		$(COMBINED_DATA)
	echo "Build completed successfully for $(ONTOLOGY_LABEL)"

graph2assertions: build
	@if [ ! -f "$(OUT_FOLDER)/$(ONTOLOGY_LABEL)" ]; then \
		echo "No ontology file available. Skipping assertion extraction."; \
		exit 0; \
	fi
	uv run pubmate-cleanrdf \
		--input-ontology-path $(OUT_FOLDER)/$(ONTOLOGY_LABEL) \
		--base-namespace $(BASE_NAMESPACE) \
		--term-output-path $(UNPUBLISHED_FOLDER) \
		--term-parent-class $(TERM_PARENT_CLASS)

archive-dropbox: prepare
	@set -e; \
	files="$(DATA_FILES)"; \
	if [ -z "$$files" ]; then \
		echo "No YAML files found in $(DROPBOX_FOLDER). Nothing to archive."; \
		exit 0; \
	fi; \
	for src in $$files; do \
		name=$$(basename "$$src"); \
		dest="$(ARCHIVE_FOLDER)/$$name"; \
		if [ -e "$$dest" ]; then \
			ts=$$(date -u +%Y%m%d%H%M%S); \
			dest="$(ARCHIVE_FOLDER)/$${name%.yaml}_$$ts.yaml"; \
		fi; \
		mv "$$src" "$$dest"; \
		echo "Archived $$src -> $$dest"; \
	done

process-dropbox: graph2assertions archive-dropbox

publish-nanopubs: prepare
	@set -e; \
	files=$$(ls -1 $(UNPUBLISHED_FOLDER)/*.ttl 2>/dev/null || true); \
	if [ -z "$$files" ]; then \
		echo "No assertions found in $(UNPUBLISHED_FOLDER). Skipping nanopub publish."; \
		exit 0; \
	fi; \
	uv run pubmate-publish \
		--assertion-folder $(UNPUBLISHED_FOLDER) \
		--private-key "$$NANOPUB_PRIVATE_KEY" \
		--public-key "$$NANOPUB_PUBLIC_KEY" \
		--intro-nanopub-uri "$$INTRO_NANOPUB_URI" \
		$(DRY)

mark-published: prepare
	@if [ -n "$(DRY)" ]; then \
		echo "DRY mode enabled. Keeping assertions in $(UNPUBLISHED_FOLDER)."; \
		exit 0; \
	fi
	@set -e; \
	files=$$(ls -1 $(UNPUBLISHED_FOLDER)/*.ttl 2>/dev/null || true); \
	if [ -z "$$files" ]; then \
		echo "No assertions found in $(UNPUBLISHED_FOLDER). Nothing to move."; \
		exit 0; \
	fi; \
	for src in $$files; do \
		name=$$(basename "$$src"); \
		dest="$(PUBLISHED_FOLDER)/$$name"; \
		if [ -e "$$dest" ]; then \
			ts=$$(date -u +%Y%m%d%H%M%S); \
			dest="$(PUBLISHED_FOLDER)/$${name%.ttl}_$$ts.ttl"; \
		fi; \
		mv "$$src" "$$dest"; \
		echo "Moved $$src -> $$dest"; \
	done

publish-pipeline: publish-nanopubs mark-published
pipeline: process-dropbox

test-flow:
	$(MAKE) pipeline DRY=--dry-run
	$(MAKE) publish-pipeline DRY=--dry-run

clean:
	rm -f $(OUT_FOLDER)/* $(UNPUBLISHED_FOLDER)/*.ttl
