#!/bin/bash
cd "$(dirname "$0")" || exit 1

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Установите xcodegen: brew install xcodegen"
  exit 1
fi

xcodegen generate || exit 1

if ! xcodebuild -version >/dev/null 2>&1; then
  if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi

xcodebuild -scheme test -destination 'generic/platform=iOS Simulator' build
