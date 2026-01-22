# Fillora Azure Migration Plan - Imagine Cup 2026

## 📋 Requirements Analysis

### Imagine Cup 2026 Requirements:
- ✅ Must use **at least 2 Microsoft AI services**
- ✅ Built with Microsoft cloud and AI platforms
- ✅ Submission materials in English
- ✅ Demo video of MVP required

### Current Fillora Architecture:
- Mobile/Web App (Flutter)
- Browser Extension (planned)
- Profile storage and form parsing
- Conversation engine
- PDF/image extraction

---

## 🎯 Azure Services Mapping

### Required Microsoft AI Services (Minimum 2):

1. **Azure OpenAI Service** ✅ (Primary AI Service)
   - Replaces: Google Gemini
   - Usage: Conversational form filling, form understanding
   - API: Chat completions, embeddings

2. **Azure Speech Services** ✅ (Secondary AI Service)
   - Replaces: Google Speech-to-Text / Flutter TTS
   - Usage: Voice input (STT), voice output (TTS)
   - API: Speech-to-Text, Text-to-Speech

3. **Azure Computer Vision** ✅ (Tertiary AI Service - Bonus)
   - New service
   - Usage: PDF/image OCR, text extraction from documents
   - API: Read API for OCR

4. **Azure Form Recognizer** ✅ (Tertiary AI Service - Bonus)
   - New service
   - Usage: Intelligent form field detection and extraction
   - API: Document Analysis, Custom Models

### Additional Azure Services:

5. **Azure App Service** (Backend)
   - REST APIs for profile storage
   - Form parsing service
   - Conversation engine backend

6. **Azure Blob Storage** (File Storage)
   - PDF/image uploads
   - Document storage
   - Secure file access

7. **Azure SQL Database** (Primary Database)
   - User profiles
   - Form data
   - Template library

8. **Azure Cosmos DB** (Optional - for scale)
   - User profiles (alternative to SQL)
   - Session data
   - Analytics data

---

## 📦 Implementation Plan

### Phase 1: Update Dependencies & Configuration

**Files to Update:**
- `pubspec.yaml` - Add Azure SDK packages
- `lib/config/app_config.dart` - Azure endpoints and keys

**New Dependencies:**
```yaml
dependencies:
  # Azure SDKs
  azure_core: ^1.0.0
  azure_identity: ^1.0.0
  azure_storage_blob: ^1.0.0
  azure_cosmos: ^1.0.0
  
  # HTTP (existing, but will use for Azure APIs)
  http: ^1.2.0
  dio: ^5.4.0
```

### Phase 2: Replace AI Services

**1. Azure OpenAI Service** (Replace `ai_chat_service.dart`)
- Use Azure OpenAI REST API
- Model: `gpt-4` or `gpt-35-turbo`
- Endpoint: `https://[resource-name].openai.azure.com/`

**2. Azure Speech Services** (Replace `voice_service.dart`)
- Use Azure Speech SDK or REST API
- Speech-to-Text API
- Text-to-Speech API

**3. Azure Computer Vision** (New service: `azure_vision_service.dart`)
- Read API for OCR
- Extract text from PDFs/images

**4. Azure Form Recognizer** (New service: `azure_form_recognizer_service.dart`)
- Document Analysis API
- Prebuilt models for forms
- Custom model support

### Phase 3: Backend Services

**Create:**
- `backend/` directory structure
- Azure App Service deployment files
- REST API endpoints
- Authentication with Azure AD

### Phase 4: Storage Integration

**Update:**
- `database_service.dart` - Add Azure SQL integration
- New: `azure_blob_service.dart` - File uploads
- Update `offline_service.dart` - Sync with Azure

### Phase 5: Browser Extension

**Create:**
- `browser-extension/` directory
- Manifest files
- Content scripts
- Background service worker

---

## 🔧 Technical Implementation Details

### Service Replacements:

| Current Service | Azure Replacement | Service File |
|----------------|-------------------|--------------|
| Google Gemini | Azure OpenAI | `ai_chat_service.dart` |
| Google STT | Azure Speech Services | `voice_service.dart` |
| Flutter TTS | Azure Speech Services | `voice_service.dart` |
| Local SQLite | Azure SQL Database | `database_service.dart` |
| Local Files | Azure Blob Storage | `azure_blob_service.dart` (new) |
| Manual OCR | Azure Computer Vision | `azure_vision_service.dart` (new) |
| Manual Form Detection | Azure Form Recognizer | `azure_form_recognizer_service.dart` (new) |

---

## 📝 Next Steps

1. ✅ Create updated architecture document
2. ✅ Update dependencies in pubspec.yaml
3. ✅ Update app_config.dart with Azure endpoints
4. ✅ Replace ai_chat_service.dart with Azure OpenAI
5. ✅ Replace voice_service.dart with Azure Speech Services
6. ✅ Create azure_vision_service.dart
7. ✅ Create azure_form_recognizer_service.dart
8. ✅ Create azure_blob_service.dart
9. ✅ Update database_service.dart with Azure SQL
10. ✅ Create backend API structure
11. ✅ Create browser extension structure

---

## 🚀 Deployment Requirements

### Azure Resources Needed:
- Azure OpenAI resource (with GPT-4 or GPT-3.5 Turbo deployment)
- Azure Speech Services resource
- Azure Computer Vision resource
- Azure Form Recognizer resource (optional)
- Azure App Service (for backend APIs)
- Azure Blob Storage account
- Azure SQL Database (or Cosmos DB)

### Configuration:
- All API keys stored in Azure Key Vault
- Environment variables for different environments
- CORS configuration for web app
- Authentication with Azure AD B2C

---

**This plan ensures compliance with Imagine Cup 2026 requirements by using multiple Microsoft AI services.**
