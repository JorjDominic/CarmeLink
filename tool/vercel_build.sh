#!/usr/bin/env bash
set -euo pipefail

# Vercel's standard build image does not include Flutter. Keep the SDK version
# pinned so production builds do not unexpectedly change with Flutter stable.
readonly CARMELINK_FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.8}"
readonly CARMELINK_FLUTTER_ROOT="${PWD}/.vercel_flutter"

if command -v flutter >/dev/null 2>&1; then
  CARMELINK_FLUTTER_BIN="$(command -v flutter)"
else
  if [[ ! -x "${CARMELINK_FLUTTER_ROOT}/bin/flutter" ]]; then
    git clone \
      --branch "${CARMELINK_FLUTTER_VERSION}" \
      --depth 1 \
      https://github.com/flutter/flutter.git \
      "${CARMELINK_FLUTTER_ROOT}"
  fi
  CARMELINK_FLUTTER_BIN="${CARMELINK_FLUTTER_ROOT}/bin/flutter"
fi

"${CARMELINK_FLUTTER_BIN}" config --no-analytics
"${CARMELINK_FLUTTER_BIN}" pub get

CARMELINK_BUILD_ARGS=(
  build web
  --release
  --target lib/main_web.dart
)

# Production defaults to the canonical domain. Set this Vercel environment
# variable when deploying previews or before the custom domain is attached.
if [[ -n "${PASSWORD_RECOVERY_REDIRECT_URL:-}" ]]; then
  CARMELINK_BUILD_ARGS+=(
    "--dart-define=PASSWORD_RECOVERY_REDIRECT_URL=${PASSWORD_RECOVERY_REDIRECT_URL}"
  )
fi

"${CARMELINK_FLUTTER_BIN}" "${CARMELINK_BUILD_ARGS[@]}"
