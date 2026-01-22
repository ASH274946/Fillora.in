# Fillora Browser Extension

## Overview

Browser extension for Fillora that detects forms on web pages and allows users to fill them automatically using their Fillora profile.

## Features

- 🔍 Automatic form detection on web pages
- 📝 One-click form filling using Fillora profile
- 🔐 Secure authentication with Fillora account
- 🔄 Sync with mobile/web app
- 📋 Support for common form fields

## Architecture

```
browser-extension/
├── manifest.json          # Extension manifest
├── background/            # Background service worker
│   └── service-worker.js  # Main service worker
├── content/               # Content scripts
│   ├── form-detector.js   # Form detection logic
│   └── form-filler.js     # Form filling logic
├── popup/                 # Extension popup UI
│   ├── popup.html
│   ├── popup.js
│   └── popup.css
├── options/               # Options page
│   ├── options.html
│   ├── options.js
│   └── options.css
└── assets/                # Icons and images
    ├── icon-16.png
    ├── icon-48.png
    └── icon-128.png
```

## Supported Browsers

- Chrome/Chromium (Manifest V3)
- Edge (Manifest V3)
- Firefox (Manifest V2/V3)

## API Integration

The extension communicates with:
- Fillora Backend API (Azure App Service)
- Azure services for form processing
- User's Fillora profile

## Installation

1. Load unpacked extension in browser
2. Sign in with Fillora account
3. Grant necessary permissions
4. Start using on form pages

## Permissions

- `activeTab` - Access to current tab
- `storage` - Store user preferences
- `https://*.azurewebsites.net/*` - Backend API access

## Status

**Status**: 🚧 Structure created, implementation pending

This is a placeholder structure. Full implementation required for production.
