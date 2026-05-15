# Fillora.in - AI-Powered Form Assistant

**Forms, Filled in Seconds. AI-Powered Precision.**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/fillora)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android-green.svg)](https://www.android.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[📥 Download APK](https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m)

---

## 📱 About Fillora.in

**Fillora.in** is a revolutionary AI-powered mobile application that transforms the tedious process of form filling into a seamless, intelligent experience. Built with Flutter and powered by advanced AI, Fillora helps users complete complex forms in seconds with high accuracy, multi-language support, and a premium glassmorphic design.

### Why Fillora?
Filling out government, educational, or corporate forms is often frustrating and time-consuming. Fillora simplifies this by extracting data from your documents and guiding you through a conversational interface, ensuring you never miss a field or make a mistake again.

---

## ✨ Key Features

### 🤖 Intelligent Form Processing
- **AI-Powered OCR**: Automatically extracts data from IDs, certificates, and documents using advanced Optical Character Recognition.
- **Smart Auto-Fill**: Maps extracted data to form fields with high precision, saving minutes of manual typing.
- **Conversational Assistant**: A compassionate AI guide that talks you through the form-filling process step-by-step.

### 🎨 Premium User Experience
- **Glassmorphic UI**: A state-of-the-art design language featuring frosted glass effects, vibrant gradients, and smooth micro-animations.
- **Dynamic Theming**: Beautiful Dark and Light modes that adapt to your system settings.
- **Stateful Navigation**: Smooth, flicker-free tab switching using `StatefulShellRoute` to preserve your progress and scroll positions.

### 🔒 Security & Privacy
- **Secure App Lock**: Protect your sensitive form data with Biometric (Fingerprint/Face) authentication or a secure PIN.
- **Local-First Storage**: Your personal data stays on your device, encrypted and secure.
- **Granular Permissions**: You control exactly what the app can access.

### 🌐 Universal Accessibility
- **Multi-Language Support**: Support for 10+ major Indian languages, including Hindi, Tamil, Telugu, and more.
- **Voice-to-Text**: Fill forms entirely by speaking, perfect for hands-free operation or accessibility needs.
- **Text-to-Speech**: The AI assistant reads out questions and guidance for better clarity.

### 📚 Comprehensive Toolset
- **Template Library**: Hundreds of pre-built templates for common forms (Scholarships, Passports, Job Applications).
- **PDF Generation**: Instantly generate, preview, and share professional PDF versions of your completed forms.
- **Progress Tracking**: Never lose your place with real-time saving and progress indicators.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0 or higher)
- Android SDK (API 21+)
- A physical device or emulator

### Installation & Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/fillora.git
   cd fillora
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Environment**
   Create a `.env` file (if applicable) and add your AI service keys.

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 🏗️ Technical Architecture

### Core Technologies
- **Framework**: Flutter (Dart)
- **Navigation**: GoRouter (with ShellRoute implementation)
- **Local Database**: SQLite (Sqflite)
- **State Management**: Provider / StatefulWidget
- **AI/ML**: Custom REST API integration for Document Analysis
- **Design**: Material 3 with Custom Glassmorphism

### Project Structure
```
lib/
├── config/           # App configuration & constants
├── models/           # Data structures for forms, users, and stats
├── screens/          # UI Screens (Dashboard, Templates, Security, etc.)
├── services/         # Business logic (Auth, AI, PDF, AppLock, DB)
├── theme/            # Glassmorphic design tokens and colors
├── widgets/          # Reusable UI components (NavBar, Cards, SnackBar)
└── utils/            # Helper functions and extensions
```

---

## 🛠️ Security Hardening
Fillora takes security seriously. The repository is configured to protect sensitive information:
- **Environment Protection**: `.env` and configuration files are excluded from version control.
- **Keystore Security**: Production keys and certificates (`*.jks`, `*.pem`) are strictly ignored.
- **Credential Safety**: Service account JSONs and property files are never committed.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <p><b>Forms, Simplified. Privacy, Guaranteed.</b></p>
  <p>Made with ❤️ by Team FazEd</p>
  <a href="https://spec-team-fazed.vercel.app/">Website</a> • <a href="https://www.upload-apk.com/en/Sv3n0Ecf8qkPP2m">Download</a>
</div>
