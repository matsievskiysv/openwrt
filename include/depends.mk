# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2007-2020 OpenWrt.org

##@ @file depends.mk Subtree dependency target generation.

##@
# @brief Excluded globs for file search.
#
# Globs are prepended  by `-x` flag. Used in @find_md5 and
# @find_md5_reproducible functions.
#
##
DEP_FINDPARAMS := -x "*/.svn*" -x ".*" -x "*:*" -x "*\!*" -x "* *" -x "*\\\#*" -x "*/.*_check" -x "*/.*.swp" -x "*/.pkgdir*"

##@
# @brief Calculate hash of files in folder including modification time.
#
# This version uses modification time to calculate hash, thus the hash value is
# not reproducible. If you need reproducible hash, use @find_md5_reproducible
# function.
#
# @see @find_md5_reproducible
#
# @param 1: Directory glob. May resolve to multiple directories.
# @param 2: Ignored subdir globs, separated by `-x`. Gets added to
#           @DEP_FINDPARAMS list.
##
find_md5=find $(wildcard $(1)) -type f $(patsubst -x,-and -not -path,$(DEP_FINDPARAMS) $(2)) -printf "%p%T@\n" | sort | $(MKHASH) md5

##@
# @brief Calculate hash of files in folder.
#
# This version does not use file modification time to calculate hash, thus
# the hash value is reproducible.
#
# @see @find_md5
#
# @param 1: Directory glob. May resolve to multiple directories.
# @param 2: Ignored subdir globs, separated by `-x`. Gets added to
#           @DEP_FINDPARAMS list.
##
find_md5_reproducible=find $(wildcard $(1)) -type f $(patsubst -x,-and -not -path,$(DEP_FINDPARAMS) $(2)) -print0 | xargs -0 $(MKHASH) md5 | sort | $(MKHASH) md5

##@
# @brief Define a dependency on a subtree.
#
# Check subtree files timestamps and compare with flag $(2)_check file timestamp.
#
# @param 1: Dependency directories/files.
# @param 2: Dependency file.
# @param 3: Temporary file for file listings.
# @param 4: Additional ignored subdir globs. Appended to @DEP_FINDPARAMS list.
##
define rdep
  .PRECIOUS: $(2)
  .SILENT: $(2)_check

  $(2): $(2)_check
  check-depends: $(2)_check

ifneq ($(wildcard $(2)),)
  # target file already exists
  $(2)_check::
	$(if $(3), \
		$(call find_md5,$(1),$(4)) > $(3).1; \
		{ [ \! -f "$(3)" ] || diff $(3) $(3).1 >/dev/null; } && \
	) \
	{ \
		[ -f "$(2)_check.1" ] && mv "$(2)_check.1" "$(2)_check"; \
	    $(TOPDIR)/scripts/timestamp.pl $(DEP_FINDPARAMS) $(4) -n $(2) $(1) && { \
			$(call debug_eval,$(SUBDIR),r,echo "No need to rebuild $(2)";) \
			touch -r "$(2)" "$(2)_check"; \
		} \
	} || { \
		$(call debug_eval,$(SUBDIR),r,echo "Need to rebuild $(2)";) \
		touch "$(2)_check"; \
	}
	$(if $(3), mv $(3).1 $(3))
else
  # target file not yet exist
  $(2)_check::
	$(if $(3), rm -f $(3) $(3).1)
	$(call debug_eval,$(SUBDIR),r,echo "Target $(2) not built")
endif

endef

ifeq ($(filter .%,$(MAKECMDGOALS)),$(if $(MAKECMDGOALS),$(MAKECMDGOALS),x))
  # if make target starts with ".". TODO: find where is needed
  define rdep
    $(2): $(2)_check
  endef
endif
