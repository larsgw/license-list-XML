TOOL_VERSION = 2.1.12
TEST_DATA = test/simpleTestForGenerator
GIT_AUTHOR = License Publisher (maintained by Gary O'Neall) <gary@sourceauditor.com>
LICENSE_DATA_REPO_NO_SCHEME = github.com/goneall/license-list-data.git
LICENSE_DATA_REPO = https://$(LICENSE_DATA_REPO_NO_SCHEME)
LICENSE_DATA_URL = https://$(GITHUB_TOKEN)@$(LICENSE_DATA_REPO_NO_SCHEME)
LICENSE_OUTPUT_DIR = .tmp
VERSION = $(shell git describe --always || echo 'UNKNOWN')
RELEASE_DATE = $(shell date '+%Y-%m-%d')
COMMIT_MSG = License list build $(VERSION) using license list publisher $(TOOL_VERSION)
RELEASE_MSG = Adding release matching the license list XML tag $(VERSION)
#TODO Change the license data repo to license-list-xml before merging pull request
	
.PHONY: validate-canonical-match
validate-canonical-match: licenseListPublisher-$(TOOL_VERSION).jar-valid resources/licenses-full.json $(TEST_DATA) $(LICENSE_OUTPUT_DIR)
	java -jar -DLocalFsfFreeJson=false -DlistedLicenseSchema="schema/ListedLicense.xsd" licenseListPublisher-$(TOOL_VERSION).jar LicenseRDFAGenerator src $(LICENSE_OUTPUT_DIR) 1.0 2000-01-01 $(TEST_DATA) expected-warnings

.PHONY: deploy-license-data
deploy-license-data: licenseListPublisher-$(TOOL_VERSION).jar-valid $(TEST_DATA) $(LICENSE_OUTPUT_DIR)	
	git clone $(LICENSE_DATA_URL) $(LICENSE_OUTPUT_DIR) --quiet --depth 1
	# Clean out the old data directories
	rm -r $(LICENSE_OUTPUT_DIR)/html
	rm -r $(LICENSE_OUTPUT_DIR)/json
	rm -r $(LICENSE_OUTPUT_DIR)/jsonld
	rm -r $(LICENSE_OUTPUT_DIR)/rdfa
	rm -r $(LICENSE_OUTPUT_DIR)/rdfnt
	rm -r $(LICENSE_OUTPUT_DIR)/rdfturtle
	rm -r $(LICENSE_OUTPUT_DIR)/rdfxml
	rm -r $(LICENSE_OUTPUT_DIR)/template
	rm -r $(LICENSE_OUTPUT_DIR)/text
	rm -r $(LICENSE_OUTPUT_DIR)/website
	rm $(LICENSE_OUTPUT_DIR)/licenses.md
	java -jar -DLocalFsfFreeJson=false -DlistedLicenseSchema="schema/ListedLicense.xsd" licenseListPublisher-$(TOOL_VERSION).jar LicenseRDFAGenerator src $(LICENSE_OUTPUT_DIR) $(VERSION) $(RELEASE_DATE) $(TEST_DATA) expected-warnings
	
	echo $(COMMIT_MSG)
	git -C "$(LICENSE_OUTPUT_DIR)" add -A .
	git -C "$(LICENSE_OUTPUT_DIR)" commit --author "$(GIT_AUTHOR)" -m "$(COMMIT_MSG)"
	echo Pushing updates to the license list data repository.  This could take a while...
	git -C "$(LICENSE_OUTPUT_DIR)" push --quiet origin
	
.PHONY: release-license-data
release-license-data: deploy-license-data
	if [[ $VERSION =~ .+-g[a-f0-9]{7} ]]
	then
		echo Can not release license data - license list version '$VERSION' does not match a release pattern
		exit 1
	else
		git -C "$(LICENSE_OUTPUT_DIR)" tag -a $(VERSION) -m "$(RELEASE_MESSAGE)"
		git -C "$(LICENSE_OUTPUT_DIR)" push --tags --quiet origin
	fi

.PRECIOUS: licenseListPublisher-%.jar
licenseListPublisher-%.jar:
	curl -L https://dl.bintray.com/spdx/spdx-tools/org/spdx/licenseListPublisher/$*/licenseListPublisher-$*-jar-with-dependencies.jar >$@

.PRECIOUS: licenseListPublisher-%.jar.asc
licenseListPublisher-%.jar.asc:
	curl -L https://dl.bintray.com/spdx/spdx-tools/org/spdx/licenseListPublisher/$*/licenseListPublisher-$*-jar-with-dependencies.jar.asc >$@

.PHONY: licenseListPublisher-%.jar-valid
licenseListPublisher-%.jar-valid: licenseListPublisher-%.jar.asc licenseListPublisher-%.jar goneall.gpg
	gpg --verify --no-default-keyring --keyring ./goneall.gpg $<

$(LICENSE_OUTPUT_DIR):
	mkdir -p $@

resources:
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(LICENSE_OUTPUT_DIR)

.PHONY: full-clean
full-clean: clean
	rm -rf resources licenseListPublisher-*.jar*
