build-resolvers: build-resolver-linux build-resolver-darwin

.build:
	mkdir -p .build
build-resolver-darwin: .build
	cargo install heroku-nodejs-utils --root .build --bin resolve_version --git https://github.com/heroku/buildpacks-nodejs --target aarch64-apple-darwin --profile release
	mv .build/bin/resolve_version lib/vendor/resolve-version-darwin

# `cross` doesn't support the `install` command, so approximate it:
buildpacks-nodejs: .build/buildpacks-nodejs
	rm -rf .build/buildpacks-nodejs
	git clone https://github.com/heroku/buildpacks-nodejs .build/buildpacks-nodejs

build-resolver-linux: .build buildpacks-nodejs
	cd .build/buildpacks-nodejs && \
		CROSS_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_IMAGE_TOOLCHAIN="aarch64-unknown-linux-gnu" \
		CROSS_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_IMAGE="ahuszagh/aarch64-cross:aarch64-unknown-linux-musl" \
		cross build \
		--bin resolve_version \
		--target aarch64-unknown-linux-musl \
		--release -vv
	mv .build/buildpacks-nodejs/target/aarch64-unknown-linux-musl/release/resolve_version lib/vendor/resolve-version-linux

build-inventory: 
	cargo install heroku-nodejs-utils \
		--bin update_node_inventory \
		--git https://github.com/heroku/buildpacks-nodejs
	update_node_inventory ./inventory/node.toml ./CHANGELOG.md \
		--platform linux-arm64 \
		--format classic
test: heroku-22-build heroku-24-build

test-binary:
	go test -v ./cmd/... -tags=integration

shellcheck:
	@shellcheck -x bin/compile bin/detect bin/release bin/test bin/test-compile
	@shellcheck -x lib/*.sh
	@shellcheck -x ci-profile/**
	@shellcheck -x etc/**

heroku-24-build:
	@echo "Running tests in docker (heroku-24-build)..."
	@docker run --platform "linux/arm64" -v $(shell pwd):/buildpack:ro --rm -it -e "STACK=heroku-24" heroku/heroku:24-build bash -c 'cp -r /buildpack ~/buildpack_test; cd ~/buildpack_test/; test/run;'
	@echo ""

heroku-22-build:
	@echo "Running tests in docker (heroku-22-build)..."
	@docker run -v $(shell pwd):/buildpack:ro --rm -it -e "STACK=heroku-22" heroku/heroku:22-build bash -c 'cp -r /buildpack /buildpack_test; cd /buildpack_test/; test/run;'
	@echo ""

hatchet:
	@echo "Running hatchet integration tests..."
	@bash etc/ci-setup.sh
	@bash etc/hatchet.sh spec/ci/
	@echo ""

nodebin-test:
	@echo "Running test for Node v${TEST_NODE_VERSION}..."
	@bash etc/ci-setup.sh
	@bash etc/hatchet.sh spec/nodebin/
	@echo ""

unit:
	@echo "Running unit tests in docker (heroku-22)..."
	@docker run -v $(shell pwd):/buildpack:ro --rm -it -e "STACK=heroku-22" heroku/heroku:22 bash -c 'cp -r /buildpack /buildpack_test; cd /buildpack_test/; test/unit;'
	@echo ""

shell:
	@echo "Opening heroku-22 shell..."
	@docker run -v $(shell pwd):/buildpack:ro --rm -it heroku/heroku:22 bash -c 'cp -r /buildpack /buildpack_test; cd /buildpack_test/; bash'
	@echo ""
