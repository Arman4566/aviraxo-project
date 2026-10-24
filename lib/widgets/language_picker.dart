import 'package:flutter/material.dart';

import '../core/prefs.dart';

/// English / हिन्दी switch. Shown on the first screens (sign in, welcome) so a person who does not read English can
/// change the language before doing anything else. The whole app follows immediately.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppPrefs.I.language,
      builder: (_, lang, __) => SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 'en', label: Text('English')),
          ButtonSegment(value: 'hi', label: Text('हिन्दी')),
        ],
        selected: {lang},
        onSelectionChanged: (v) => AppPrefs.I.setLanguage(v.first),
      ),
    );
  }
}
