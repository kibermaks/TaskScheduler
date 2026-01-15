#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Task Scheduler Release Helper${NC}"
echo ""

get_version() {
    grep "MARKETING_VERSION =" "TaskScheduler.xcodeproj/project.pbxproj" | head -n 1 | sed 's/.*= //;s/;//' | tr -d '[:space:]'
}

if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes.${NC}"
    echo "It's recommended to commit all changes before creating a release."
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

CURRENT_VERSION=$(get_version)
echo -e "Current version: ${GREEN}$CURRENT_VERSION${NC}"
echo ""

echo "What type of release is this?"
echo "  1) Major (breaking changes) - ${CURRENT_VERSION} → $(echo $CURRENT_VERSION | awk -F. '{print $1+1".0"}')"
echo "  2) Minor (new features) - ${CURRENT_VERSION} → $(echo $CURRENT_VERSION | awk -F. '{print $1"."$2+1}')"
echo "  3) Patch (bug fixes) - ${CURRENT_VERSION} → ${CURRENT_VERSION} (build number only)"
echo "  4) Custom version"
echo ""
read -p "Enter choice (1-4): " CHOICE

case $CHOICE in
    1)
        INCREMENT="major"
        ;;
    2)
        INCREMENT="minor"
        ;;
    3)
        INCREMENT="patch"
        ;;
    4)
        read -p "Enter new version (e.g., 1.5): " CUSTOM_VERSION
        INCREMENT="version $CUSTOM_VERSION"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}📝 Pre-release Checklist${NC}"
echo ""
echo "Before proceeding, ensure you have:"
echo "  ☐ Updated CHANGELOG.md with changes for this release"
echo "  ☐ Tested the app thoroughly"
echo "  ☐ Updated documentation if needed"
echo "  ☐ Committed all changes to git"
echo ""
read -p "Have you completed the checklist above? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please complete the checklist and try again."
    exit 1
fi

# Build the app
echo ""
echo -e "${BLUE}🔨 Building app...${NC}"
./build_app.sh $INCREMENT

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

NEW_VERSION=$(get_version)
echo ""
echo -e "${GREEN}✅ Built version $NEW_VERSION${NC}"

echo ""
echo -e "${BLUE}📦 Creating DMG...${NC}"
./create_dmg.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ DMG creation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Release artifacts created!${NC}"
echo ""
echo "The following files are ready:"
ls -lh dmg_output/*.dmg 2>/dev/null || echo "  (DMG not found)"
echo ""

echo -e "${BLUE}📚 Git Operations${NC}"
echo ""
read -p "Create git commit for version $NEW_VERSION? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    git add TaskScheduler.xcodeproj/project.pbxproj
    git commit -m "chore: bump version to $NEW_VERSION"
    echo -e "${GREEN}✅ Git commit created${NC}"
fi

read -p "Create and push git tag v$NEW_VERSION? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION"
    
    read -p "Push to remote? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        git push origin main
        git push origin "v$NEW_VERSION"
        echo -e "${GREEN}✅ Pushed to remote${NC}"
        echo ""
        echo -e "${BLUE}🎉 GitHub Actions will now build and create the release automatically!${NC}"
        echo ""
        echo "Check the progress at:"
        REPO_URL=$(git config --get remote.origin.url | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github.com\//')
        echo "  ${REPO_URL}/actions"
    fi
fi

echo ""
echo -e "${BLUE}📋 Next Steps${NC}"
echo ""
echo "1. Wait for GitHub Actions to complete the release build"
echo "2. Review the automatically created GitHub Release"
echo "3. Edit the release notes if needed"
echo "4. Announce the release to users"
echo ""
echo -e "${GREEN}🎉 Release process complete!${NC}"
