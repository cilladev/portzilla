.PHONY: run build test clean bundle

run:
	swift run Portzilla

build:
	swift build -c release

test:
	swift test

clean:
	rm -rf .build Portzilla.app

bundle: build
	@echo "Creating Portzilla.app bundle..."
	mkdir -p Portzilla.app/Contents/MacOS
	mkdir -p Portzilla.app/Contents/Resources
	cp .build/release/Portzilla Portzilla.app/Contents/MacOS/Portzilla
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > Portzilla.app/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> Portzilla.app/Contents/Info.plist
	@echo '<plist version="1.0">' >> Portzilla.app/Contents/Info.plist
	@echo '<dict>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>CFBundleIdentifier</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <string>com.palora.portzilla</string>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>CFBundleName</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <string>Portzilla</string>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>CFBundleShortVersionString</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <string>0.1.0</string>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>CFBundleExecutable</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <string>Portzilla</string>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>CFBundlePackageType</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <string>APPL</string>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>LSUIElement</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <true/>' >> Portzilla.app/Contents/Info.plist
	@echo '  <key>LSMinimumSystemVersion</key>' >> Portzilla.app/Contents/Info.plist
	@echo '  <string>13.0</string>' >> Portzilla.app/Contents/Info.plist
	@echo '</dict>' >> Portzilla.app/Contents/Info.plist
	@echo '</plist>' >> Portzilla.app/Contents/Info.plist
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns Portzilla.app/Contents/Resources/; fi
	@if [ -f Resources/AppIcon.png ]; then cp Resources/AppIcon.png Portzilla.app/Contents/Resources/; fi
	codesign --force --deep --sign - Portzilla.app
	@echo "Bundle created: Portzilla.app"
