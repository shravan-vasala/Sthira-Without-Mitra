import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_bottom_sheet.dart';

class GitaVerseSheet extends StatelessWidget {
  const GitaVerseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      scrollable: true,
      // intentionally NOT passing '2:47' to `title:` here. 
      // The verse reference, the shloka, and the interpretation 
      // form a unified centered composition. Forcing '2:47' into `title` 
      // drops it into 24/w800 left-aligned Cabinet Grotesk which breaks the composition.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '2:47',
            textAlign: TextAlign.center,
            style: context.text.screenTitle.copyWith(
              color: context.colors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'కర్మణ్యేవాధికారస్తే మా ఫలేషు కదాచన ।\nమా కర్మఫలహేతుర్భూర్మా తే సఙ్గోయస్త్వకర్మణి ॥',
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(
              color: context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "\"Krishna does not ask Arjuna to chase results - He asks him to master his focus. You can't control outcomes, but you can control the integrity of your effort. Do your karma, then let go.\"",
              textAlign: TextAlign.center,
              style: context.text.quote, 
            ),
          ),
        ],
      ),
    );
  }
}
