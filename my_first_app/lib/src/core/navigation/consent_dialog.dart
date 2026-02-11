import 'package:flutter/material.dart';
import 'route_guard.dart';

// Consent dialog and helper for Explore Discussion (opt-in AI).
// Responsibility:
// - Present a concise consent description to the user
// - If user accepts, persist consent for the current session (in-memory via ConsentService)
// - Returns `true` if accepted, `false` otherwise

Future<bool> showExploreConsentDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      title: const Text('Explore discussion — opt in'),
      content: const SingleChildScrollView(
        child: Text(
          'This guided feature uses AI to analyze the story and public comments. ' 
          'It is read-only and will not change original content. AI outputs are ' 
          'interpretations, not facts. Provenance and sources will be shown, and ' 
          'you can exit at any time.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Remember consent for this session only
            ConsentService.instance.setConsent(true);
            Navigator.of(context).pop(true);
          },
          child: const Text('Agree & explore'),
        ),
      ],
    ),
  );

  return result == true;
}
