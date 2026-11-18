import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/theme.dart';
import '../hooks/language.dart';

// 🌐 in the top bar: a short menu with the two languages and their flags,
// the current one ticked
class LanguageButton extends StatelessWidget {
  final Color? color;

  const LanguageButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final english = AppLanguage.instance.isEnglish;
    return PopupMenuButton<bool>(
      tooltip: 'Language',
      icon: Icon(Icons.language, color: color),
      position: PopupMenuPosition.under,
      onSelected: AppLanguage.instance.setEnglish,
      itemBuilder: (context) => [
        for (final (value, label, flag) in [
          (false, 'ខ្មែរ', _cambodiaFlag),
          (true, 'English', _ukFlag),
        ])
          CheckedPopupMenuItem(
            value: value,
            checked: english == value,
            child: Row(
              children: [
                Flag(svg: flag, semanticLabel: label),
                const SizedBox(width: AppSpacing.sm),
                Text(label),
              ],
            ),
          ),
      ],
    );
  }
}

// A small flag with rounded corners and a hairline edge, so white parts show on white
class Flag extends StatelessWidget {
  final String svg;
  final String? semanticLabel;

  const Flag({super.key, required this.svg, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 19,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x33000000), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.string(
        svg,
        fit: BoxFit.cover,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}

// For other places that show the two languages (the account page's switch)
const cambodiaFlagSvg = _cambodiaFlag;
const ukFlagSvg = _ukFlag;

// Cambodia: blue, red, blue, with Angkor Wat in white (drawn simply, to read at this size)
const _cambodiaFlag = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 25 16">
  <rect width="25" height="16" fill="#032EA1"/>
  <rect y="4" width="25" height="8" fill="#E00025"/>
  <g fill="#fff">
    <rect x="7" y="10.3" width="11" height="0.9"/>
    <rect x="8" y="8.2" width="9" height="2.1"/>
    <polygon points="12.5,4.6 13.4,6.6 13.4,8.2 11.6,8.2 11.6,6.6"/>
    <polygon points="9.9,6 10.6,7.3 10.6,8.2 9.2,8.2 9.2,7.3"/>
    <polygon points="15.1,6 15.8,7.3 15.8,8.2 14.4,8.2 14.4,7.3"/>
    <polygon points="8.4,7 8.9,7.7 8.9,8.2 7.9,8.2 7.9,7.7"/>
    <polygon points="16.6,7 17.1,7.7 17.1,8.2 16.1,8.2 16.1,7.7"/>
  </g>
</svg>
''';

// United Kingdom
const _ukFlag = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 30">
  <clipPath id="t"><path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z"/></clipPath>
  <path d="M0,0 v30 h60 v-30 z" fill="#012169"/>
  <path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" stroke-width="6"/>
  <path d="M0,0 L60,30 M60,0 L0,30" clip-path="url(#t)" stroke="#C8102E" stroke-width="4"/>
  <path d="M30,0 v30 M0,15 h60" stroke="#fff" stroke-width="10"/>
  <path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6"/>
</svg>
''';
