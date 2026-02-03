#!/bin/bash

# EUDI iOS SDK Setup Script
# This script helps integrate the EUDI Wallet Kit into your Flutter iOS app

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║        EUDI Wallet Kit iOS Integration Setup                          ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IOS_DIR="$SCRIPT_DIR/ios"

echo -e "${BLUE}This script will guide you through adding the EUDI Wallet Kit SDK.${NC}"
echo ""
echo "The EUDI Wallet Kit SDK must be added via Swift Package Manager in Xcode."
echo "This is because:"
echo "  • The SDK is distributed as an SPM package"
echo "  • It has dependencies that require SPM"
echo "  • Flutter's CocoaPods integration works alongside SPM"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}✗ Xcode is not installed or not in PATH${NC}"
    echo "  Please install Xcode from the App Store first."
    exit 1
fi
echo -e "${GREEN}✓ Xcode is installed${NC}"

# Check if workspace exists
if [ ! -d "$IOS_DIR/Runner.xcworkspace" ]; then
    echo -e "${YELLOW}! Runner.xcworkspace not found${NC}"
    echo "  Running pod install first..."
    cd "$IOS_DIR"
    pod install
    cd "$SCRIPT_DIR"
fi

if [ ! -d "$IOS_DIR/Runner.xcworkspace" ]; then
    echo -e "${RED}✗ Failed to create workspace${NC}"
    echo "  Please run 'cd ios && pod install' manually"
    exit 1
fi
echo -e "${GREEN}✓ Xcode workspace exists${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "                     MANUAL STEPS REQUIRED                              "
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "Please follow these steps to add the EUDI Wallet Kit SDK:"
echo ""
echo -e "${YELLOW}1. Open the Xcode workspace:${NC}"
echo "   $ open ios/Runner.xcworkspace"
echo ""
echo -e "${YELLOW}2. In Xcode, select the Runner project in the Project Navigator${NC}"
echo ""
echo -e "${YELLOW}3. Select the Runner target, then go to the 'Package Dependencies' tab${NC}"
echo ""
echo -e "${YELLOW}4. Click the '+' button to add a package${NC}"
echo ""
echo -e "${YELLOW}5. In the search field, enter:${NC}"
echo "   https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-kit.git"
echo ""
echo -e "${YELLOW}6. Select version rules:${NC}"
echo "   • Dependency Rule: 'Exact Version'"
echo "   • Version: 0.19.4"
echo "   (Or use 'Up to Next Major' for updates)"
echo ""
echo -e "${YELLOW}7. Click 'Add Package'${NC}"
echo ""
echo -e "${YELLOW}8. In the 'Choose Package Products' dialog:${NC}"
echo "   • Check 'EudiWalletKit'"
echo "   • Add to target: 'Runner'"
echo "   • Click 'Add Package'"
echo ""
echo -e "${YELLOW}9. Wait for Xcode to download and integrate the package${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""

read -p "Press Enter when you have completed the above steps..."

echo ""
echo "Checking if SDK was added..."

# Try to detect if the package was added
if [ -d "$IOS_DIR/Runner.xcworkspace/xcshareddata/swiftpm" ] || \
   [ -f "$IOS_DIR/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    echo -e "${GREEN}✓ Swift Package Manager configuration detected${NC}"
else
    echo -e "${YELLOW}⚠ Could not detect SPM configuration${NC}"
    echo "  If you added the package, you can ignore this warning."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "                        NEXT STEPS                                      "
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}After adding the SDK, you need to enable it in the code:${NC}"
echo ""
echo "1. Open: ios/Runner/EudiSsiApiImpl.swift"
echo ""
echo "2. Uncomment this line at the top:"
echo "   // import EudiWalletKit"
echo "   →  import EudiWalletKit"
echo ""
echo "3. Uncomment the TODO sections in the file:"
echo "   • initialize() method - Real SDK initialization"
echo "   • acceptCredentialOffer() method - Real credential issuance"
echo "   • getCredentials() method - Real credential fetching"
echo ""
echo "4. Build and run the app:"
echo "   $ flutter run"
echo ""
echo -e "${GREEN}Once complete, your iOS app will support:${NC}"
echo "  ✓ OAuth authorization via ASWebAuthenticationSession"
echo "  ✓ Real credential issuance from EUDI issuers"
echo "  ✓ Secure storage in iOS Secure Enclave"
echo "  ✓ OpenID4VCI and OpenID4VP protocols"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}Setup script completed!${NC}"
echo ""
echo "For more information, see:"
echo "  • docs/IOS_SDK_INTEGRATION_GUIDE.md"
echo "  • docs/OAUTH_CALLBACK_FIXES.md"
echo ""
