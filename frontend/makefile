build:
	./optimize.sh src/Main.elm
	mkdir -p src/gotutor/initialProgram
	cp -r src/initialProgram src/gotutor # since the pogram is server under https://ahmedakef.github.io/gotutor/


dev:
	elm make --output=src/compiledJs/elm.js src/Main.elm
	mkdir -p src/gotutor/initialProgram
	cp -r src/initialProgram src/gotutor # since the pogram is server under https://ahmedakef.github.io/gotutor/
