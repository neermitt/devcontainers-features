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
