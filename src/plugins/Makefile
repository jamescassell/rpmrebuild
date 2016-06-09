# $Id$
TOP_DIR := ..
include $(TOP_DIR)/Makefile.include

# list of plugins names
PLUG_LIST := \
   compat_digest \
   demo        \
   demofiles   \
   file2pacDep \
   nodoc       \
   set_tag     \
   uniq        \
   un_prelink  \
   unset_tag   \
                    \

PLUGINS := $(addsuffix .plug, $(PLUG_LIST))

SCRIPTS := $(addsuffix .sh, $(PLUG_LIST))

MANPAGES_BASE := $(addsuffix .1rrp,$(PLUGINS))

MANPAGES := $(foreach lang,$(LANGS),$(addprefix man/$(lang)/,$(MANPAGES_BASE)))

MANPAGES_SRC := $(addsuffix .in,$(MANPAGES))

SOURCES :=         \
   $(PLUGINS)	   \
   $(SCRIPTS)      \
   $(MANPAGES_SRC) \
   Makefile        \

all: $(MANPAGES)

$(MANPAGES): %: %.in $(TOP_DIR)/Version
	$(MakeManPage)

man: $(MANPAGES)

install:
	$(MKDIR)                   $(TARGET_PLUGIN)
	$(INSTALL_RO)  $(PLUGINS)  $(TARGET_PLUGIN)
	$(INSTALL_RUN) $(SCRIPTS)  $(TARGET_PLUGIN)
	$(InstallManPages)

clean:
	$(RM) $(MANPAGES)

tar_names:
	@echo $(addprefix plugins/,$(SOURCES))
