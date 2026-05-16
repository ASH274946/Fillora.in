class AppConfig {
  // ============================================
  // Azure Configuration - Imagine Cup 2026
  // ============================================
  
  // Azure OpenAI Configuration
  static const String azureOpenAiEndpoint = 'YOUR_AZURE_OPENAI_ENDPOINT'; // e.g., https://fillora-openai.openai.azure.com/
  static const String azureOpenAiApiKey = 'YOUR_AZURE_OPENAI_API_KEY';
  static const String azureOpenAiDeploymentName = 'gpt-4'; // or 'gpt-35-turbo'
  static const String azureOpenAiApiVersion = '2024-02-15-preview';
  
  // Azure Speech Services Configuration
  static const String azureSpeechEndpoint = 'YOUR_AZURE_SPEECH_ENDPOINT'; // e.g., https://fillora-speech.cognitiveservices.azure.com/
  static const String azureSpeechApiKey = 'YOUR_AZURE_SPEECH_API_KEY';
  static const String azureSpeechRegion = 'YOUR_AZURE_REGION'; // e.g., 'eastus'
  
  // Azure Computer Vision Configuration
  static const String azureVisionEndpoint = 'YOUR_AZURE_VISION_ENDPOINT'; // e.g., https://fillora-vision.cognitiveservices.azure.com/
  static const String azureVisionApiKey = 'YOUR_AZURE_VISION_API_KEY';
  
  // Azure Form Recognizer Configuration
  static const String azureFormRecognizerEndpoint = 'YOUR_AZURE_FORM_RECOGNIZER_ENDPOINT'; // e.g., https://fillora-formrecognizer.cognitiveservices.azure.com/
  static const String azureFormRecognizerApiKey = 'YOUR_AZURE_FORM_RECOGNIZER_API_KEY';
  
  // Azure Blob Storage Configuration
  static const String azureBlobStorageConnectionString = 'YOUR_AZURE_STORAGE_CONNECTION_STRING';
  static const String azureBlobStorageContainerName = 'fillora-documents';
  
  // Azure SQL Database Configuration
  static const String azureSqlConnectionString = 'YOUR_AZURE_SQL_CONNECTION_STRING';
  
  // Azure App Service Backend API
  static const String azureBackendApiUrl = 'YOUR_AZURE_APP_SERVICE_URL'; // e.g., https://fillora-api.azurewebsites.net/api/
  
  // Legacy Google Services (deprecated - will be removed)
  // [SECURITY] Removed hardcoded API key. Use environment variables.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  
  // NVIDIA NIM Configuration (OpenAI Compatible)
  // [SECURITY] Removed hardcoded API key. Use environment variables.
  static const String nvidiaApiKey = String.fromEnvironment('NVIDIA_API_KEY');
  static const String nvidiaBaseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String nvidiaModel = 'meta/llama-3.1-8b-instruct'; // Ultra-fast model
  
  @Deprecated('Use Azure Speech Services instead')
  static const String sttApiKey = 'DEPRECATED';
}

