export SELF ?= $(MAKE)

include Makefile.*

BASE_IMAGES := $(shell jq -r '.[]' ./.github/baseImages.json)
FEATURES := $(patsubst src/%,%,$(wildcard src/*))


## Test all devcontainers features
devcontainer/test: $(FEATURES)
	for i in ${BASE_IMAGES}; do \
		 devcontainer features test -i "$$i" .; \
	done
	@$(SELF) -s devcontainer/cleanup

## Test a devcontainers feature (e.g. gomplate, helmfile, kind)
devcontainer/test/%:
	for i in ${BASE_IMAGES}; do \
		 devcontainer features test -f $* -i "$$i" .; \
	done
	@$(SELF) -s devcontainer/cleanup


devcontainer/cleanup:
	docker ps -aq -f 'label=dev.containers.features=common' | xargs docker stop | xargs docker rm

generate/component/%:
	mkdir -p "src/$*"
	gomplate --file ./templates/src/install.sh.gotmpl --datasource component=./components/$*.yaml --out src/$*/install.sh
	gomplate --file ./templates/src/devcontainer-feature.json.gotmpl --datasource component=./components/$*.yaml --out src/$*/devcontainer-feature.json
	mkdir -p "test/$*"
	gomplate --file ./templates/test/test.sh.gotmpl --datasource component=./components/$*.yaml --out test/$*/test.sh
	gomplate --file ./templates/test/scenarios.json.gotmpl --datasource component=./components/$*.yaml --out test/$*/scenarios.json
	gomplate --file ./templates/test/all_cli_versions.sh.gotmpl --datasource component=./components/$*.yaml --out test/$*/all_cli_versions.sh
