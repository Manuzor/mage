
OUTDIR = output

DFLAGSCOMMON += -m64
DFLAGSCOMMON += -gc
DFLAGSCOMMON += -w

MAGEDIST_DESTDIR = $(OUTDIR)/dist
MAGEDIST_CODEDIR = code/install


PATHLIB_DIR = thirdParty/pathlib
PATHLIB_CODEDIR = $(PATHLIB_DIR)/code
PATHLIB_DFILES = $(shell find $(PATHLIB_CODEDIR) -name '*.d')
PATHLIB_MAKE = +$(MAKE) -C $(PATHLIB_DIR) -e OUTDIR="../../$(OUTDIR)" -e DFLAGSCOMMON="$(DFLAGSCOMMON)"

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
	cp -r `find $(OUTDIR) -name '*.lib'` $(MAGEDIST_DESTDIR)/
	cp -r `find $(OUTDIR) -name '*.exe'` $(MAGEDIST_DESTDIR)/

# Code.
	cp -r $(PATHLIB_CODEDIR)/. $(MAGEDIST_DESTDIR)/import
	cp -r $(LIBMAGE_CODEDIR)/. $(MAGEDIST_DESTDIR)/import
	cp -r $(MAGEAPP_CODEDIR)/. $(MAGEDIST_DESTDIR)/import
	cp -r $(MAGEDIST_CODEDIR)/. $(MAGEDIST_DESTDIR)/code


lib: $(OUTDIR)/libmage.lib
$(OUTDIR)/libmage.lib: $(LIBMAGE_DFILES) | pathlib
	$(eval DFLAGS = $(DFLAGSCOMMON))

	$(eval DFLAGS += -I$(PATHLIB_CODEDIR))
	$(eval DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval DFLAGS += -lib)
	dmd $(LIBMAGE_DFILES) $(DFLAGS) -of$(OUTDIR)/libmage.lib

libtests: $(OUTDIR)/libmagetests.exe
$(OUTDIR)/libmagetests.exe: $(LIBMAGE_DFILES) | pathlib
	$(eval DFLAGS = $(DFLAGSCOMMON))

	$(eval DFLAGS += -I$(PATHLIB_CODEDIR))
	$(eval DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval DFLAGS += -unittest)
	$(eval DFLAGS += -main)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(LIBMAGE_DFILES) $(DFLAGS) -of$(OUTDIR)/libmagetests.exe

app: $(OUTDIR)/mage.exe
$(OUTDIR)/mage.exe: $(MAGEAPP_DFILES) | lib pathlib
	$(eval DFLAGS = $(DFLAGSCOMMON))

	$(eval DFLAGS += -I$(PATHLIB_CODEDIR))
	$(eval DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval DFLAGS += -Icode/lib)
	$(eval DFLAGS += -L$(OUTDIR)/libmage.lib)

	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(MAGEAPP_DFILES) $(DFLAGS) -of$(OUTDIR)/mage.exe

apptests: $(OUTDIR)/magetests.exe
$(OUTDIR)/magetests.exe: $(MAGEAPP_DFILES) | lib pathlib
	@echo Not implemented.
