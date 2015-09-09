
CUR_MAKEFILE = $(abspath $(lastword $(MAKEFILE_LIST)))
ifneq ($(shell uname -s | grep -i cygwin),)
  # We are in a cygwin shell.
  CUR_MAKEFILEDIR = $(shell cygpath -m $(dir $(CUR_MAKEFILE)))
else
  # We are in some other shell.
  CUR_MAKEFILEDIR = $(dir $(CUR_MAKEFILE))
endif

ifeq ($(CUR_MAKEFILEDIR),)
  error "Unable to determine current working dir."
endif

ifeq ($(OUTDIR),)
  OUTDIR = $(CUR_MAKEFILEDIR)/output
endif

ifeq ($(DFLAGSCOMMON),)
  #DFLAGSCOMMON += -m64
  #DFLAGSCOMMON += -L/INCREMENTAL:NO
  DFLAGSCOMMON += -gc
  DFLAGSCOMMON += -w
endif

DFILES_LIB = $(shell find code/lib -name '*.d')
DFILES_APP = $(shell find code/app -name '*.d')

PATHLIB_MAKE = $(MAKE) -C thirdParty/pathlib -e OUTDIR="$(OUTDIR)" -e DFLAGSCOMMON="$(DFLAGSCOMMON)"


default: lib

all: lib libtests app apptests

.PHONY: clean
clean:
	@echo "Cleaning all '$(OUTDIR)/*mage*' files ..."
	@find $(OUTDIR)/ -type f | grep mage | xargs rm -f
	$(PATHLIB_MAKE) clean

pathlib: thirdParty/pathlib
	$(PATHLIB_MAKE)

lib: pathlib $(DFILES_LIB)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	
# pathlib.lib
	$(eval DFLAGS += -IthirdParty/pathlib/code)
	$(eval DFLAGS += -L$(OUTDIR)/pathlib.lib)

	$(eval DFLAGS += -lib)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(DFILES_LIB) $(DFLAGS) -of$(OUTDIR)/mage.lib

app: lib $(DFILES_APP)
	$(eval DFLAGS = $(DFLAGSCOMMON))

# mage.lib
	$(eval DFLAGS += -Icode/lib)
	$(eval DFLAGS += -L$(OUTDIR)/mage.lib)

	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(DFILES_APP) $(DFLAGS) -of$(OUTDIR)/mage.exe

libtests: $(DFILES_LIB)
	$(eval DFLAGS = $(DFLAGSCOMMON))
	$(eval DFLAGS += -unittest)
	$(eval DFLAGS += -main)
	$(eval DFLAGS += -od$(OUTDIR))
	dmd $(DFILES_LIB) $(DFLAGS) -of$(OUTDIR)/magetests.exe

apptests: $(DFILES_APP)
	@echo Not implemented.

runtests: tests
	$(OUTDIR)/magetests.exe

