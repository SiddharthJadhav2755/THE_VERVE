#!/bin/bash
# Reassembles the single-file THE VERVE app from its 9 source modules.
# Usage: bash build.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/../the-verve-store.html"
cat "$DIR"/01-head.part "$DIR"/02-data.part "$DIR"/03-core.part \
    "$DIR"/04-storefront.part "$DIR"/05-product.part "$DIR"/06-commerce.part \
    "$DIR"/07-account.part "$DIR"/08-admin.part "$DIR"/09-events-boot.part > "$OUT"
echo "built $(wc -c < "$OUT") bytes -> $OUT"
