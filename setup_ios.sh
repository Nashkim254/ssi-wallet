#!/bin/bash

# iOS Setup Script for SSI Wallet
# This script helps prepare the iOS project for building

set -e

echo "🍎 iOS Setup Script for SSI Wallet"
echo "=================================="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script must be run on macOS"
    exit 1
fi

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "❌ CocoaPods not found"
    echo "📦 Installing CocoaPods..."
    sudo gem install cocoapods
fi

echo "✅ CocoaPods found: $(pod --version)"
echo ""

# Navigate to iOS directory
cd ios

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf Pods
rm -f Podfile.lock
rm -rf build
echo "✅ Cleaned"
echo ""

# Install pods
echo "📦 Installing CocoaPods dependencies..."
pod install
echo "✅ Pods installed"
echo ""

# Go back to root
cd ..

# Clean Flutter build
echo "🧹 Cleaning Flutter build cache..."
flutter clean
echo "✅ Flutter cleaned"
echo ""

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get
echo "✅ Dependencies fetched"
echo ""

echo "✅ iOS project setup complete!"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Open Xcode workspace:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. In Xcode, add these Swift files to the Runner target:"
echo "   • ios/Runner/SprucekitSsiApiImpl.swift"
echo "   • ios/Runner/SsiApi.swift (if not already added)"
echo ""
echo "3. Build and run:"
echo "   flutter run -d ios"
echo ""
echo "📖 For detailed instructions, see: docs/iOS_QUICK_SETUP.md"
echo ""
