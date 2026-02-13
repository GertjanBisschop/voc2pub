DATA_FILES := $(sort $(wildcard dropbox/*.yaml))

SCHEMA=schema/schema.yaml
OUT_FOLDER=build
ONTOLOGY_LABEL=terms.ttl
UNPUBLISHED_FOLDER=unpublished
ARCHIVE_FOLDER=archive
COMBINED_DATA=$(OUT_FOLDER)/combined.yaml

print-data:
	@echo $(DATA_FILES)

prepare:
	kdir -p $(OUT_FOLDER)
	mkdir -p $(UNPUBLISHED_FOLDER)
	mkdir -p $(ARCHIVE_FOLDER)

aggregate:
	yq eval-all '. as $$item ireduce ({}; . * $$item )' \
		$(DATA_FILES) > $(COMBINED_DATA)

mint: aggregate
	uv run pubmate-mint \
		--data $(COMBINED_DATA) \
		--target matrix_subclasses \
		--namespace "http://w3id.org/peh/matrices/" \
		--verbose \
		--force \
		--preflabel label \
		$(DRY)

build:
	uv run linkml-convert \
		--target-class Container \
		-s $(SCHEMA) \
		-o $(OUT_FOLDER)/$(ONTOLOGY_LABEL) \
		$(COMBINED_DATA)

graph2assertions: | $(UNPUBLISHED_FOLDER)
	uv run pubmate-cleanrdf \
		--input-ontology-path $(OUT_FOLDER)/$(ONTOLOGY_LABEL) \
		--base-namespace http://w3id.org/peh/terms/ \
		--term-output-path $(UNPUBLISHED_FOLDER) \
		--term-parent-class http://w3id.org/peh/terms/Matrix

pipeline: prepare mint build graph2assertions

