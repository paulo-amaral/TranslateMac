.PHONY: build test app run clean

build:
	swift build

test:
	swift test

app:
	scripts/make-app.sh

run: app
	open .build/TranslateMac.app

clean:
	swift package clean
