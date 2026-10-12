.PHONY: help install test package run format format-check build publish doc doc-build clean

help:
	@echo "install       install the pixi environments"
	@echo "test          run the test suite"
	@echo "package       precompile dist/libc.mojoc"
	@echo "run           run src/main.mojo"
	@echo "format        apply mojo format"
	@echo "format-check  fail when the tree is not formatted"
	@echo "build         build the conda package"
	@echo "publish       upload the conda package to prefix.dev"
	@echo "doc           serve the docs"
	@echo "doc-build     build the docs"
	@echo "clean         remove build artifacts"

install:
	pixi install --all

test:
	pixi run test

package:
	pixi run package

run:
	pixi run run

format:
	pixi run format

format-check:
	pixi run format-check

build:
	pixi run -e build build-conda

publish:
	pixi run -e build publish

doc:
	pixi run -e docs doc

doc-build:
	pixi run -e docs doc-build

clean:
	rm -rf dist output site
