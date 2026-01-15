# Quick Start Guide for Developers

A cheat sheet for common development tasks with Task Scheduler.

## 🚀 Common Commands

### Development

```bash
# Open in Xcode
open TaskScheduler.xcodeproj

# Build and run locally
./build_app.sh

# Build and deploy to Applications
./build_app.sh && ./deploy_app.sh

# Build specific version
./build_app.sh minor          # Bump minor version
./build_app.sh major          # Bump major version
./build_app.sh version 2.0    # Set specific version
```

### Distribution

```bash
# Create DMG installer
./create_dmg.sh

# Full release process (interactive)
./release.sh
```

### Git Operations

```bash
# Check status
git status

# Create release tag
git tag -a v1.0 -m "Release version 1.0"
git push origin v1.0

# List all tags
git tag -l
```

## 📁 Important Files

| File | Purpose |
|------|---------|
| `README.md` | Main project documentation |
| `CONTRIBUTING.md` | Contribution guidelines |
| `CHANGELOG.md` | Version history and changes |
| `Agents.md` | Critical info for AI agents/developers |
| `RELEASE_PROCESS.md` | Detailed release instructions |
| `LICENSE` | MIT License |
| `.github/workflows/` | GitHub Actions CI/CD |

## 🏗️ Project Structure

```
TaskScheduler/
├── TaskScheduler/              # Main source code
│   ├── Models/                 # Data models
│   ├── Services/               # Business logic
│   ├── Views/                  # SwiftUI views
│   └── Assets.xcassets/        # Images/icons
│
├── TaskScheduler.xcodeproj/    # Xcode project
├── build_app.sh               # Build script
├── deploy_app.sh              # Deployment script
├── create_dmg.sh              # DMG creation script
└── release.sh                 # Release automation
```

## 🔧 Development Workflow

### 1. Start New Feature

```bash
git checkout -b feature/my-feature
# Make changes in Xcode
```

### 2. Test Changes

```bash
./build_app.sh
# Test the built app
```

### 3. Commit Changes

```bash
git add .
git commit -m "feat: add my new feature"
```

### 4. Create Pull Request

```bash
git push origin feature/my-feature
# Open PR on GitHub
```

## 📦 Release Workflow

### Quick Release

```bash
./release.sh
# Follow interactive prompts
```

### Manual Release

```bash
# 1. Update CHANGELOG.md

# 2. Build
./build_app.sh minor

# 3. Create DMG
./create_dmg.sh

# 4. Commit and tag
git add .
git commit -m "chore: bump version to 1.1"
git tag -a v1.1 -m "Release version 1.1"

# 5. Push
git push origin main
git push origin v1.1

# GitHub Actions will handle the rest!
```

## 🐛 Common Issues

### "Build Failed" in Xcode

**Solution**: Clean build folder

- Xcode → Product → Clean Build Folder (Cmd+Shift+K)
- Delete `build_output/` directory
- Try building again

### "Code Signing Failed"

**Solution**: Build script handles signing automatically

- Use `./build_app.sh` instead of Xcode's build
- Or set Code Signing to "Sign to Run Locally" in Xcode

### "App Won't Launch" after install

**Solution**: Remove quarantine attribute

```bash
xattr -cr "/Applications/TaskScheduler.app"
```

### New Swift File Not Building

**Problem**: Added file but Xcode doesn't see it

**Solution**: Must update `project.pbxproj` (see Agents.md)

- Or use Xcode: File → Add Files to "TaskScheduler"

## 💡 Tips & Tricks

### Preview GitHub Actions Locally

```bash
# Install act: brew install act
act -l  # List workflows
act push -n  # Dry run
```

### Find Build Output

```bash
# Built app location
ls -la ./TaskScheduler.app
ls -la ./build_output/

# DMG location
ls -la ./dmg_output/
```

## 📚 Documentation Links

- **For New Contributors**: Start with [CONTRIBUTING.md](CONTRIBUTING.md)
- **For Releases**: See [RELEASE_PROCESS.md](RELEASE_PROCESS.md)
- **For Architecture**: Check [README.md](README.md#-architecture--key-elements)
- **For AI Agents**: Read [Agents.md](Agents.md) FIRST

## 🔗 Useful GitHub URLs

Replace `kibermaks` with your GitHub username:

- **Repository**: `https://github.com/kibermaks/TaskScheduler`
- **Issues**: `https://github.com/kibermaks/TaskScheduler/issues`
- **Actions**: `https://github.com/kibermaks/TaskScheduler/actions`
- **Releases**: `https://github.com/kibermaks/TaskScheduler/releases`
- **Discussions**: `https://github.com/kibermaks/TaskScheduler/discussions`

## 🎯 Next Steps

### First Time Setup

1. Clone the repo
2. Open in Xcode
3. Build with `./build_app.sh`
4. Read [CONTRIBUTING.md](CONTRIBUTING.md)
5. Check out [Issues](https://github.com/kibermaks/TaskScheduler/issues) for good first issues

### Making Your First Contribution

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Update documentation
6. Submit a pull request

### Creating Your First Release

1. Update CHANGELOG.md
2. Run `./release.sh`
3. Follow the prompts
4. Wait for GitHub Actions
5. Announce the release!

---

**Need Help?**

- Check the [documentation](#-documentation-links)
- Open a [GitHub Discussion](https://github.com/kibermaks/TaskScheduler/discussions)
- Read [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines
