#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc PulsoKit/TD27File.swift PulsoKit/TD27Wave.swift TD27CoreTests/main.swift -o build/td27-core-tests
build/td27-core-tests "$@"
