import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart'; // Import AppConfig for API key


class AzureTranslationService {
  static final AzureTranslationService _instance = AzureTranslationService._internal();
  factory AzureTranslationService() => _instance;
  AzureTranslationService._internal();

  // Mock dictionary for hackathon demo
  final Map<String, Map<String, String>> _mockDictionary = {
    'te': { // Telugu
      'Welcome to Fillora!': 'ఫిలోరాకి స్వాగతం!',
      'What is your name?': 'నీ పేరు ఏమిటి?',
      'My name is': 'నా పేరు',
      'Submit': 'సమర్పించు',
      'Voice input active': 'వాయిస్ ఇన్‌పుట్ సక్రియంగా ఉంది',
      'Hello': 'హలో',
      'Hi': 'హాయ్',
      'Help': 'సహాయం',
      'Yes': 'అవును',
      'No': 'కాదు',
      'Thanks': 'ధన్యవాదాలు',
      'I can help you with the form.': 'నేను మీకు ఫారమ్‌లో సహాయం చేయగలను.',
      // Form Fields
      'Mobile Number': 'మొబైల్ నంబర్',
      'Enter Mobile Number': 'మొబైల్ నంబర్ నమోదు చేయండి',
      'Email ID': 'ఇమెయిల్ ఐడి',
      'Enter Email ID': 'ఇమెయిల్ ఐడిని నమోదు చేయండి',
      'College': 'కళాశాల',
      'Select College': 'కళాశాలను ఎంచుకోండి',
      'Branch': 'బ్రాంచ్',
      'Enter Branch': 'బ్రాంచ్‌ని నమోదు చేయండి',
      'Year': 'సంవత్సరం',
      'Select Year': 'సంవత్సరాన్ని ఎంచుకోండి',
      'Gender': 'లింగం',
      'Select Gender': 'లింగాన్ని ఎంచుకోండి',
      'Faculty': 'అధ్యాపకులు',
      'Enter Faculty': 'అధ్యాపకులను నమోదు చేయండి',
      'College ID / Roll Number': 'కళాశాల ఐడి / రోల్ నంబర్',
      'Enter College ID / Roll Number': 'కళాశాల ఐడి / రోల్ నంబర్‌ని నమోదు చేయండి',
      'Student Name': 'విద్యార్థి పేరు',
      'Enter Student Name': 'విద్యార్థి పేరు నమోదు చేయండి',
      // Options & UI
      'Male': 'పురుషుడు',
      'Female': 'స్త్రీ',
      'Other': 'ఇతర',
      '1st Year': '1వ సంవత్సరం',
      '2nd Year': '2వ సంవత్సరం',
      '3rd Year': '3వ సంవత్సరం',
      '4th Year': '4వ సంవత్సరం',
      'Enter Student Name': 'విద్యార్థి పేరు నమోదు చేయండి',
      // Options & UI
      'Male': 'పురుషుడు',
      'Female': 'స్త్రీ',
      'Other': 'ఇతర',
      '1st Year': '1వ సంవత్సరం',
      '2nd Year': '2వ సంవత్సరం',
      '3rd Year': '3వ సంవత్సరం',
      '4th Year': '4వ సంవత్సరం',
      'Next': 'తరువాత',
      'Clear': 'ప్రశాంతంగా',
      'CSE': 'కంప్యూటర్ సైన్స్',
      'ECE': 'ఎలక్ట్రానిక్స్',
      'EEE': 'ఎలక్ట్రికల్',
      'Civil': 'సివిల్',
      'Mech': 'మెకానికల్',
      'St. Peter\'s Engineering College, Hyderabad': 'సెయింట్ పీటర్స్ ఇంజనీరింగ్ కాలేజ్, హైదరాబాద్',
      'Others': 'ఇతరులు',
    },
    'hi': { // Hindi
      'Welcome to Fillora!': 'फ़िलोरा में आपका स्वागत है!',
      'What is your name?': 'आपका नाम क्या है?',
      'My name is': 'मेरा नाम है',
      'Submit': 'जमा करें',
      'Voice input active': 'वॉयस इनपुट सक्रिय',
      'Hello': 'नमस्ते',
      'Hi': 'नमस्ते',
      'Help': 'मदद',
      'Yes': 'हाँ',
      'No': 'नहीं',
      'Thanks': 'धन्यवाद',
      'I can help you with the form.': 'मैं फॉर्म भरने में आपकी मदद कर सकता हूं।',
      'What would you like assistance with?': 'आप क्या मदद चाहते हैं?',
      // Form Fields
      'Mobile Number': 'मोबाइल नंबर',
      'Enter Mobile Number': 'मोबाइल नंबर दर्ज करें',
      'Email ID': 'ईमेल आईडी',
      'Enter Email ID': 'ईमेल आईडी दर्ज करें',
      'College': 'कॉलेज',
      'Select College': 'कॉलेज चुनें',
      'Branch': 'शाखा',
      'Enter Branch': 'शाखा दर्ज करें',
      'Year': 'वर्ष',
      'Select Year': 'वर्ष चुनें',
      'Gender': 'लिंग',
      'Select Gender': 'लिंग चुनें',
      'Faculty': 'संकाय',
      'Enter Faculty': 'संकाय दर्ज करें',
      'College ID / Roll Number': 'कॉलेज आईडी / रोल नंबर',
      'Enter College ID / Roll Number': 'कॉलेज आईडी / रोल नंबर दर्ज करें',
      'Student Name': 'छात्र का नाम',
      'Enter Student Name': 'छात्र का नाम दर्ज करें',
      // Options & UI
      'Male': 'पुरुष',
      'Female': 'महिला',
      'Other': 'अन्य',
      '1st Year': 'पहला साल',
      '2nd Year': 'दूसरा साल',
      '3rd Year': 'तीसरा साल',
      '4th Year': 'चौथा साल',
      'Next': 'अगला',
      'Clear': 'साफ़ करें',
      'CSE': 'कंप्यूटर विज्ञान',
      'ECE': 'इलेक्ट्रॉनिक्स',
      'EEE': 'बिजली',
      'Civil': 'सिविल',
      'Mech': 'यांत्रिक',
      'St. Peter\'s Engineering College, Hyderabad': 'सेंट पीटर्स इंजीनियरिंग कॉलेज, हैदराबाद',
      'Others': 'अन्य',
    },
    'ta': { // Tamil
      'Welcome to Fillora!': 'Fillora-விற்கு வரவேற்கிறோம்!',
      'What is your name?': 'உங்கள் பெயர் என்ன?',
      'My name is': 'என் பெயர்',
      'Submit': 'சமர்ப்பிக்கவும்',
      'Voice input active': 'குரல் உள்ளீடு செயலில் உள்ளது',
      'Hello': 'வணக்கம்',
      'Hi': 'வணக்கம்',
      'Help': 'உதவி',
      'Yes': 'ஆம்',
      'No': 'இல்லை',
      'Thanks': 'நன்றி',
      'I can help you with the form.': 'படிவத்தை நிரப்ப நான் உங்களுக்கு உதவ முடியும்.',
      // Form Fields
      'Mobile Number': 'மொபைல் எண்',
      'Enter Mobile Number': 'மொபைல் எண்ணை உள்ளிடவும்',
      'Email ID': 'மின்னஞ்சல் முகவரி',
      'Enter Email ID': 'மின்னஞ்சல் முகவரியை உள்ளிடவும்',
      'College': 'கல்லூரி',
      'Select College': 'கல்லூரியைத் தேர்ந்தெடுக்கவும்',
      'Branch': 'கிளை',
      'Enter Branch': 'கிளையை உள்ளிடவும்',
      'Year': 'ஆண்டு',
      'Select Year': 'ஆ ஆண்டைத் தேர்ந்தெடுக்கவும்',
      'Gender': 'பாலினம்',
      'Select Gender': 'பாலினத்தைத் தேர்ந்தெடுக்கவும்',
      'Faculty': 'ஆசிரியர்கள்',
      'Enter Faculty': 'ஆசிரியர்களை உள்ளிடவும்',
      'College ID / Roll Number': 'கல்லூரி ஐடி / ரோல் எண்',
      'Enter College ID / Roll Number': 'கல்லூரி ஐடி / ரோல் எண்ணை உள்ளிடவும்',
      'Student Name': 'மாணவர் பெயர்',
      'Enter Student Name': 'மாணவர் பெயரை உள்ளிடவும்',
      // Options & UI
      'Male': 'ஆண்',
      'Female': 'பெண்',
      'Other': 'மற்றவை',
      '1st Year': 'முதலாம் ஆண்டு',
      '2nd Year': 'இரண்ட இரண்டாம் ஆண்டு',
      '3rd Year': 'மூன்றாம் ஆண்டு',
      '4th Year': 'நான்காம் ஆண்டு',
      'Next': 'அடுத்தது',
      'Clear': 'அழி',
      'CSE': 'கணினி அறிவியல்',
      'ECE': 'மின்னணுவியல்',
      'EEE': 'மின்',
      'Civil': 'சிவில்',
      'Mech': 'இயந்திர',
      'St. Peter\'s Engineering College, Hyderabad': 'செயின்ட் பீட்டர்ஸ் பொறியியல் கல்லூரி, ஹைதராபாத்',
      'Others': 'மற்றவை',
    },
  };

  /// Translates text from source language to target language.
  /// Uses Azure Translator API (mocked for this implementation if key is missing).
  Future<String> translate({
    required String text,
    required String resultLanguage, // e.g., 'te', 'hi', 'en'
    String sourceLanguage = 'en',
  }) async {
    if (resultLanguage == sourceLanguage) return text;
    if (text.isEmpty) return text;

    try {
      // 1. Try Mock Dictionary first (for instant, reliable demo)
      if (_mockDictionary.containsKey(resultLanguage) && 
          _mockDictionary[resultLanguage]!.containsKey(text)) {
        return _mockDictionary[resultLanguage]![text]!;
      }
      
      // Reverse lookup for English output
      if (resultLanguage == 'en' && _mockDictionary.containsKey(sourceLanguage)) {
         final reversed = _mockDictionary[sourceLanguage]!.map((k, v) => MapEntry(v, k));
         if (reversed.containsKey(text)) {
           return reversed[text]!;
         }
      }

      // 2. Real Azure API Call (Simulated structure)
      // In a real app, you would uncomment this and add your key
      /*
      final uri = Uri.parse('https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=$resultLanguage');
      final response = await http.post(
        uri,
        headers: {
          'Ocp-Apim-Subscription-Key': 'YOUR_KEY',
          'Ocp-Apim-Subscription-Region': 'YOUR_REGION',
          'Content-Type': 'application/json',
        },
        body: jsonEncode([{'Text': text}]),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json[0]['translations'][0]['text'];
      }
      */

      // 3. Fallback: Use Gemini for Translation (since user has that key)
      // This ensures dynamic translation works without Azure Key
      if (AppConfig.geminiApiKey != 'DEPRECATED' && AppConfig.geminiApiKey.isNotEmpty) {
        return await _translateWithGemini(text, sourceLanguage, resultLanguage);
      }

      // 4. Final Fallback (Visual identifier)
      if (resultLanguage == 'en') {
        return text; 
      }
      return '[$resultLanguage] $text'; 
      
    } catch (e) {
      debugPrint('Translation Error: $e');
      return text; // Fail safe
    }
  }

  // Use Gemini as a translation engine
  Future<String> _translateWithGemini(String text, String source, String target) async {
    try {
      final apiKey = AppConfig.geminiApiKey;
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey';
      
      String prompt = "Translate the following text from ${source == 'auto' ? 'detected language' : source} to $target.\n"
          "Return ONLY the translated text. Do not include quotes, explanations, or any other text.\n\n"
          "Text: $text";

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
           String translated = data['candidates'][0]['content']['parts'][0]['text'];
           return translated.trim();
        }
      }
    } catch (e) {
      debugPrint('Gemini Translation Failed: $e');
    }
    return text; // Return original if fails
  }
}
