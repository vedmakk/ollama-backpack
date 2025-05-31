PRODUCT_NAME := $(shell cat product_name.txt | xargs)
UPLOAD_IDENTIFIER := $(PRODUCT_NAME)
LINT_IMAGE = precommit-runner
PRECOMMIT_CACHE = $$HOME/.cache/pre-commit

DOCKER_RUN_LINT = docker run --rm -v "$$(pwd)":/project -v "$(PRECOMMIT_CACHE):/root/.cache/pre-commit" -w /project $(LINT_IMAGE)

.PHONY: build-image-lint setup lint lint-fix clean build

build-image-lint:
	docker build -t $(LINT_IMAGE) -f Dockerfile.lint .

# Setup pre-commit hook
setup: build-image-lint
	git config core.hooksPath .git-hooks
	chmod +x .git-hooks/pre-commit

# Check for linting errors and fix them.
lint:
	$(DOCKER_RUN_LINT) pre-commit run --all-files

lint-fix:
	$(DOCKER_RUN_LINT) pre-commit run --all-files --hook-stage manual


ARGS := $(filter-out build clean,$(MAKECMDGOALS))

# Clean up previous build artifacts (live-build directory and baked models)
clean:
	@if [ -d live-build ]; then cd live-build && lb clean; fi
	@rm -rf live-build/config/includes.chroot/usr/share/ollama/.ollama/models

# Remove the 'dist' directory with previously built ISOs.
clean-dist:
	@read -p "Are you sure you want to remove the 'dist' directory? [y/N] " ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		rm -rf dist && echo "'dist' directory removed."; \
	else \
		echo "Aborted."; \
	fi

# Build the ISO.
build: clean
	@bash build.sh $(ARGS)

# Generate SHA256 checksums for the ISOs.
checksums:
	cd dist && sha256sum *.iso > sha256sums.txt

# Upload the ISOs to archive.org.
upload:
	@docker build -f Dockerfile.upload -t $(PRODUCT_NAME)-upload .
	@if [ ! -f ia.ini ]; then \
		echo "ia.ini not found, running interactive configure..."; \
		docker run -it --rm -v "$$(pwd)":/app $(PRODUCT_NAME)-upload ia --config-file /app/ia.ini configure; \
	fi
	@if [ ! -d dist ] || [ -z "$$(ls dist/*.iso 2>/dev/null)" ]; then \
		echo "Error: dist directory is empty or contains no .iso files."; \
		exit 1; \
	fi
	@id=$(UPLOAD_IDENTIFIER); echo "Uploading ISO files to archive.org with identifier $$id"
	@docker run --rm \
		-v "$$(pwd)/dist":/app/dist \
		-v "$$(pwd)/ia.ini":/app/ia.ini \
		-e IA_CONFIG_FILE=/app/ia.ini \
		$(PRODUCT_NAME)-upload \
		--identifier "$(UPLOAD_IDENTIFIER)"

%:
	@:
