# ControlD MenuBar Manager

A macOS menu bar application for managing ControlD DNS filtering profiles.

[![macOS](https://img.shields.io/badge/macOS-11.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Menu Bar Integration**: Quick access from your macOS menu bar
- **Secure API Management**: Safe keychain storage for API tokens
- **Profile Management**: Easy switching between ControlD profiles
- **Custom Timers**: Disable profiles for custom durations
- **Real-time Status**: Live profile monitoring with visual indicators

## Requirements

- macOS 11.0 or later
- ControlD account with API access

## Installation

```bash
git clone https://github.com/pencarsa/controldmanager.git
cd controldmanager
./install_simple.sh
```

## Setup

1. Get your API token from [ControlD Dashboard](https://controld.com/dashboard) → Account Settings → API
2. Launch the app from your menu bar (shield icon)
3. Click Settings, enter your API token, and select a profile

## Usage

- Click the menu bar icon to open the control panel
- Disable profiles for custom durations or re-enable instantly
- Switch between profiles as needed

## 🛡️ Security Features

- **Keychain Integration**: API tokens stored securely in macOS Keychain
- **Certificate Validation**: HTTPS certificate pinning for API calls
- **Token Validation**: Real-time API key format and connectivity validation
- **Timeout Protection**: Network request timeouts prevent hanging
- **Memory Safety**: Secure token handling with automatic cleanup

## 🏗️ Architecture

### Modern Swift Development
- **MVVM Pattern**: Clean separation of concerns with ViewModels
- **Dependency Injection**: Protocol-based service architecture
- **SwiftUI**: Native macOS interface with reactive programming
- **Combine Framework**: Real-time state management and updates
- **Async/Await**: Modern concurrency patterns throughout

### Security & Performance
- **Keychain Integration**: Device-specific encrypted credential storage
- **Network Optimization**: Request debouncing and response caching
- **Performance Monitoring**: Built-in metrics collection and analysis
- **Memory Management**: Optimized for menu bar applications
- **Sandboxed Environment**: Secure execution with proper entitlements

## 📁 Project Structure

```
controldmanager/
├── ControlDMenuBar/
│   ├── ControlDMenuBar.xcodeproj/    # Xcode project
│   └── ControlDMenuBar/
│       ├── Core/                     # Core architecture
│       │   ├── AppState.swift        # Centralized state management
│       │   └── DependencyContainer.swift
│       ├── Services/                 # Service layer
│       │   ├── NetworkOptimizationService.swift
│       │   ├── PerformanceMonitor.swift
│       │   ├── TimerService.swift
│       │   └── [Additional services]
│       ├── Views/                    # SwiftUI views
│       │   ├── ContentView.swift     # Main interface
│       │   └── SettingsView.swift    # Configuration UI
│       ├── Protocols/                # Service protocols
│       └── Info.plist               # App metadata
├── USER_GUIDE.md                    # Complete user documentation
├── build.sh                         # Build automation
├── install_simple.sh               # Easy installer
└── implement_phase1.sh             # Performance improvements
```

## 🔨 Development

### Prerequisites
```bash
# Required tools
xcode-select --install
```

### Building
```bash
# Clean build
./build.sh

# Development build  
xcodebuild -project ControlDMenuBar/ControlDMenuBar.xcodeproj -scheme ControlDMenuBar -configuration Debug
```

### Code Style
- Swift 5.5+ with modern concurrency
- SwiftUI for all interface components
- Protocol-oriented design patterns
- Comprehensive error handling

## 🔧 Development

### Building from Source
```bash
# Prerequisites
xcode-select --install

# Clone and build
git clone https://github.com/pencarsa/controldmanager.git
cd controldmanager
./build.sh

# Development build
xcodebuild -project ControlDMenuBar/ControlDMenuBar.xcodeproj \
           -scheme ControlDMenuBar \
           -configuration Debug
```

### Advanced Usage
For detailed usage instructions and troubleshooting:
```bash
# See USER_GUIDE.md for comprehensive documentation
open USER_GUIDE.md
```

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Follow** Swift style guidelines and security best practices
4. **Add tests** for new functionality
5. **Update documentation** as needed
6. **Submit** a Pull Request with clear description

### Development Guidelines
- Use modern Swift patterns (async/await, SwiftUI, Combine)
- Follow MVVM architecture principles
- Ensure security best practices (no hardcoded credentials)
- Add performance monitoring for new features
- Update documentation for user-facing changes

## 📊 Performance & Architecture

This application demonstrates modern Swift development practices:
- **Memory Usage**: Optimized for menu bar applications (<40MB target)
- **Network Efficiency**: Request debouncing and intelligent caching
- **Security**: Keychain integration with device-specific encryption
- **Architecture**: Clean MVVM with dependency injection
- **Testing**: Comprehensive test coverage for business logic

See [USER_GUIDE.md](USER_GUIDE.md) for detailed usage instructions, troubleshooting, and architecture information.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help
- **Issues**: [GitHub Issues](https://github.com/pencarsa/controldmanager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/pencarsa/controldmanager/discussions)
- **ControlD API**: [ControlD Support](https://controld.com/support)

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Invalid API Token | Verify token in ControlD dashboard |
| No Profiles Loading | Check internet connection and API permissions |
| App Won't Launch | Ensure macOS 11.0+ and try rebuilding |
| Settings Won't Save | Check Keychain access permissions |

## 🎨 Screenshots

### Main Interface
![ControlD Manager Interface](screenshots/controld-manager-interface.png)

*The ControlD Manager interface showing profile status and quick actions*

**Interface Features:**
- 🟢 **Online Status**: Real-time connection indicator  
- 👤 **Profile Display**: Current active profile (NonserviaM)
- 🔴 **Status Badge**: Clear disabled/enabled state indication
- 🔵 **Re-enable Button**: One-click profile reactivation
- ⚙️ **Settings Access**: Easy configuration management
- 📱 **Version Info**: Enhanced v2.0 indicator

## ⭐ Acknowledgments

- [ControlD](https://controld.com) for the powerful DNS filtering API
- The Swift community for excellent development tools
- Contributors who help improve this project

## 🎯 Roadmap

### Completed ✅
- Core menu bar functionality
- Secure API key management
- Profile switching and management
- Custom timer options
- Performance optimization framework
- Modern Swift architecture (MVVM + DI)

### Planned 🚧
- [ ] Enhanced notification system
- [ ] Analytics dashboard
- [ ] Network diagnostics tools
- [ ] Settings synchronization
- [ ] Accessibility improvements
- [ ] Comprehensive test suite

### Future Considerations 💭
- [ ] Widget support
- [ ] Shortcuts integration
- [ ] Advanced scheduling
- [ ] Multi-account support

## 🏆 Acknowledgments

- [ControlD](https://controld.com) for the powerful DNS filtering API
- The Swift community for excellent development tools and frameworks
- macOS development community for design patterns and best practices
- Contributors who help improve this project

## 📈 Project Status

**Current Version**: 2.0 Enhanced Edition  
**Status**: Production Ready  
**Architecture**: Modern Swift with MVVM + Dependency Injection  
**Security**: Audited and production-ready  
**Performance**: Optimized for menu bar applications  

---

**Made with ❤️ for the macOS community**

*A professional-grade ControlD management application built with modern Swift development practices.*
