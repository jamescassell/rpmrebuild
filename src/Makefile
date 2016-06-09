# $Id$
#
TOP_DIR := .
include $(TOP_DIR)/Makefile.include

PWD := $(shell pwd)
RPM_TOP_DIR    := $(PWD)/BUILD
RPM_SOURCE_DIR := $(PWD)
RPM_BUILD_DIR  := $(PWD)/BUILD
RPM_RPMS_DIR   := $(PWD)
RPM_SRPMS_DIR  := $(PWD)

RPM_DEFINES :=                             \
   --define '_topdir    $(RPM_TOP_DIR)'    \
   --define '_sourcedir $(RPM_SOURCE_DIR)' \
   --define '_builddir  $(RPM_BUILD_DIR)'  \
   --define '_rpmdir    $(RPM_RPMS_DIR)'   \
   --define '_srcrpmdir $(RPM_SRPMS_DIR)'  \
   --define '_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm'

PACKAGE=rpmrebuild
VERSION=$(shell cat Version)
TAR_FILE := $(RPM_SOURCE_DIR)/rpmrebuild-$(VERSION).tar.gz

SCRIPTS     := rpmrebuild 

LIB_SCRIPTS :=             \
   rpmrebuild.sh           \
   rpmrebuild_files.sh     \
   rpmrebuild_buildroot.sh \
   rpmrebuild_ghost.sh     \
   rpmrebuild_extract_tags.sh \

INCLUDE_SCRIPTS :=       \
   rpmrebuild_lib.src   \
   processing_func.src   \
   rpmrebuild_rpmqf.src  \
   rpmrebuild_parser.src \
   spec_func.src         \

MANPAGES_BASE :=        \
   rpmrebuild.1         \
   rpmrebuild_plugins.1 \

LOCALE_BASE := 	\
   rpmrebuild.lang

KEYWORD_FILES = $(SCRIPTS) $(LIB_SCRIPTS) $(INCLUDE_SCRIPTS)

MANPAGES := $(foreach lang,$(LANGS),$(addprefix man/$(lang)/,$(MANPAGES_BASE)))
LOCALES := $(foreach lang,$(LANGS),$(addprefix locale/$(lang)/,$(LOCALE_BASE)))

MANPAGES_SRC := $(addsuffix .in,$(MANPAGES))

DOC_FILES :=      \
   AUTHORS        \
   Changelog      \
   COPYING        \
   COPYRIGHT      \
   LISEZ.MOI      \
   News           \
   README         \
   rpmrebuild.lsm \
   Todo           \

SOURCES :=               \
   $(SCRIPTS)            \
   $(LIB_SCRIPTS)        \
   $(INCLUDE_SCRIPTS)    \
   $(SPEC_SCRIPTS)       \
   $(MANPAGES_SRC)	 \
   $(LOCALES)		 \
   $(DOC_FILES)          \
   Makefile              \
   Makefile.include      \
   Changelog             \
   rpmrebuild.spc        \
   rpmrebuild.files      \
   Version               \
   Release               \

TAR_NAMES_PLUGINS := $(shell $(MAKE) --quiet -C plugins tar_names)
TAR_NAMES := $(SOURCES) rpmrebuild.spec $(TAR_NAMES_PLUGINS)

define Spec
   Version="`cat Version`"             && \
   Release="`cat Release`"             && \
   {                                      \
      echo "Version: $$Version"        && \
      echo "%define release $$Release" && \
      cat rpmrebuild.spc               && \
      echo "%changelog"                && \
      cat Changelog                    && \
      :                                ;  \
   }
endef

all: rpmrebuild.spec VERSION $(MANPAGES) 
	$(MAKE) -C plugins $@

rpmrebuild.spec: rpmrebuild.spc Version Release Changelog 
	$(RM) $@
	$(Spec) > $@ || { $(RM) $@; exit 1; }

$(MANPAGES): %: %.in $(TOP_DIR)/Version
	$(MakeManPage)

VERSION: Version
	$(RM) $@
	read VERSION < $< && echo "VERSION='$$VERSION'" > $@ || { $(RM) $@; exit 1; }

install:
	$(MKDIR)                                  $(TARGET_DIR)
	$(INSTALL_RUN) $(SCRIPTS)                 $(TARGET_DIR)

	$(MKDIR)                                 $(TARGET_LIB)
	$(INSTALL_RUN) $(LIB_SCRIPTS)            $(TARGET_LIB)
	$(INSTALL_RO) $(INCLUDE_SCRIPTS) VERSION $(TARGET_LIB)
	$(InstallManPages)
	$(InstallLocales)
	$(MAKE) -C plugins $@

tar:	rpmrebuild.spec man expand
	tar -cvzf $(TAR_FILE) $(TAR_NAMES)

dist:	tar
	~/bin/gensign.sh $(TAR_FILE)

rpmbuild:	tar
	$(MKDIR) $(RPM_BUILD_DIR)
	$@ -ba $(RPM_DEFINES) rpmrebuild.spec
	rpm --resign rpmrebuild*.rpm

clean: unexpand
	$(RMDIR) $(ROOT) $(RPM_BUILD_DIR)
	$(RM)    VERSION rpmrebuild.spec *.rpm rpmrebuild.tar.gz rpmrebuild.tar.gz.sig
	$(RM)    $(MANPAGES)
	$(MAKE) -C plugins $@

man: $(MANPAGES)

html:
	./faire_doc.sh

# build all packages
alldist: rpmbuild dist html

# expand svn keywords just for publish
expand:
	git tag -f "$(PACKAGE)-$(VERSION)"
	git-svn-keyword-expand $(KEYWORD_FILES)

# remove svn keywords to keep repository clean
unexpand:
	git-svn-keyword-unexpand $(KEYWORD_FILES)

help:
	@echo "list of targets :"
	@echo "- tar : build tar.gz"
	@echo "- dist : build signed tar.gz"
	@echo "- rpmbuild : build rpm packages"
	@echo "- install : install software"
	@echo "- man : build man pages"
	@echo "- html : build html pages"
	@echo "- alldist : build all packages"
	@echo "- clean : clean building temp files"
