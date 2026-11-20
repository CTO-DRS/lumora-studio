import 'package:lumora/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
