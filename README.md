# ControlD MenuBar

A sleek macOS menu bar application for managing ControlD profiles and DNS filtering through the ControlD API.

## 🚀 Features

- **Menu Bar Integration**: Quick access from your macOS menu bar
- **Secure API Management**: Safe keychain storage for API tokens
- **Profile Management**: Easy switching between ControlD profiles  
- **One-Click Disable**: Temporarily disable profiles for 1 hour
- **Smart UI**: Scalable interface that handles large numbers of profiles
- **Auto-Validation**: Real-time API key validation and error handling
- **Modern Design**: Clean, native macOS interface with smooth animations

## 📋 Requirements

- macOS 11.0 Big Sur or later
- ControlD account with API access
- Xcode 13+ (for building from source)

## 📦 Installation

### Quick Install
```bash
git clone https://github.com/yourusername/controld-menubar.git
cd controld-menubar
./install_simple.sh
```

### Manual Build
```bash
# Clone repository
git clone https://github.com/yourusername/controld-menubar.git
cd controld-menubar

# Build application
./build.sh

# Install to Applications
cp -r "./ControlDMenuBar/build/Build/Products/Release/ControlD.app" /Applications/
```

## 🔑 Setup

1. **Get Your API Token**:
   - Log into [ControlD Dashboard](https://controld.com/dashboard)
   - Navigate to **Account Settings** → **API**
   - Generate a new API token

2. **Configure the App**:
   - Launch ControlD from your menu bar
   - Click **Configure Settings**
   - Enter your API token
   - Select your desired profile

## 🎯 Usage

### Basic Operations
- **Click menu bar icon**: Open control panel
- **Disable Profile**: Click "Disable Profile for 1 Hour"  
- **Re-enable**: Click "Re-enable Profile" (if disabled)
- **Settings**: Configure API key and select profiles

### Profile Management
- **Auto-Discovery**: Profiles load automatically after API validation
- **Search**: Find profiles quickly in large lists
- **Status Indicators**: See which profiles are currently disabled
- **One-Click Selection**: Easy profile switching

## 🛡️ Security

- Keychain integration for API tokens
- Secure memory handling
- Biometric authentication support
- Audit logging
- Network security

## 🔨 Development

```bash
./build.sh  # Build app
⌘U          # Run tests
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

## 📄 License

MIT License - see [LICENSE](LICENSE)

## Support

- Issues: [GitHub Issues](https://github.com/yourusername/controld-menubar/issues)
- ControlD: [controld.com/support](https://controld.com/support)
