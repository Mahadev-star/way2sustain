import 'package:flutter/material.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLanguage = "English";

  final List<Map<String, dynamic>> _languages = [
    {"code": "en", "name": "English", "native": "English"},
    {"code": "es", "name": "Spanish", "native": "Español"},
    {"code": "fr", "name": "French", "native": "Français"},
    {"code": "de", "name": "German", "native": "Deutsch"},
    {"code": "zh", "name": "Chinese", "native": "中文"},
    {"code": "ja", "name": "Japanese", "native": "日本語"},
    {"code": "ko", "name": "Korean", "native": "한국어"},
    {"code": "ar", "name": "Arabic", "native": "العربية"},
    {"code": "hi", "name": "Hindi", "native": "हिन्दी"},
    {"code": "pt", "name": "Portuguese", "native": "Português"},
    {"code": "ru", "name": "Russian", "native": "Русский"},
    {"code": "it", "name": "Italian", "native": "Italiano"},
  ];

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF43A047);
    const Color backgroundColor = Color(0xFF151717);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Language",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Save language preference
              Navigator.pop(context);
            },
            child: const Text(
              "Save",
              style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.grey[900]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  hintText: "Search language...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Language List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final language = _languages[index];
                final isSelected = _selectedLanguage == language["name"];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.grey[900]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? brandGreen : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      language["name"]!,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      language["native"]!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: brandGreen)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = language["name"]!;
                      });
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                );
              },
            ),
          ),

          // Auto-detect Language Option
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.grey[900]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.public, color: Colors.grey),
                title: const Text(
                  "Auto-detect language",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Use device language setting",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Switch(
                  value: false,
                  activeThumbColor: brandGreen,
                  onChanged: (value) {
                    // Toggle auto-detect
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
