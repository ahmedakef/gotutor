#!/bin/sh

set -e

js="src/compiledJs/elm.js"
js_optimized="src/compiledJs/elm_optimized.js"
min="src/compiledJs/elm.min.js"

elm make --output=$js "$@"
elm make --optimize --output=$js_optimized "$@"

uglifyjs $js_optimized --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output $min
cleancss -o src/style.min.css src/style.css

echo "Compiled size:$(wc -c $js_optimized) bytes  ($js_optimized)"
echo "Minified size:$(wc -c $min) bytes  ($min)"
echo "Gzipped size: $(gzip $min -c | wc -c) bytes"
