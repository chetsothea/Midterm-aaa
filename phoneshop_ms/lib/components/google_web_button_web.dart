import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import '../hooks/language.dart';

// The login card's side margins and padding, around the button
const _cardInset = 80.0;

// On the web, Google only allows sign-in from the button it renders itself.
// A successful sign-in arrives on GoogleAuth.events, like on mobile.
//
// Google draws it once at a fixed width and allows at most 400px. It must fit the
// space it gets: any wider and its rounded ends are cut off.
Widget googleWebButton() => Builder(
  builder: (context) {
    // Not the full width of the card: just enough for the logo and the text
    final width = min(MediaQuery.sizeOf(context).width - _cardInset, 260.0);
    final english = AppLanguage.instance.isEnglish;
    return SizedBox(
      height: 54,
      child: Center(
        child: SizedBox(
          width: width,
          // A new width or language needs a new button: Google won't redraw the old one
          child: KeyedSubtree(
            key: ValueKey((width, english)),
            child: web.renderButton(
              configuration: web.GSIButtonConfiguration(
                // White with a thin outline, like the card it sits on
                theme: web.GSIButtonTheme.outline,
                text: web.GSIButtonText.continueWith,
                shape: web.GSIButtonShape.pill,
                size: web.GSIButtonSize.large,
                logoAlignment: web.GSIButtonLogoAlignment.left,
                // Google writes the text itself: in the app's language, not the browser's
                locale: english ? 'en' : 'km',
                minimumWidth: width,
              ),
            ),
          ),
        ),
      ),
    );
  },
);
