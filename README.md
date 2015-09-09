# mage
Makefile and IDE Project file generator.

# Building with `make`
You need to have a `make` program that is compliant with GNU make as well as the dmd compiler in your path. Any of the submodules are not initialized yet, the Makefile will take care of it. Simply `cd` into the mage repo and type `make`.

Interesting targets:
- lib -- Creates the main library `libmage.lib`.
- app -- Create the command line client used to generate build systems.
- tests -- Create testing executables in `output/`.
- dist -- Assemble all files needed to install mage on any system, ready to be archived by `7z`, `tar`, or whatever. By default, all files are put to `output/dist/`. Use `make dist -e MAGEDIST_DESTDIR="C:/some/path/mage"` to control where these files are being put.

You can use `make -e DFLAGS="-whatever"` to override the default flags passed to dmd for mage and all its dependencies.

# Building with `dub`
To build `libmage.lib`: `dub build mage:lib`
To build `mage.exe`: `dub build mage:app` 
To "install" all necessary mage files: `dub build mage:app && dup run mage:install -- -s . -d C:/some/path/mage`
