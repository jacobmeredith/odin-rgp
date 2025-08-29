default: build

clean:
	rm -rf build
	mkdir build

build: clean
	odin build src -debug -out:build/debug
