# Fillora Azure Migration Guide - Complete Implementation

## ✅ Completed Steps

### Phase 1: Configuration ✅
- ✅ Updated `app_config.dart` with Azure endpoints and keys
- ✅ Created Azure service configuration structure

### Phase 2: Azure Services Created ✅
- ✅ `azure_openai_service.dart` - Replaces Google Gemini
- ✅ `azure_speech_service.dart` - Replaces Google STT/Flutter TTS
- ✅ `azure_vision_service.dart` - New OCR service
- ✅ `azure_form_recognizer_service.dart` - New form detection service
- ✅ `azure_blob_service.dart` - New file storage service

---

## 🔄 Migration Steps

### Step 1: Update AI Chat Service

**File:** `lib/services/ai_chat_service.dart`

**Change:**
```dart
// OLD: Import and use Gemini
import 'ai_chat_service.dart';
final aiService = AiChatService();

// NEW: Import and use Azure OpenAI
import 'azure_openai_service.dart';
final aiService = AzureOpenAiService();
```

**Update all usages:**
- The API is the same: `getResponse(String message, Map<String, dynamic>? context)`
- Just change the import and service instantiation

### Step 2: Update Voice Service

**File:** `lib/services/voice_service.dart`

**Change:**
```dart
// OLD: Using speech_to_text and flutter_tts packages
import 'voice_service.dart';
final voiceService = VoiceService();

// NEW: Using Azure Speech Services
import 'azure_speech_service.dart';
final voiceService = AzureSpeechService();
```

**Note:** Azure Speech Service requires:
- Audio recording implementation (use `record` or `flutter_sound` package)
- Audio playback implementation (use `audioplayers` or `just_audio` package)

### Step 3: Add Document Extraction

**Files using document extraction:**
- `document_upload_screen.dart`
- Any service that extracts fields from documents

**Add:**
```dart
import 'azure_form_recognizer_service.dart';
import 'azure_vision_service.dart';

// For form fields
final formRecognizer = AzureFormRecognizerService();
final fields = await formRecognizer.extractFieldsFromPdf(pdfBytes);

// For simple text extraction
final visionService = AzureVisionService();
final text = await visionService.extractTextFromImage(imageBytes);
```

### Step 4: Add File Storage

**Files uploading documents:**
- `document_upload_screen.dart`
- Any service saving files

**Add:**
```dart
import 'azure_blob_service.dart';

final blobService = AzureBlobService();
final fileUrl = await blobService.uploadPdf(pdfBytes, 'document.pdf');
```

### Step 5: Update Database Service

**File:** `lib/services/database_service.dart`

**For Azure SQL Database integration:**
- Add connection to Azure SQL
- Keep SQLite for offline mode
- Sync data between local and cloud

---

## 📋 Code Changes Required

### 1. Update Conversational Form Screen

**File:** `lib/screens/conversational_form_screen.dart`

```dart
// OLD
import '../services/ai_chat_service.dart';
final aiService = AiChatService();

// NEW
import '../services/azure_openai_service.dart';
final aiService = AzureOpenAiService();
```

### 2. Update Document Upload Screen

**File:** `lib/screens/document_upload_screen.dart`

```dart
// Add imports
import '../services/azure_form_recognizer_service.dart';
import '../services/azure_blob_service.dart';
import '../services/azure_vision_service.dart';

// When processing uploaded document:
final formRecognizer = AzureFormRecognizerService();
final blobService = AzureBlobService();

// Upload to Azure Blob
final fileUrl = await blobService.uploadPdf(documentBytes, fileName);

// Extract fields
final extractedFields = await formRecognizer.extractFieldsFromPdf(documentBytes);
```

### 3. Update Voice Input Usage

**File:** `lib/screens/conversational_form_screen.dart` (or wherever voice is used)

```dart
// OLD
import '../services/voice_service.dart';
final voiceService = VoiceService();

// NEW
import '../services/azure_speech_service.dart';
final voiceService = AzureSpeechService();
```

---

## 🔧 Configuration Setup

### 1. Azure Resources Setup

**Create these resources in Azure Portal:**

1. **Azure OpenAI**
   - Resource: Create Azure OpenAI resource
   - Deployment: Deploy GPT-4 or GPT-3.5 Turbo model
   - Get: Endpoint URL and API Key

2. **Azure Speech Services**
   - Resource: Create Speech Services resource
   - Get: Endpoint URL, API Key, Region

3. **Azure Computer Vision**
   - Resource: Create Computer Vision resource
   - Get: Endpoint URL and API Key

4. **Azure Form Recognizer** (Optional, but recommended)
   - Resource: Create Form Recognizer resource
   - Get: Endpoint URL and API Key

5. **Azure Blob Storage**
   - Storage Account: Create storage account
   - Container: Create container (e.g., `fillora-documents`)
   - Get: Connection String

6. **Azure SQL Database** (Optional)
   - Database: Create SQL Database
   - Get: Connection String

### 2. Update Configuration File

**File:** `lib/config/app_config.dart`

Replace all `YOUR_*` placeholders with actual values:

```dart
// Azure OpenAI
static const String azureOpenAiEndpoint = 'https://fillora-openai.openai.azure.com/';
static const String azureOpenAiApiKey = 'your-actual-api-key';
static const String azureOpenAiDeploymentName = 'gpt-4';

// Azure Speech
static const String azureSpeechEndpoint = 'https://fillora-speech.cognitiveservices.azure.com/';
static const String azureSpeechApiKey = 'your-actual-api-key';
static const String azureSpeechRegion = 'eastus';

// Azure Computer Vision
static const String azureVisionEndpoint = 'https://fillora-vision.cognitiveservices.azure.com/';
static const String azureVisionApiKey = 'your-actual-api-key';

// Azure Form Recognizer
static const String azureFormRecognizerEndpoint = 'https://fillora-formrecognizer.cognitiveservices.azure.com/';
static const String azureFormRecognizerApiKey = 'your-actual-api-key';

// Azure Blob Storage
static const String azureBlobStorageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=...';

// Azure SQL (if using)
static const String azureSqlConnectionString = 'Server=tcp:...';
```

### 3. Environment Variables (Optional)

For production, use environment variables instead of hardcoding:

```dart
import 'dart:io';

class AppConfig {
  static String get azureOpenAiApiKey => 
    Platform.environment['AZURE_OPENAI_API_KEY'] ?? 'YOUR_KEY_HERE';
  
  // ... similar for other keys
}
```

---

## 🚀 Testing Checklist

### Azure OpenAI
- [ ] Test chat responses in conversational form screen
- [ ] Verify context awareness
- [ ] Check error handling

### Azure Speech Services
- [ ] Test speech-to-text (requires audio recording setup)
- [ ] Test text-to-speech (requires audio playback setup)
- [ ] Check permission handling

### Azure Computer Vision
- [ ] Test image OCR
- [ ] Test PDF text extraction
- [ ] Verify text accuracy

### Azure Form Recognizer
- [ ] Test form field extraction
- [ ] Test PDF analysis
- [ ] Verify key-value pairs extraction

### Azure Blob Storage
- [ ] Test file upload
- [ ] Test file download
- [ ] Test file deletion
- [ ] Verify access permissions

---

## 📦 Additional Dependencies Needed

Add to `pubspec.yaml`:

```yaml
dependencies:
  # Audio recording for Azure Speech STT
  record: ^5.0.4  # or flutter_sound: ^9.2.13
  
  # Audio playback for Azure Speech TTS
  audioplayers: ^5.2.1  # or just_audio: ^0.9.36
  
  # For Azure Blob Storage (optional, can use REST API)
  # azure_storage_blob: ^1.0.0  # If available
```

---

## 🐛 Troubleshooting

### "API key not configured" error
- Check `app_config.dart` - all keys must be set
- Verify keys are correct in Azure Portal

### "Endpoint not configured" error
- Ensure endpoint URLs end with `/` or don't end with `/` consistently
- Check endpoint URLs match Azure Portal

### Azure Speech STT not working
- Ensure audio recording is implemented
- Check microphone permissions
- Verify audio format is supported

### Azure Blob upload fails
- Check connection string format
- Verify container exists
- Check storage account permissions

### Form Recognizer timeouts
- Increase retry count in service
- Check document size (may be too large)
- Verify API key has proper permissions

---

## 📝 Next Steps

1. **Complete Service Integration**
   - Update all screens to use new Azure services
   - Test thoroughly
   - Fix any integration issues

2. **Backend API (Optional)**
   - Create Azure App Service backend
   - Move some logic to backend
   - Implement authentication

3. **Browser Extension**
   - Create extension structure
   - Implement form detection
   - Connect to Azure services

4. **Deployment**
   - Set up Azure resources
   - Configure production keys
   - Deploy app

---

## ✅ Compliance with Imagine Cup 2026

**Requirements Met:**
- ✅ **2+ Microsoft AI Services**: Azure OpenAI, Azure Speech Services, Azure Computer Vision, Azure Form Recognizer
- ✅ **Microsoft Cloud**: Azure Blob Storage, Azure SQL Database
- ✅ **Built with Microsoft technologies**: All services use Azure

**This architecture fully complies with Imagine Cup 2026 requirements!**
