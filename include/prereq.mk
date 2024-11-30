# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2006-2020 OpenWrt.org

##@ @file prereq.mk Prerequisite check functions.

ifneq ($(__prereq_inc),1)
__prereq_inc:=1

##@ @brief Report prereq error message once and clear it.
prereq:
	if [ -f $(TMP_DIR)/.prereq-error ]; then \
		echo; \
		cat $(TMP_DIR)/.prereq-error; \
		rm -f $(TMP_DIR)/.prereq-error; \
		echo; \
		false; \
	fi

.SILENT: prereq
endif

PREREQ_PREV=

##@
# @brief Setup prerequisite targets.
#
# Internal command, used by @RequireCommand, @RequireHeader, @RequireCHeader
# and @TestHostCommand, that sets up `prereq` and `check` targets.
#
# @param 1: Display name.
# @param 2: Error message.
##
define Require
  export PREREQ_CHECK=1
  ifeq ($$(CHECK_$(1)),)
    prereq: prereq-$(1)

    prereq-$(1): $(if $(PREREQ_PREV),prereq-$(PREREQ_PREV)) FORCE
		printf "Checking '$(1)'... "
		if $(NO_TRACE_MAKE) -f $(firstword $(MAKEFILE_LIST)) check-$(1) PATH="$(ORIG_PATH)" >/dev/null 2>/dev/null; then \
			echo 'ok.'; \
		elif $(NO_TRACE_MAKE) -f $(firstword $(MAKEFILE_LIST)) check-$(1) PATH="$(ORIG_PATH)" >/dev/null 2>/dev/null; then \
			echo 'updated.'; \
		else \
			echo 'failed.'; \
			echo "$(PKG_NAME): $(strip $(2))" >> $(TMP_DIR)/.prereq-error; \
		fi

    check-$(1): FORCE
	  $(call Require/$(1))
    CHECK_$(1):=1

    .SILENT: prereq-$(1) check-$(1)
    .NOTPARALLEL:
  endif

  PREREQ_PREV=$(1)
endef

##@
# @brief Check command presence.
#
# @param 1: Command to test.
# @param 2: Failure message.
##
define RequireCommand
  define Require/$(1)
    command -v $(1)
  endef

  $$(eval $$(call Require,$(1),$(2)))
endef

##@
# @brief Check file presence.
#
# @param 1: File to test.
# @param 2: Failure message.
##
define RequireHeader
  define Require/$(1)
    [ -e "$(1)" ]
  endef

  $$(eval $$(call Require,$(1),$(2)))
endef

##@
# @brief Check availability of C header.
#
# @param 1: Header to test.
# @param 2: Failure message.
# @param 3: Optional compile time test, embedded into C code.
# @param 4: Optional link library test (example -lncurses).
##
define RequireCHeader
  define Require/$(1)
    echo 'int main(int argc, char **argv) { $(3); return 0; }' | gcc -include $(1) -x c -o $(TMP_DIR)/a.out - $(4)
  endef

  $$(eval $$(call Require,$(1),$(2)))
endef

##@
# @brief Put shell command in quotes.
#
# Put shell command in single quotes `'` and escape them in command string.
#
# @param 1: Command.
##
define QuoteHostCommand
'$(subst ','"'"',$(strip $(1)))'
endef

##@
# @brief Evaluate shell test expression.
#
# @param 1: Display name.
# @param 2: Failure message.
# @param 3: Shell test.
##
define TestHostCommand
  define Require/$(1)
	($(3)) >/dev/null 2>/dev/null
  endef

  $$(eval $$(call Require,$(1),$(2)))
endef

##@
# @brief Select command out of several possibilities.
#
# @param 1: Canonical name.
# @param 2: Failure message.
# @param 3..12: Candidate testing functions. The successfully evaluated command
#               will be used.
##
define SetupHostCommand
  define Require/$(1)
	mkdir -p "$(STAGING_DIR_HOST)/bin"; \
	for cmd in $(call QuoteHostCommand,$(3)) $(call QuoteHostCommand,$(4)) \
	           $(call QuoteHostCommand,$(5)) $(call QuoteHostCommand,$(6)) \
	           $(call QuoteHostCommand,$(7)) $(call QuoteHostCommand,$(8)) \
	           $(call QuoteHostCommand,$(9)) $(call QuoteHostCommand,$(10)) \
	           $(call QuoteHostCommand,$(11)) $(call QuoteHostCommand,$(12)); do \
		if [ -n "$$$$$$$$cmd" ]; then \
			bin="$$$$$$$$(command -v "$$$$$$$${cmd%% *}")"; \
			if [ -x "$$$$$$$$bin" ] && eval "$$$$$$$$cmd" >/dev/null 2>/dev/null; then \
				case "$$$$$$$$(ls -dl -- $(STAGING_DIR_HOST)/bin/$(strip $(1)))" in \
					"-"* | \
					*" -> $$$$$$$$bin"* | \
					*" -> "[!/]*) \
						[ -x "$(STAGING_DIR_HOST)/bin/$(strip $(1))" ] && exit 0 \
						;; \
				esac; \
				ln -sf "$$$$$$$$bin" "$(STAGING_DIR_HOST)/bin/$(strip $(1))"; \
				exit 1; \
			fi; \
		fi; \
	done; \
	exit 1
  endef

  $$(eval $$(call Require,$(1),$(if $(2),$(2),Missing $(1) command)))
endef
