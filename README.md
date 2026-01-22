# Fillora.in - AI-Powered Form Assistant

**Forms, Filled in Seconds**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/fillora)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android-green.svg)](https://www.android.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[📥 Download APK](https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m)

</div>

---

## 📱 About Fillora.in

**Fillora.in** is a revolutionary AI-powered mobile application that transforms the tedious process of form filling into a seamless, intelligent experience. Built with Flutter, Fillora helps users complete forms in seconds instead of minutes, with multi-language support and a compassionate, user-centric design.

### Key Highlights

- ⚡ **Smart Auto-Fill** - Automatically extracts and fills form data from documents
- 🤖 **AI Guidance** - Step-by-step help with conversational AI chat
- 🌍 **Multi-Language** - Support for 10+ languages
- 📚 **Template Library** - Pre-built form templates
- 🎤 **Voice Input** - Speech-to-text for hands-free form filling
- 🔒 **Secure & Private** - Biometric authentication and local data storage

---

## ✨ Features

### Core Features

- **Smart Document Processing**
  - Upload PDF, Image, or URL
   - Camera scan option
  - Real-time data extraction
  - AI-powered field detection

- **Intelligent Form Filling**
  - Auto-fill from documents
  - Context-aware suggestions
  - Field validation
  - Progress tracking

- **AI Assistant**
  - Conversational chat interface
  - Step-by-step guidance
  - Voice input support
  - Text-to-speech responses

- **Multi-Language Support**
  - English, Hindi, Tamil, Bengali, Telugu
  - Marathi, Gujarati, Kannada, Malayalam, Punjabi
  - And more...

- **Template Library**
  - Pre-built form templates
  - Category-based browsing
   - Search functionality
  - Popular forms

- **Export & Share**
  - PDF export
  - JSON, CSV, Text formats
  - Share functionality
  - Print support

- **Security & Privacy**
  - Biometric authentication
  - App lock feature
  - Local data storage
  - Secure form submission

---

## 📥 Download & Installation

### Download APK

**Direct Download**: [Download fillora.apk](https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m)

**File Details:**
- **Size**: 57.4 MB
- **Version**: 1.0.0+1
- **Platform**: Android
- **Minimum Android**: 5.0 (API 21+)

### Installation Instructions

1. **Download the APK**
   - Click the download link above
   - Or visit [Upload APK](https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m)

2. **Enable Unknown Sources**
   - Go to Settings → Security
   - Enable "Install from Unknown Sources" or "Allow from this source"

3. **Install the App**
   - Open the downloaded `fillora.apk` file
   - Tap "Install"
   - Wait for installation to complete

4. **Launch Fillora**
   - Open the app from your app drawer
   - Complete the onboarding process
   - Start filling forms!

### System Requirements

- Android 5.0 (Lollipop) or higher
- Minimum 100 MB free storage
- Internet connection (for AI features)
- Camera (optional, for document scanning)

---

## 🌐 Website

Visit our official website for more information, features, and updates:

**🌐 [Fillora.in Website](https://spec-team-fazed.vercel.app/)**

---

## 🏗️ Project Structure

```
Fillora/
├── android/                      # Android platform files
│   ├── app/
│   │   ├── src/
│   │   │   ├── main/
│   │   │   │   ├── kotlin/      # Kotlin source files
│   │   │   │   ├── res/         # Android resources
│   │   │   │   │   ├── drawable/    # Images and drawables
│   │   │   │   │   ├── values/      # Styles, colors, strings
│   │   │   │   │   └── mipmap/     # App icons
│   │   │   │   └── AndroidManifest.xml
│   │   │   └── build.gradle.kts
│   │   └── build.gradle.kts
│   └── build.gradle.kts
│
├── ios/                          # iOS platform files (future)
│   ├── Runner/
│   └── Runner.xcodeproj
│
├── lib/                          # Main Dart source code
│   ├── main.dart                 # App entry point
│   │
│   ├── config/                   # Configuration files
│   │   └── app_config.dart
│   │
│   ├── models/                   # Data models
│   │   └── form_model.dart      # Form data model
│   │
│   ├── screens/                  # App screens
│   │   ├── splash_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── signin_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── templates_screen.dart
│   │   ├── history_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── form_selection_screen.dart
│   │   ├── document_upload_screen.dart
│   │   ├── conversational_form_screen.dart
│   │   ├── review_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── security_screen.dart
│   │   ├── notifications_screen.dart
│   │   ├── app_lock_screen.dart
│   │   └── app_lock_setup_screen.dart
│   │
│   ├── services/                 # Business logic services
│   │   ├── auth_service.dart         # Authentication
│   │   ├── database_service.dart     # SQLite database
│   │   ├── ai_chat_service.dart      # AI chat functionality
│   │   ├── voice_service.dart        # Voice input/output
│   │   ├── pdf_service.dart          # PDF generation
│   │   ├── form_validation_service.dart
│   │   ├── search_service.dart
│   │   ├── export_service.dart
│   │   ├── analytics_service.dart
│   │   ├── template_service.dart
│   │   ├── language_service.dart
│   │   ├── app_lock_service.dart
│   │   └── app_logger_service.dart
│   │
│   ├── widgets/                  # Reusable widgets
│   │   ├── bottom_navigation.dart
│   │   ├── stat_card.dart
│   │   ├── action_card.dart
│   │   └── back_button_handler.dart
│   │
│   ├── theme/                    # Theme configuration
│   │   └── app_theme.dart        # App theming (dark/light)
│   │
│   └── utils/                     # Utility functions
│       └── onboarding_utils.dart
│
├── assets/                       # App assets
│   └── images/
│       └── logo.png              # App logo
│
├── test/                         # Unit and widget tests
│   └── widget_test.dart
│
├── web/                          # Web platform files
│   ├── index.html
│   └── manifest.json
│
├── Logo.png                      # Main app logo
│
├── pubspec.yaml                  # Flutter dependencies
├── pubspec.lock                  # Dependency lock file
├── analysis_options.yaml          # Linter configuration
│
└── README.md                     # This file
```

---

## 🛠️ Technology Stack

### Frontend
- **Framework**: [Flutter](https://flutter.dev/) (Cross-platform)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: Flutter StatefulWidget
- **Navigation**: [go_router](https://pub.dev/packages/go_router)
- **UI Components**: Material Design 3

### Backend & Services
- **Database**: [SQLite](https://www.sqlite.org/) (via [sqflite](https://pub.dev/packages/sqflite))
- **Authentication**: 
  - [google_sign_in](https://pub.dev/packages/google_sign_in)
  - [flutter_facebook_auth](https://pub.dev/packages/flutter_facebook_auth)
- **Voice Services**: 
  - [speech_to_text](https://pub.dev/packages/speech_to_text)
  - [flutter_tts](https://pub.dev/packages/flutter_tts)
- **File Processing**: 
  - [pdf](https://pub.dev/packages/pdf) - PDF generation
  - [printing](https://pub.dev/packages/printing) - PDF printing
  - [file_picker](https://pub.dev/packages/file_picker) - File selection
  - [image_picker](https://pub.dev/packages/image_picker) - Camera/Image selection

### Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^12.1.3              # Navigation
  shared_preferences: ^2.2.2      # Local storage
  sqflite: ^2.3.0                 # Database
  google_sign_in: ^6.3.0          # Google auth
  flutter_facebook_auth: ^7.0.0    # Facebook auth
  speech_to_text: ^7.0.0           # Voice input
  flutter_tts: ^4.0.2             # Text-to-speech
  pdf: ^3.11.1                    # PDF generation
  printing: ^5.12.0               # PDF printing
  file_picker: ^8.0.0             # File selection
  image_picker: ^1.0.7            # Camera
  google_fonts: ^6.1.0             # Typography
  intl: ^0.20.2                   # Internationalization
  uuid: ^3.0.7                    # Unique IDs
  local_auth: ^2.3.0              # Biometric auth
  flutter_secure_storage: ^9.0.0  # Secure storage
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- Android SDK (for Android development)
- Physical device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/fillora.git
   cd fillora
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Build for Release

**Android APK:**
```bash
flutter build apk --release
```

The APK will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

---

## 📱 Features in Detail

### 1. Smart Auto-Fill
- Automatically extracts data from uploaded documents
- AI-powered field detection and mapping
- High accuracy data extraction
- Support for multiple document formats

### 2. AI Guidance
- Conversational AI chat interface
- Context-aware responses
- Step-by-step form guidance
- Real-time assistance

### 3. Multi-Language Support
- 10+ languages supported
- Automatic language detection
- Language-aware fonts
- Localized UI elements

### 4. Template Library
- Pre-built form templates
- Category-based organization
- Search functionality
- Popular forms section

### 5. Voice Input
- Speech-to-text conversion
- Hands-free form filling
- Multiple language support
- Real-time transcription

### 6. Document Management
- PDF upload
- Image upload
- Camera scan
- URL-based extraction
- Document history

### 7. Export Options
- PDF export with formatting
- JSON export for data
- CSV export for spreadsheets
- Text export
- Share functionality

### 8. Security Features
- Biometric authentication
- App lock with PIN/Pattern
- Secure local storage
- Privacy controls

---

## 🎨 Design System

### Color Palette

- **Primary Orange**: `#FF8A00` - Active states, buttons, accents
- **Primary Indigo**: `#6366F1` - Secondary accents
- **Dark Background**: `#0B0B0C` - Main background
- **Dark Surface**: `#1A1A1B` - Cards, containers
- **Text Primary**: `#FFFFFF` - Main text
- **Text Secondary**: `#B0B0B0` - Secondary text

### Typography

- **Font Family**: [Poppins](https://fonts.google.com/specimen/Poppins) (Google Fonts)
- **Language-Aware**: Automatic font selection for different languages

### Design Principles

- Modern dark theme with orange accents
- Glassmorphism effects
- Smooth Material Design 3 animations
- Rounded corners (12-28px)
- Zero elevation with custom shadows
- Edge-to-edge display

---

## 📖 Documentation

### API Documentation

- [Authentication Service](docs/auth_service.md)
- [Database Service](docs/database_service.md)
- [AI Chat Service](docs/ai_chat_service.md)

### User Guides

- [Getting Started Guide](docs/getting_started.md)
- [Form Filling Tutorial](docs/form_filling.md)
- [Multi-Language Setup](docs/languages.md)

---

## 🧪 Testing

Run tests with:
```bash
flutter test
```

For widget tests:
```bash
flutter test test/widget_test.dart
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Contribution Guidelines

- Follow the existing code style
- Write meaningful commit messages
- Add tests for new features
- Update documentation as needed

---

## 👥 Team FazEd

Fillora.in is built with passion and innovation by **Team FazEd**.

### Team Members

- **L. Kiran Teja** - Main Developer
  - Architecting core functionality and AI integration

- **T. Keerthan Reddy** - UI/UX Developer
  - Crafting beautiful, intuitive interfaces

- **A. Ashwin Kumar** - Backend Developer
  - Building robust server infrastructure and APIs

### Our Mission

To leverage AI technology to simplify everyday tasks and help users save time while maintaining the highest standards of security and privacy.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Amazing cross-platform framework
- [Google Fonts](https://fonts.google.com/) - Poppins font family
- All the open-source packages that made this project possible
- Our beta testers and early users

---

## 📞 Contact & Support

- **Website**: [Fillora.in](https://spec-team-fazed.vercel.app/)
- **Download**: [APK Download Link](https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m)
- **Email**: [Your Email]
- **Issues**: [GitHub Issues](https://github.com/yourusername/fillora/issues)

---

## 🔮 Roadmap

### Upcoming Features

- [ ] iOS version
- [ ] Cloud sync
- [ ] More languages
- [ ] Enhanced AI capabilities
- [ ] Web version
- [ ] Form templates marketplace
- [ ] Team collaboration features
- [ ] Advanced analytics

### Version History

- **v1.0.0** (Current)
  - Initial release
  - Core form filling features
  - Multi-language support
  - Template library
  - AI guidance

---

## ⭐ Star History

If you find this project helpful, please consider giving it a star ⭐!

---

<div align="center">

**Made with ❤️ by Team FazEd**

[Website](https://spec-team-fazed.vercel.app/) • [Download](https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m) • [Documentation](#documentation)

</div>
