.PHONY: build run clean install-deps format release

build:
	xcodebuild -project Clipd.xcodeproj -scheme Clipd -configuration Release -derivedDataPath build/

run: build
	open build/Build/Products/Release/Clipd.app

clean:
	rm -rf build/
	xcodebuild clean -project Clipd.xcodeproj -scheme Clipd

install-deps:
	brew install gifsicle

format:
	swift-format format -i Clipd/*.swift

release:
	./scripts/release.sh
