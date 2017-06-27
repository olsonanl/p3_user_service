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
APP_SCRIPT   = ./bin/p3-user

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

P3_USER_SERVICE_URL = http://$(SERVICE_HOSTNAME):$(SERVICE_PORT)
P3_HOME_URL = http://$(SERVICE_HOSTNAME):3000
P3_USER_SIGNING_PRIVATE_PEM = $(shell pwd)/test-private-nokey.pem 
P3_USER_SIGNING_PUBLIC_PEM = $(shell pwd)/test-public.pem 
P3_USER_SIGNING_SUBJECT_URL = $(P3_USER_SERVICE_URL)/public_key
P3_USER_REALM = patricbrc.org

P3_CALLBACK_URL = $(P3_HOME_URL)/auth/callback

COOKIE_SECRET = patric3
COOKIE_KEY = patric3
COOKIE_DOMAIN = $(shell echo $(SERVICE_HOSTNAME) | sed -e 's/^[^.][^.]*\././') 

EMAIL_LOCAL_SENDMAIL = true
EMAIL_DEFAULT_FROM = "PATRIC <do-not-reply@patricbrc.org>"
EMAIL_DEFAULT_SENDER = "PATRIC <do-not-reply@patricbrc.org>"
EMAIL_HOST = 
EMAIL_PORT = 25
EMAIL_USERNAME =
EMAIL_PASSWORD =

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
	--define p3_user_production=$(PRODUCTION) \
	--define p3_user_service_port=$(SERVICE_PORT) \
	--define p3_user_mongo_url=$(MONGO_URL) \
	--define p3_user_workspace_api_url=$(WORKSPACE_API_URL) \
	--define p3_user_distribute_url=$(DISTRIBUTE_URL) \
	--define p3_user_enable_indexer=$(ENABLE_INDEXER) \
	--define p3_user_jbrowse_api_root=$(JBROWSE_API_ROOT) \
	--define p3_user_public_genome_dir=$(PUBLIC_GENOME_DIR) \
	--define p3_user_newrelic_license_key=$(NEWRELIC_LICENSE_KEY) \
	--define p3_user_num_workers=$(NUM_WORKERS) \
	--define p3_user_queue_directory=$(QUEUE_DIRECTORY) \
	--define p3_user_cache_enabled=$(CACHE_ENABLED) \
	--define p3_user_cache_directory=$(CACHE_DIRECTORY) \
	--define p3_user_service_url=$(P3_USER_SERVICE_URL) \
	--define p3_user_signing_private_pem=$(P3_USER_SIGNING_PRIVATE_PEM) \
	--define p3_user_signing_public_pem=$(P3_USER_SIGNING_PUBLIC_PEM) \
	--define p3_user_realm=$(P3_USER_REALM) \
	--define p3_home_url=$(P3_HOME_URL) \
	--define redis_host=$(REDIS_HOST) \
	--define redis_port=$(REDIS_PORT) \
	--define redis_db=$(REDIS_DB) \
	--define redis_pass=$(REDIS_PASS) \
	--define cookie_key=$(COOKIE_KEY) \
	--define cookie_secret=$(COOKIE_SECRET) \
	--define cookie_domain=$(COOKIE_DOMAIN) \
	--define email_local_sendmail=$(EMAIL_LOCAL_SENDMAIL) \
	--define email_default_from=$(EMAIL_DEFAULT_FROM) \
	--define email_default_sender=$(EMAIL_DEFAULT_SENDER) \
	--define email_host=$(EMAIL_HOST) \
	--define email_port=$(EMAIL_PORT) \
	--define email_username=$(EMAIL_USERNAME) \
	--define email_password=$(EMAIL_PASSWORD) \
	$(TPAGE_SERVICE_LOGDIR)

# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
TOOLS_DIR = $(TOP_DIR)/tools
WRAP_PERL_TOOL = wrap_perl
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)


default: build-app build-config


build-app: $(APP_DIR)/package.json dme/package.json build-primary.tag build-forever.tag 

$(APP_DIR)/package.json:
	git clone $(APP_TAG) --recursive $(APP_REPO) $(APP_DIR); 
	ln -s $(APP_DIR) app

dme/package.json:
	git clone --recursive $(DME_REPO) dme; \

build-primary.tag:
	export PATH=$$KB_RUNTIME/build-tools/bin:$$PATH LD_LIBRARY_PATH=$$KB_RUNTIME/build-tools/lib64 ; \
	(cd $(APP_DIR); npm install; cd public; rm -f js; ln -s ../../../p3_web_service/app/public/js .) && touch build-primary.tag

build-forever.tag:
	export PATH=$$KB_RUNTIME/build-tools/bin:$$PATH LD_LIBRARY_PATH=$$KB_RUNTIME/build-tools/lib64 ; \
	(cd $(APP_DIR); npm install forever) && touch build-forever.tag

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
	rsync --exclude .git --delete -ar $(APP_DIR)/. $(SERVICE_APP_DIR)

deploy-config: build-config
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(SERVICE_APP_DIR)/$(CONFIG)

build-config:
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(APP_DIR)/$(CONFIG)

deploy-run-scripts:
	mkdir -p $(TARGET)/services/$(SERVICE_DIR)
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
