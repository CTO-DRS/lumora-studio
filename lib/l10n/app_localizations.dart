import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Lumora Studio'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Pro photo & video editing. 100% on your device.'**
  String get tagline;

  /// No description provided for @editPhoto.
  ///
  /// In en, this message translates to:
  /// **'Edit photo'**
  String get editPhoto;

  /// No description provided for @editVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get editVideo;

  /// No description provided for @recentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent projects'**
  String get recentProjects;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet. Open a photo or video to start.'**
  String get noProjects;

  /// No description provided for @aiModels.
  ///
  /// In en, this message translates to:
  /// **'AI models'**
  String get aiModels;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @compare.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get compare;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Project saved'**
  String get saved;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get exported;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @toolPresets.
  ///
  /// In en, this message translates to:
  /// **'Looks'**
  String get toolPresets;

  /// No description provided for @toolAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get toolAdjust;

  /// No description provided for @toolHsl.
  ///
  /// In en, this message translates to:
  /// **'HSL'**
  String get toolHsl;

  /// No description provided for @toolCurves.
  ///
  /// In en, this message translates to:
  /// **'Curves'**
  String get toolCurves;

  /// No description provided for @toolCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get toolCrop;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @toolStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get toolStickers;

  /// No description provided for @toolDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get toolDraw;

  /// No description provided for @toolMasks.
  ///
  /// In en, this message translates to:
  /// **'Masks'**
  String get toolMasks;

  /// No description provided for @toolAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get toolAi;

  /// No description provided for @toolLut.
  ///
  /// In en, this message translates to:
  /// **'LUTs'**
  String get toolLut;

  /// No description provided for @toolEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get toolEffects;

  /// No description provided for @groupLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get groupLight;

  /// No description provided for @groupColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get groupColor;

  /// No description provided for @groupDetail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get groupDetail;

  /// No description provided for @groupEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get groupEffects;

  /// No description provided for @exposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get exposure;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @shadows.
  ///
  /// In en, this message translates to:
  /// **'Shadows'**
  String get shadows;

  /// No description provided for @whites.
  ///
  /// In en, this message translates to:
  /// **'Whites'**
  String get whites;

  /// No description provided for @blacks.
  ///
  /// In en, this message translates to:
  /// **'Blacks'**
  String get blacks;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @tint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get tint;

  /// No description provided for @vibrance.
  ///
  /// In en, this message translates to:
  /// **'Vibrance'**
  String get vibrance;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @fade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get fade;

  /// No description provided for @sharpen.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get sharpen;

  /// No description provided for @clarity.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get clarity;

  /// No description provided for @structure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get structure;

  /// No description provided for @dehaze.
  ///
  /// In en, this message translates to:
  /// **'Dehaze'**
  String get dehaze;

  /// No description provided for @blur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get blur;

  /// No description provided for @vignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get vignette;

  /// No description provided for @vignetteMidpoint.
  ///
  /// In en, this message translates to:
  /// **'Vignette size'**
  String get vignetteMidpoint;

  /// No description provided for @vignetteFeather.
  ///
  /// In en, this message translates to:
  /// **'Vignette feather'**
  String get vignetteFeather;

  /// No description provided for @grain.
  ///
  /// In en, this message translates to:
  /// **'Grain'**
  String get grain;

  /// No description provided for @grainSize.
  ///
  /// In en, this message translates to:
  /// **'Grain size'**
  String get grainSize;

  /// No description provided for @chromaticAberration.
  ///
  /// In en, this message translates to:
  /// **'Chromatic aberration'**
  String get chromaticAberration;

  /// No description provided for @glitch.
  ///
  /// In en, this message translates to:
  /// **'Glitch'**
  String get glitch;

  /// No description provided for @lutIntensity.
  ///
  /// In en, this message translates to:
  /// **'LUT intensity'**
  String get lutIntensity;

  /// No description provided for @duotone.
  ///
  /// In en, this message translates to:
  /// **'Duotone'**
  String get duotone;

  /// No description provided for @splitToning.
  ///
  /// In en, this message translates to:
  /// **'Split toning'**
  String get splitToning;

  /// No description provided for @shadowsHue.
  ///
  /// In en, this message translates to:
  /// **'Shadows hue'**
  String get shadowsHue;

  /// No description provided for @highlightsHue.
  ///
  /// In en, this message translates to:
  /// **'Highlights hue'**
  String get highlightsHue;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @luminance.
  ///
  /// In en, this message translates to:
  /// **'Luminance'**
  String get luminance;

  /// No description provided for @bandRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get bandRed;

  /// No description provided for @bandOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get bandOrange;

  /// No description provided for @bandYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get bandYellow;

  /// No description provided for @bandGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get bandGreen;

  /// No description provided for @bandAqua.
  ///
  /// In en, this message translates to:
  /// **'Aqua'**
  String get bandAqua;

  /// No description provided for @bandBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get bandBlue;

  /// No description provided for @bandPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get bandPurple;

  /// No description provided for @bandMagenta.
  ///
  /// In en, this message translates to:
  /// **'Magenta'**
  String get bandMagenta;

  /// No description provided for @curveMaster.
  ///
  /// In en, this message translates to:
  /// **'RGB'**
  String get curveMaster;

  /// No description provided for @curveRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get curveRed;

  /// No description provided for @curveGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get curveGreen;

  /// No description provided for @curveBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get curveBlue;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @importLut.
  ///
  /// In en, this message translates to:
  /// **'Import .cube LUT'**
  String get importLut;

  /// No description provided for @invalidLut.
  ///
  /// In en, this message translates to:
  /// **'Invalid LUT file'**
  String get invalidLut;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @flipH.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flipH;

  /// No description provided for @straighten.
  ///
  /// In en, this message translates to:
  /// **'Straighten'**
  String get straighten;

  /// No description provided for @perspectiveV.
  ///
  /// In en, this message translates to:
  /// **'Vertical perspective'**
  String get perspectiveV;

  /// No description provided for @perspectiveH.
  ///
  /// In en, this message translates to:
  /// **'Horizontal perspective'**
  String get perspectiveH;

  /// No description provided for @aspectFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get aspectFree;

  /// No description provided for @aspectOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get aspectOriginal;

  /// No description provided for @addText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get addText;

  /// No description provided for @editText.
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get editText;

  /// No description provided for @textHint.
  ///
  /// In en, this message translates to:
  /// **'Type something…'**
  String get textHint;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @removeLayer.
  ///
  /// In en, this message translates to:
  /// **'Remove layer'**
  String get removeLayer;

  /// No description provided for @brushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size'**
  String get brushSize;

  /// No description provided for @eraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get eraser;

  /// No description provided for @softness.
  ///
  /// In en, this message translates to:
  /// **'Softness'**
  String get softness;

  /// No description provided for @maskBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get maskBrush;

  /// No description provided for @maskLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get maskLinear;

  /// No description provided for @maskRadial.
  ///
  /// In en, this message translates to:
  /// **'Radial'**
  String get maskRadial;

  /// No description provided for @maskSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject (AI)'**
  String get maskSubject;

  /// No description provided for @invertMask.
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get invertMask;

  /// No description provided for @feather.
  ///
  /// In en, this message translates to:
  /// **'Feather'**
  String get feather;

  /// No description provided for @addMask.
  ///
  /// In en, this message translates to:
  /// **'Add mask'**
  String get addMask;

  /// No description provided for @aiAutoEnhance.
  ///
  /// In en, this message translates to:
  /// **'Auto enhance'**
  String get aiAutoEnhance;

  /// No description provided for @aiRemoveBg.
  ///
  /// In en, this message translates to:
  /// **'Remove background'**
  String get aiRemoveBg;

  /// No description provided for @aiPortraitBg.
  ///
  /// In en, this message translates to:
  /// **'Portrait cutout'**
  String get aiPortraitBg;

  /// No description provided for @aiUpscale.
  ///
  /// In en, this message translates to:
  /// **'Upscale 4×'**
  String get aiUpscale;

  /// No description provided for @aiEraser.
  ///
  /// In en, this message translates to:
  /// **'Object eraser'**
  String get aiEraser;

  /// No description provided for @aiRetouch.
  ///
  /// In en, this message translates to:
  /// **'Portrait retouch'**
  String get aiRetouch;

  /// No description provided for @aiBlurBg.
  ///
  /// In en, this message translates to:
  /// **'Blur background'**
  String get aiBlurBg;

  /// No description provided for @aiEraserHint.
  ///
  /// In en, this message translates to:
  /// **'Paint over what you want to remove, then tap Apply.'**
  String get aiEraserHint;

  /// No description provided for @aiWorking.
  ///
  /// In en, this message translates to:
  /// **'Running on-device AI…'**
  String get aiWorking;

  /// No description provided for @aiFailed.
  ///
  /// In en, this message translates to:
  /// **'AI step failed: {error}'**
  String aiFailed(String error);

  /// No description provided for @downloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadModel;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String downloading(String percent);

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @modelsInfo.
  ///
  /// In en, this message translates to:
  /// **'Models are downloaded once from Hugging Face, verified with SHA-256 and run fully offline. Your photos never leave the device.'**
  String get modelsInfo;

  /// No description provided for @needsModel.
  ///
  /// In en, this message translates to:
  /// **'This feature needs the model “{name}” ({size} MB). Download now?'**
  String needsModel(String name, String size);

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get exportFormat;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @keepExif.
  ///
  /// In en, this message translates to:
  /// **'Keep EXIF metadata'**
  String get keepExif;

  /// No description provided for @fullResolution.
  ///
  /// In en, this message translates to:
  /// **'Full resolution'**
  String get fullResolution;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exporting;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'Open-source (MIT). No cloud, no analytics, no tracking.'**
  String get aboutText;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @trim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get trim;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @reverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get reverse;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @addClip.
  ///
  /// In en, this message translates to:
  /// **'Add clip'**
  String get addClip;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @addMusic.
  ///
  /// In en, this message translates to:
  /// **'Add music'**
  String get addMusic;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @originalAudio.
  ///
  /// In en, this message translates to:
  /// **'Original audio'**
  String get originalAudio;

  /// No description provided for @transition.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get transition;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @aspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get aspectRatio;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @exportFast.
  ///
  /// In en, this message translates to:
  /// **'Fast (FFmpeg filters)'**
  String get exportFast;

  /// No description provided for @exportStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio (GPU shaders, exact)'**
  String get exportStudio;

  /// No description provided for @videoExported.
  ///
  /// In en, this message translates to:
  /// **'Video saved to your gallery'**
  String get videoExported;

  /// No description provided for @videoTextHint.
  ///
  /// In en, this message translates to:
  /// **'Title…'**
  String get videoTextHint;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @deleteProjectQ.
  ///
  /// In en, this message translates to:
  /// **'Delete this project?'**
  String get deleteProjectQ;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String errorGeneric(String error);

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project {date}'**
  String projectName(String date);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
