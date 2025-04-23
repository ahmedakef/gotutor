build:
	# sed -i '' 's/elm.js/elm\.min\.js/g' src/index.html
	./optimize.sh src/Main.elm
	mkdir -p src/gotutor/initialProgram
	cp -r src/initialProgram src/gotutor # since it can be served under https://ahmedakef.github.io/gotutor/


dev:
	# elm make --output=src/compiledJs/elm.js src/Main.elm
	mkdir -p src/gotutor/initialProgram
	sed -i '' 's/elm\.min\.js/elm.js/g' src/index.html
	cp -r src/initialProgram src/gotutor # since it can be served under https://ahmedakef.github.io/gotutor/
	cleancss -o src/style.min.css src/style.css
	elm-live src/Main.elm --start-page=src/index.html --  --output=src/compiledJs/elm.js # site will be ready at http://localhost:8000/src/index.html
