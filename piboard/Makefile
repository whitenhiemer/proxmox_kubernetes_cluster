# Makefile - Piboard build and deploy targets
#
# Build locally:     make build
# Build for Pi 3B:   make build-pi
# Deploy to Pi:      make deploy PI_HOST=pi@192.168.86.x

BINARY    := piboard
BUILD_DIR := bin

# Pi 3 Model B = ARMv7 (32-bit)
PI_GOOS   := linux
PI_GOARCH := arm
PI_GOARM  := 7

.PHONY: build build-pi run clean deploy

# Build for the current platform
build:
	go build -o $(BUILD_DIR)/$(BINARY) .

# Cross-compile for Raspberry Pi 3B (ARMv7)
build-pi:
	CGO_ENABLED=0 GOOS=$(PI_GOOS) GOARCH=$(PI_GOARCH) GOARM=$(PI_GOARM) \
		go build -ldflags="-s -w" -o $(BUILD_DIR)/$(BINARY)-arm .

# Run locally (for development / testing against Prometheus)
run: build
	$(BUILD_DIR)/$(BINARY) --config config.yaml

# Deploy binary and config to Pi, then restart services.
# Pass HA_TOKEN=<token> to write /etc/piboard/ha.env (HOME_ASSISTANT_TOKEN).
deploy: build-pi
	@if [ -z "$(PI_HOST)" ]; then echo "ERROR: set PI_HOST=pi@<ip>"; exit 1; fi
	scp $(BUILD_DIR)/$(BINARY)-arm $(PI_HOST):/tmp/piboard
	scp config.yaml $(PI_HOST):/tmp/config.yaml
	$(if $(HA_TOKEN),echo "HOME_ASSISTANT_TOKEN=$(HA_TOKEN)" | ssh $(PI_HOST) "sudo tee /etc/piboard/ha.env > /dev/null && sudo chmod 600 /etc/piboard/ha.env",)
	ssh $(PI_HOST) 'sudo install -m 755 /tmp/piboard /usr/local/bin/piboard && \
		sudo install -m 640 -o piboard -g piboard /tmp/config.yaml /etc/piboard/config.yaml && \
		sudo systemctl restart piboard'

clean:
	rm -rf $(BUILD_DIR)
