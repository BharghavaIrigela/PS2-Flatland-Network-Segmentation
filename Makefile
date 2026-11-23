# Flatland PS-2 - common tasks.   make help
NAME    := flatland-ps2
DIST    := dist
ZIPFILE := $(DIST)/$(NAME).zip

.PHONY: help test smoke dashboard zip test-fresh clean

help:          ## list targets
	@grep -E '^[a-z-]+:.*##' Makefile | awk -F':.*## ' '{printf "  make %-11s %s\n", $$1, $$2}'

test:          ## static checks: deliverables present, scripts parse, compose + nft valid
	@bash scripts/check_static.sh

smoke:         ## full before/after run with assertions (needs Docker, ~5 min)
	@bash scripts/smoke.sh

dashboard:     ## start the web dashboard on http://localhost:8000
	python3 dashboard/server.py

zip:           ## build dist/flatland-ps2.zip (code, configs, docs, evidence)
	@mkdir -p $(DIST)
	@rm -f $(ZIPFILE)
	@cd .. && zip -qr $(CURDIR)/$(ZIPFILE) $(notdir $(CURDIR)) \
	   -x '$(notdir $(CURDIR))/$(DIST)/*' '$(notdir $(CURDIR))/.git/*' '*/__pycache__/*' '*.pyc'
	@echo "built $(ZIPFILE) ($$(du -h $(ZIPFILE) | cut -f1))"

test-fresh: zip ## unzip the package into a temp dir and test that copy (FULL=1 also runs smoke)
	@T=$$(mktemp -d) && unzip -q $(ZIPFILE) -d $$T && cd $$T/$(notdir $(CURDIR)) && \
	  echo "== testing fresh copy in $$T" && bash scripts/check_static.sh && \
	  if [ "$(FULL)" = "1" ]; then bash scripts/smoke.sh; fi && \
	  echo "FRESH COPY OK" ; rc=$$?; rm -rf $$T; exit $$rc

clean:         ## remove build output
	rm -rf $(DIST)
