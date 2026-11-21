#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/phi-engine.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -module-cache-path "$CHECK_DIR/modules" "$PROJECT_DIR/PHIDailyCheck/DailyCheckEngine.swift" "$PROJECT_DIR/PHIDailyCheck/AIExplanation.swift" "$PROJECT_DIR/PHIDailyCheck/PHIChat.swift" "$PROJECT_DIR/Tests/EngineChecks.swift" -o "$CHECK_DIR/check-engine"
"$CHECK_DIR/check-engine" "$PROJECT_DIR/PHIDailyCheck/Resources/WorkshopDailySamples.json"
