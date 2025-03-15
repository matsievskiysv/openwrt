# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2007-2020 OpenWrt.org

##@ @file scan.mk top level makefile for scanning projects.
#
# This file calls Makefile in $(SCAN_DIR) subfolders in order to create package
# info caches in $(TMPDIR) folder.
##

include $(TOPDIR)/include/verbose.mk
include $(TOPDIR)/rules.mk
TMP_DIR:=$(TOPDIR)/tmp

all: $(TMP_DIR)/.$(SCAN_TARGET)

SCAN_TARGET ?= packageinfo
SCAN_NAME ?= package
SCAN_DIR ?= package
TARGET_STAMP:=$(TMP_DIR)/info/.files-$(SCAN_TARGET).stamp
FILELIST:=$(TMP_DIR)/info/.files-$(SCAN_TARGET)-$(SCAN_COOKIE)
OVERRIDELIST:=$(TMP_DIR)/info/.overrides-$(SCAN_TARGET)-$(SCAN_COOKIE)

export ORIG_PATH:=$(if $(ORIG_PATH),$(ORIG_PATH),$(PATH))
export PATH:=$(STAGING_DIR_HOST)/bin:$(PATH)

##@
# @brief Extract feed name from path.
#
# Path must start with `feeds/`
#
# @param 1: Path to feed
##
define feedname
$(if $(patsubst feeds/%,,$(1)),,$(word 2,$(subst /, ,$(1))))
endef

ifeq ($(SCAN_NAME),target)
  SCAN_DEPS=image/Makefile profiles/*.mk $(TOPDIR)/include/kernel*.mk $(TOPDIR)/include/target.mk image/*.mk
else
  SCAN_DEPS=$(TOPDIR)/include/package*.mk
ifneq ($(call feedname,$(SCAN_DIR)),)
  SCAN_DEPS += $(TOPDIR)/feeds/$(call feedname,$(SCAN_DIR))/*.mk
endif
endif

ifeq ($(IS_TTY),1)
  ifneq ($(strip $(NO_COLOR)),1)
    ##@
    # @brief Show progress string in color.
    #
    # @param 1: String
    ##
    define progress
	printf "\033[M\r$(1)" >&2;
    endef
  else
    ##@
    # @brief Show progress string w/o color.
    #
    # @param 1: String
    ##
    define progress
	printf "\r$(1)" >&2;
    endef
  endif
else
  ##@
  # @brief Placeholder function.
  #
  # @param 1: String
  ##
  define progress
	:;
  endef
endif

##@
# @brief Create target description file.
#
# Description files are placed in $(TMP_DIR)/info/ directory. For each
# $(SCAN_TARGET) the $(TMP_DIR)/$(SCAN_TARGET) flag file is created.
#
# @param 1: Target name
# @param 2: Subdirectory in $(SCAN_DIR) folder
# @param 3: Override flag
##
define PackageDir
  $(TMP_DIR)/.$(SCAN_TARGET): $(TMP_DIR)/info/.$(SCAN_TARGET)-$(1)
  $(TMP_DIR)/info/.$(SCAN_TARGET)-$(1): $(SCAN_DIR)/$(2)/Makefile $(foreach DEP,$(DEPS_$(SCAN_DIR)/$(2)/Makefile) $(SCAN_DEPS),$(wildcard $(if $(filter /%,$(DEP)),$(DEP),$(SCAN_DIR)/$(2)/$(DEP))))
	{ \
		$$(call progress,Collecting $(SCAN_NAME) info: $(SCAN_DIR)/$(2)) \
		echo Source-Makefile: $(SCAN_DIR)/$(2)/Makefile; \
		$(if $(3),echo Override: $(3),true); \
		$(if $(findstring c,$(OPENWRT_VERBOSE)),$(MAKE),$(NO_TRACE_MAKE) --no-print-dir) -r DUMP=1 FEED="$(call feedname,$(2))" -C $(SCAN_DIR)/$(2) $(SCAN_MAKEOPTS) \
			$(if $(findstring c,$(OPENWRT_VERBOSE)),,2>/dev/null) || { \
			mkdir -p "$(TOPDIR)/logs/$(SCAN_DIR)/$(2)"; \
			$(NO_TRACE_MAKE) --no-print-dir -r DUMP=1 FEED="$(call feedname,$(2))" -C $(SCAN_DIR)/$(2) $(SCAN_MAKEOPTS) > $(TOPDIR)/logs/$(SCAN_DIR)/$(2)/dump.txt 2>&1; \
			$$(call progress,ERROR: please fix $(SCAN_DIR)/$(2)/Makefile - see logs/$(SCAN_DIR)/$(2)/dump.txt for details\n) \
			rm -f $$@; \
		}; \
		echo; \
	} > $$@.tmp
	mv $$@.tmp $$@
endef

$(OVERRIDELIST):
	rm -f $(TMP_DIR)/info/.overrides-$(SCAN_TARGET)-*
	touch $@

ifeq ($(SCAN_NAME),target)
  GREP_STRING=BuildTarget
else
  GREP_STRING=(Build/DefaultTargets|BuildPackage|KernelPackage)
endif

##@
# @brief Create target package list.
#
# Scan depth is controlled by variable $(SCAN_DEPTH). Extra find() arguments are
# passed in $(SCAN_EXTRA).
# Result includes Makefiles containing $(GREP_STRING).
##
$(FILELIST): $(OVERRIDELIST)
	rm -f $(TMP_DIR)/info/.files-$(SCAN_TARGET)-*
	find -L $(SCAN_DIR) -mindepth 1 $(if $(SCAN_DEPTH),-maxdepth $(SCAN_DEPTH)) $(SCAN_EXTRA) -name Makefile | xargs grep -aHE 'call $(GREP_STRING)' | sed -e 's#^$(SCAN_DIR)/##' -e 's#/Makefile:.*##' | uniq | awk -v of=$(OVERRIDELIST) -f include/scan.awk > $@

$(TMP_DIR)/info/.files-$(SCAN_TARGET).mk: $(FILELIST)
	( \
		cat $< | awk '{print "$(SCAN_DIR)/" $$0 "/Makefile" }' | xargs grep -HE '^ *SCAN_DEPS *= *' | awk -F: '{ gsub(/^.*DEPS *= */, "", $$2); print "DEPS_" $$1 "=" $$2 }'; \
		awk -F/ -v deps="$$DEPS" -v of="$(OVERRIDELIST)" ' \
		BEGIN { \
			while (getline < (of)) \
				override[$$NF]=$$0; \
			close(of) \
		} \
		{ \
			info=$$0; \
			gsub(/\//, "_", info); \
			dir=$$0; \
			pkg=""; \
			if($$NF in override) \
				pkg=override[$$NF]; \
			print "$$(eval $$(call PackageDir," info "," dir "," pkg "))"; \
		} ' < $<; \
		true; \
	) > $@.tmp
	mv $@.tmp $@

-include $(TMP_DIR)/info/.files-$(SCAN_TARGET).mk

$(TARGET_STAMP)::
	+( \
		$(NO_TRACE_MAKE) $(FILELIST); \
		MD5SUM=$$(cat $(FILELIST) $(OVERRIDELIST) | $(MKHASH) md5 | awk '{print $$1}'); \
		[ -f "$@.$$MD5SUM" ] || { \
			rm -f $@.*; \
			touch $@.$$MD5SUM; \
			touch $@; \
		} \
	)

$(TMP_DIR)/.$(SCAN_TARGET): $(TARGET_STAMP)
	$(call progress,Collecting $(SCAN_NAME) info: merging...)
	-cat $(FILELIST) | awk '{gsub(/\//, "_", $$0);print "$(TMP_DIR)/info/.$(SCAN_TARGET)-" $$0}' | xargs cat > $@ 2>/dev/null
	$(call progress,Collecting $(SCAN_NAME) info: done)
	echo

FORCE:
.PHONY: FORCE
.NOTPARALLEL:
