include common.mk

plan-infra:
	$(MAKE) -C infra plan-all

deploy-infra:
	$(MAKE) -C infra apply-all

requirements.txt: %.txt : %.txt.in
	test ! -e .requirements-env || exit 1
	virtualenv -p $(shell which python3) .$<-env
	.$<-env/bin/pip install -r $@
	.$<-env/bin/pip install -r $<
	@echo "# You should not edit this file directly.  Instead, you should edit $<." >| $@
	.$<-env/bin/pip freeze >> $@
	rm -rf .$<-env

refresh_all_requirements:
	@cat /dev/null > requirements.txt
	@if [ $$(uname -s) == "Darwin" ]; then sleep 1; fi  # this is require because Darwin HFS+ only has second-resolution for timestamps.
	@touch requirements.txt.in
	@$(MAKE) requirements.txt

clean:
	git clean -Xdf chalice daemons $(MODULES)
	git clean -df {chalice,daemons/*}/{chalicelib,domovoilib,vendor}
	git checkout $$(git status --porcelain {chalice,daemons/*}/.chalice/config.json | awk '{print $$2}')
	-rm -rf .*-env
	-rm -rf node_modules
