
OUTDIR = output

DFLAGS += -debug
DFLAGS += -m64
DFLAGS += -gc
DFLAGS += -gs
DFLAGS += -w

MAGEDIST_DESTDIR = $(OUTDIR)/dist
MAGEDIST_CODEDIR = code/install


PATHLIB_DIR = thirdParty/pathlib
PATHLIB_CODEDIR = $(PATHLIB_DIR)/code
PATHLIB_DFILES = $(shell find $(PATHLIB_CODEDIR) -name '*.d')
PATHLIB_MAKE = +$(MAKE) -C $(PATHLIB_DIR) -e OUTDIR="../../$(OUTDIR)" -e DFLAGS="$(DFLAGS)"

LIBMAGE_CODEDIR = code/lib
LIBMAGE_DFILES = $(shell find $(LIBMAGE_CODEDIR) -name '*.d')

MAGEAPP_CODEDIR = code/app
MAGEAPP_DFILES = $(shell find $(MAGEAPP_CODEDIR) -name '*.d')

SUBMODULE_DEP = thirdParty/


default: all

all: lib app tests

init:
	mkdir -p $(OUTDIR)
	

.PHONY: clean
clean:
	rm -rf $(OUTDIR)
	
$(SUBMODULE_DEP):
	git submodule update --init --recursive

pathlib: $(SUBMODULE_DEP)
	@$(PATHLIB_MAKE) lib

$(PATHLIB_DIR)/: thirdParty/

pathlibtests: $(PATHLIB_DIR)
	@$(PATHLIB_MAKE) tests

tests: libtests apptests pathlibtests

.PHONY: runtests
runtests: tests
	-$(OUTDIR)/pathlibtests.exe
	-$(OUTDIR)/libmagetests.exe

dist: all
	mkdir -p $(MAGEDIST_DESTDIR)
	mkdir -p $(MAGEDIST_DESTDIR)/import
	mkdir -p $(MAGEDIST_DESTDIR)/code

# Binaries.
	cp -ru `find $(OUTDIR) -maxdepth 1 -name '*.lib'` $(MAGEDIST_DESTDIR)/
	cp -ru `find $(OUTDIR) -maxdepth 1 -name '*.exe'` $(MAGEDIST_DESTDIR)/

# Code.
	cp -ru $(PATHLIB_CODEDIR)/. $(MAGEDIST_DESTDIR)/import
	cp -ru $(LIBMAGE_CODEDIR)/. $(MAGEDIST_DESTDIR)/import
	cp -ru $(MAGEAPP_CODEDIR)/. $(MAGEDIST_DESTDIR)/import
	cp -ru $(MAGEDIST_CODEDIR)/. $(MAGEDIST_DESTDIR)/code


lib: $(OUTDIR)/libmage.lib
$(OUTDIR)/libmage.lib: $(LIBMAGE_DFILES) | pathlib
	$(eval LIBMAGE_DFLAGS = $(DFLAGS))

	$(eval LIBMAGE_DFLAGS += -I$(PATHLIB_CODEDIR))
	$(eval LIBMAGE_DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval LIBMAGE_DFLAGS += -lib)
	dmd $(LIBMAGE_DFILES) $(LIBMAGE_DFLAGS) -of$(OUTDIR)/libmage.lib

libtests: $(OUTDIR)/libmagetests.exe
$(OUTDIR)/libmagetests.exe: $(LIBMAGE_DFILES) | pathlib
	$(eval LIBMAGETESTS_DFLAGS = $(DFLAGS))

	$(eval LIBMAGETESTS_DFLAGS += -I$(PATHLIB_CODEDIR))
	$(eval LIBMAGETESTS_DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval LIBMAGETESTS_DFLAGS += -unittest)
	$(eval LIBMAGETESTS_DFLAGS += -main)
	$(eval LIBMAGETESTS_DFLAGS += -od$(OUTDIR))
	dmd $(LIBMAGE_DFILES) $(LIBMAGETESTS_DFLAGS) -of$(OUTDIR)/libmagetests.exe

app: $(OUTDIR)/mage.exe
$(OUTDIR)/mage.exe: $(MAGEAPP_DFILES) | lib pathlib
	$(eval MAGEAPP_DFLAGS = $(DFLAGS))

	$(eval MAGEAPP_DFLAGS += -I$(PATHLIB_CODEDIR))
	$(eval MAGEAPP_DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval MAGEAPP_DFLAGS += -Icode/lib)
	$(eval MAGEAPP_DFLAGS += -L$(OUTDIR)/libmage.lib)

	$(eval MAGEAPP_DFLAGS += -od$(OUTDIR))
	dmd $(MAGEAPP_DFILES) $(MAGEAPP_DFLAGS) -of$(OUTDIR)/mage.exe

apptests: $(OUTDIR)/magetests.exe
$(OUTDIR)/magetests.exe: $(MAGEAPP_DFILES) | lib pathlib
	@echo Not implemented.
