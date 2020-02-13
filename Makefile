include common.mk

plan-infra:
	$(MAKE) -C infra plan-all

deploy-infra:
	$(MAKE) -C infra apply-all
