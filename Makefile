TOP_DIR = ../..
DEPLOY_RUNTIME ?= /disks/patric-common/runtime
TARGET ?= /tmp/deployment
include $(TOP_DIR)/tools/Makefile.common

SERVICE_SPEC = 
SERVICE_NAME = p3_user_service
SERVICE_HOSTNAME = localhost
SERVICE_PORT = 3002
SERVICE_DIR  = $(SERVICE_NAME)
SERVICE_APP_DIR      = $(TARGET)/services/$(SERVICE_DIR)/app

#APP_REPO     = git@github.com:olsonanl/p3_user.git
APP_REPO     = https://github.com/olsonanl/p3_user.git
#APP_REPO     = https://github.com/PATRIC3/p3_user.git
APP_DIR      = p3_user
APP_SCRIPT   = ./bin/p3user-server

#
# For now we use a fork of dme.
#
DME_REPO     = https://github.com/olsonanl/dme.git


PATH := $(DEPLOY_RUNTIME)/build-tools/bin:$(PATH)

ifdef DEPLOYMENT_VAR_DIR
SERVICE_LOGDIR = $(DEPLOYMENT_VAR_DIR)/services/$(SERVICE_NAME)
TPAGE_SERVICE_LOGDIR = --define kb_service_log_dir=$(SERVICE_LOGDIR)
endif

CONFIG          = p3-user.conf
CONFIG_TEMPLATE = $(CONFIG).tt

REDIS_HOST = beech.mcs.anl.gov
REDIS_PORT = 6379
REDIS_DB   = 1
REDIS_PASS = 

PRODUCTION = true
MONGO_URL = mongodb://$(SERVICE_HOSTNAME)/p3-user-test
WORKSPACE_API_URL = https://p3.theseed.org/services/Workspace
DISTRIBUTE_URL = http://$(SERVICE_HOSTNAME):3001
ENABLE_INDEXER = false
JBROWSE_API_ROOT = https://www.beta.patricbrc.org/jbrowse
PUBLIC_GENOME_DIR = /vol/patric3/downloads/genomes
NUM_WORKERS = 4
CACHE_ENABLED = false

P3USER_SERVICE_URL = http://$(SERVICE_HOSTNAME):$(SERVICE_PORT)
P3HOME_URL = http://$(SERVICE_HOSTNAME):3000
P3USER_SIGNING_PRIVATE_PEM = $(shell pwd)/test-private-nokey.pem 
P3USER_SIGNING_PUBLIC_PEM = $(shell pwd)/test-public.pem 
P3USER_REALM = patricbrc.org

COOKIE_SECRET = patric3
COOKIE_KEY = patric3
COOKIE_DOMAIN = $(shell echo $(SERVICE_HOSTNAME) | sed -e 's/^[^.][^.]*\././') 

SERVICE_PSGI = $(SERVICE_NAME).psgi
TPAGE_ARGS = --define kb_runas_user=$(SERVICE_USER) \
	--define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE_NAME) \
	--define kb_service_dir=$(SERVICE_DIR) \
	--define kb_service_port=$(SERVICE_PORT) \
	--define kb_psgi=$(SERVICE_PSGI) \
	--define kb_app_dir=$(SERVICE_APP_DIR) \
	--define kb_app_script=$(APP_SCRIPT) \
	--define p3user_production=$(PRODUCTION) \
	--define p3user_service_port=$(SERVICE_PORT) \
	--define p3user_mongo_url=$(MONGO_URL) \
	--define p3user_workspace_api_url=$(WORKSPACE_API_URL) \
	--define p3user_distribute_url=$(DISTRIBUTE_URL) \
	--define p3user_enable_indexer=$(ENABLE_INDEXER) \
	--define p3user_jbrowse_api_root=$(JBROWSE_API_ROOT) \
	--define p3user_public_genome_dir=$(PUBLIC_GENOME_DIR) \
	--define p3user_newrelic_license_key=$(NEWRELIC_LICENSE_KEY) \
	--define p3user_num_workers=$(NUM_WORKERS) \
	--define p3user_queue_directory=$(QUEUE_DIRECTORY) \
	--define p3user_cache_enabled=$(CACHE_ENABLED) \
	--define p3user_cache_directory=$(CACHE_DIRECTORY) \
	--define p3user_service_url=$(P3USER_SERVICE_URL) \
	--define p3user_signing_private_pem=$(P3USER_SIGNING_PRIVATE_PEM) \
	--define p3user_signing_public_pem=$(P3USER_SIGNING_PUBLIC_PEM) \
	--define p3user_realm=$(P3USER_REALM) \
	--define p3_home_url=$(P3HOME_URL) \
	--define redis_host=$(REDIS_HOST) \
	--define redis_port=$(REDIS_PORT) \
	--define redis_db=$(REDIS_DB) \
	--define redis_pass=$(REDIS_PASS) \
	--define cookie_key=$(COOKIE_KEY) \
	--define cookie_secret=$(COOKIE_SECRET) \
	--define cookie_domain=$(COOKIE_DOMAIN) \
	$(TPAGE_SERVICE_LOGDIR)

# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
TOOLS_DIR = $(TOP_DIR)/tools
WRAP_PERL_TOOL = wrap_perl
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)


default: build-app build-config

build-app:
	if [ ! -f $(APP_DIR)/package.json ] ; then \
		git clone --recursive $(APP_REPO) $(APP_DIR); \
	fi
	if [ ! -f dme/package.json ] ; then \
		git clone --recursive $(DME_REPO) dme; \
	fi
	cd $(APP_DIR); \
		export PATH=$$KB_RUNTIME/build-tools/bin:$$PATH LD_LIBRARY_PATH=$$KB_RUNTIME/build-tools/lib64 ; \
		npm install; \
		npm install forever
	cd $(APP_DIR)/public; rm -f js; ln -s ../../../p3_web_service/p3_web/public/js .

dist: 

test: 

deploy: deploy-client deploy-service

deploy-all: deploy-client deploy-service

deploy-client: 

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done

deploy-service: deploy-run-scripts deploy-app deploy-config

deploy-app: build-app
	-mkdir -p $(SERVICE_APP_DIR)
	rsync --exclude .git --delete -arv $(APP_DIR)/. $(SERVICE_APP_DIR)

deploy-config: build-config
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(SERVICE_APP_DIR)/$(CONFIG)

build-config:
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(APP_DIR)/$(CONFIG)

deploy-run-scripts:
	for script in start_service stop_service postinstall; do \
		$(TPAGE) $(TPAGE_ARGS) service/$$script.tt > $(TARGET)/services/$(SERVICE_NAME)/$$script ; \
		chmod +x $(TARGET)/services/$(SERVICE_NAME)/$$script ; \
	done
	mkdir -p $(TARGET)/postinstall
	rm -f $(TARGET)/postinstall/$(SERVICE_NAME)
	ln -s ../services/$(SERVICE_NAME)/postinstall $(TARGET)/postinstall/$(SERVICE_NAME)


deploy-upstart: deploy-service
	-cp service/$(SERVICE_NAME).conf /etc/init/
	echo "done executing deploy-upstart target"

deploy-cfg:

deploy-docs:
	-mkdir -p $(TARGET)/services/$(SERVICE_DIR)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_DIR)/webroot/.


build-libs:

include $(TOP_DIR)/tools/Makefile.common.rules
