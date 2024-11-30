# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2007-2020 OpenWrt.org

##@
# @file debug.mk Conditionally print messages, based on debug level.
#
# Debug flags:
#
# d: show subdirectory tree
# t: show added targets
# l: show legacy targets
# r: show autorebuild messages
# v: verbose (no .SILENCE for common targets)
##

ifeq ($(DUMP),)
  ifeq ($(DEBUG),all)
    build_debug:=dltvr
  else
    build_debug:=$(DEBUG)
  endif
endif

ifneq ($(DEBUG),)

##@
# @brief Check debug enable conditions.
#
# Internal command, used by @warn, @debug_eval and @warn_eval to determine if
# debug conditions are met. This command uses @build_debug and @DEBUG_SCOPE_DIR
# variable values to determine debugging level and scope.
#
# @param 1: Debug scope. For debugging to be enabled, must match @DEBUG_SCOPE_DIR.
# @param 2: Debug level. For debugging to be enabled, must be present in @build_debug.
##
define debug
$$(findstring $(2),$$(if $$(DEBUG_SCOPE_DIR),$$(if $$(filter $$(DEBUG_SCOPE_DIR)%,$(1)),$(build_debug)),$(build_debug)))
endef

##@
# @brief Show warning message, if meet debug conditions.
#
# @param 1: Debug scope. For debugging to be enabled, must match @DEBUG_SCOPE_DIR.
# @param 2: Debug level. For debugging to be enabled, must be present in @build_debug.
# @param 3: Warning message.
##
define warn
$$(if $(call debug,$(1),$(2)),$$(warning $(3)))
endef

##@
# @brief Evaluate expression, if meet debug conditions.
#
# @param 1: Debug scope. For debugging to be enabled, must match @DEBUG_SCOPE_DIR.
# @param 2: Debug level. For debugging to be enabled, must be present in @build_debug.
# @param 3: Expression to evaluate.
##
define debug_eval
$$(if $(call debug,$(1),$(2)),$(3))
endef

##@
# @brief Evaluate expression unconditionally and print it as warning message,
# if meet debug conditions.
#
# @param 1: Debug scope. For debugging to be enabled, must match @DEBUG_SCOPE_DIR.
# @param 2: Debug level. For debugging to be enabled, must be present in @build_debug.
# @param 3: Warning message prefix.
# @param 4: Expression to evaluate. Usually, the build rule.
##
define warn_eval
$(call warn,$(1),$(2),$(3)	$(4))
$(4)
endef

else

debug:=
warn:=
debug_eval:=
warn_eval = $(4)

endif

