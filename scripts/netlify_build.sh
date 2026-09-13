#!/usr/bin/env bash
# Netlify build: Flutter web + config.env z environment variables.
# PROČ: assets/config.env je v .gitignore (tajné klíče) – na CI ho vytvoříme z Netlify Env.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> FalcoNest Netlify build"

# --- Supabase klíče (povinné v Netlify Site settings → Environment variables) ---
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "ERROR: Nastav v Netlify Environment variables: SUPABASE_URL a SUPABASE_ANON_KEY" >&2
  exit 1
fi

{
  echo "SUPABASE_URL=${SUPABASE_URL}"
  echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  echo "APP_URL=${APP_URL:-}"
} > assets/config.env
echo "==> assets/config.env vytvořen (URL=$(printf '%s' "$SUPABASE_URL" | head -c 40)…)"

# --- Flutter (cache mezi buildy, pokud Netlify poskytne NETLIFY_CACHE_DIR) ---
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
CACHE_ROOT="${NETLIFY_CACHE_DIR:-$HOME}"
FLUTTER_DIR="${CACHE_ROOT}/flutter-sdk"

if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  echo "==> Klonuji Flutter (${FLUTTER_CHANNEL}) do ${FLUTTER_DIR}"
  rm -rf "${FLUTTER_DIR}"
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    -b "${FLUTTER_CHANNEL}" \
    "${FLUTTER_DIR}"
else
  echo "==> Používám cached Flutter v ${FLUTTER_DIR}"
  git -C "${FLUTTER_DIR}" fetch --depth 1 origin "${FLUTTER_CHANNEL}" || true
  git -C "${FLUTTER_DIR}" checkout -B "${FLUTTER_CHANNEL}" "origin/${FLUTTER_CHANNEL}" || \
    git -C "${FLUTTER_DIR}" checkout "${FLUTTER_CHANNEL}" || true
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --enable-web --no-analytics
flutter --version
flutter pub get
flutter build web --release

# SPA fallback (pro jistotu i když web/_redirects už Flutter zkopíruje)
if [[ ! -f build/web/_redirects ]]; then
  cp web/_redirects build/web/_redirects
fi

echo "==> Hotovo: build/web"
