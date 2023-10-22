SHELL = /bin/bash

TSDIR   ?= $(CURDIR)/tree-sitter-x86asm
TESTDIR ?= $(TSDIR)/examples

all:
	@

dev: $(TSDIR)
$(TSDIR):
	@git clone --depth=1 https://github.com/bearcove/tree-sitter-x86asm
	@printf "\33[1m\33[31mNote\33[22m npm build can take a while\n" >&2
	cd $(TSDIR) &&                                         \
		npm --loglevel=info --progress=true install && \
		npm run generate

.PHONY: parse-%
parse-%:
	cd $(TSDIR) && npx tree-sitter parse $(TESTDIR)/$(subst parse-,,$@)

clean:
	$(RM) -r *~

distclean: clean
	$(RM) -rf $$(git ls-files --others --ignored --exclude-standard)
