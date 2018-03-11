
release:
	git archive HEAD plugin autoload doc --output=open-browser-github-$(shell git describe --tags HEAD).zip

.PHONY: release
