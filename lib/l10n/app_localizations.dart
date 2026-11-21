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
  /// **'Open a photo or video to start. Your edits are saved automatically on this device.'**
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

  /// No description provided for @catFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get catFavorites;

  /// No description provided for @catEssentials.
  ///
  /// In en, this message translates to:
  /// **'Essentials'**
  String get catEssentials;

  /// No description provided for @catPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get catPortrait;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get catFilm;

  /// No description provided for @catVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get catVintage;

  /// No description provided for @catCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get catCinematic;

  /// No description provided for @catLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get catLandscape;

  /// No description provided for @catBw.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get catBw;

  /// No description provided for @catCreative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get catCreative;

  /// No description provided for @catCustom.
  ///
  /// In en, this message translates to:
  /// **'My presets'**
  String get catCustom;

  /// No description provided for @savePreset.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get savePreset;

  /// No description provided for @presetDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My look'**
  String get presetDefaultName;

  /// No description provided for @presetSaved.
  ///
  /// In en, this message translates to:
  /// **'Preset “{name}” saved'**
  String presetSaved(String name);

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get unfavorite;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @exportPresets.
  ///
  /// In en, this message translates to:
  /// **'Export presets'**
  String get exportPresets;

  /// No description provided for @importPresets.
  ///
  /// In en, this message translates to:
  /// **'Import presets'**
  String get importPresets;

  /// No description provided for @presetsImported.
  ///
  /// In en, this message translates to:
  /// **'{count} presets imported'**
  String presetsImported(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'Long-press any look to add it here'**
  String get noFavorites;

  /// No description provided for @copyEdits.
  ///
  /// In en, this message translates to:
  /// **'Copy edits'**
  String get copyEdits;

  /// No description provided for @pasteEdits.
  ///
  /// In en, this message translates to:
  /// **'Paste edits'**
  String get pasteEdits;

  /// No description provided for @editsCopied.
  ///
  /// In en, this message translates to:
  /// **'Edits copied'**
  String get editsCopied;

  /// No description provided for @editsPasted.
  ///
  /// In en, this message translates to:
  /// **'Edits pasted'**
  String get editsPasted;

  /// No description provided for @pasteWhat.
  ///
  /// In en, this message translates to:
  /// **'What to paste'**
  String get pasteWhat;

  /// No description provided for @pasteAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Light, color & look'**
  String get pasteAdjustments;

  /// No description provided for @pasteGeometry.
  ///
  /// In en, this message translates to:
  /// **'Crop & rotation'**
  String get pasteGeometry;

  /// No description provided for @pasteMasks.
  ///
  /// In en, this message translates to:
  /// **'Masks'**
  String get pasteMasks;

  /// No description provided for @pasteOverlays.
  ///
  /// In en, this message translates to:
  /// **'Text & stickers'**
  String get pasteOverlays;

  /// No description provided for @pasteFinishing.
  ///
  /// In en, this message translates to:
  /// **'Frame & watermark'**
  String get pasteFinishing;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all edits'**
  String get resetAll;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @photoPreview.
  ///
  /// In en, this message translates to:
  /// **'Photo preview'**
  String get photoPreview;

  /// No description provided for @pickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a color in the photo'**
  String get pickColor;

  /// No description provided for @pickColorHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a color in the photo, then drag up or down on it to adjust'**
  String get pickColorHint;

  /// No description provided for @hideMask.
  ///
  /// In en, this message translates to:
  /// **'Hide mask'**
  String get hideMask;

  /// No description provided for @showMask.
  ///
  /// In en, this message translates to:
  /// **'Show mask'**
  String get showMask;

  /// No description provided for @frameBorder.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get frameBorder;

  /// No description provided for @framePolaroid.
  ///
  /// In en, this message translates to:
  /// **'Polaroid'**
  String get framePolaroid;

  /// No description provided for @frameColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get frameColor;

  /// No description provided for @frameBlur.
  ///
  /// In en, this message translates to:
  /// **'Blurred photo'**
  String get frameBlur;

  /// No description provided for @frameWidth.
  ///
  /// In en, this message translates to:
  /// **'Border width'**
  String get frameWidth;

  /// No description provided for @cornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Rounded corners'**
  String get cornerRadius;

  /// No description provided for @watermarkText.
  ///
  /// In en, this message translates to:
  /// **'Watermark text'**
  String get watermarkText;

  /// No description provided for @watermarkLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get watermarkLogo;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @margin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get margin;

  /// No description provided for @healMode.
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get healMode;

  /// No description provided for @cloneMode.
  ///
  /// In en, this message translates to:
  /// **'Clone'**
  String get cloneMode;

  /// No description provided for @healHint.
  ///
  /// In en, this message translates to:
  /// **'Paint over blemishes, dust or small objects, then tap Apply'**
  String get healHint;

  /// No description provided for @cloneSetSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the photo to choose the area to copy from'**
  String get cloneSetSourceHint;

  /// No description provided for @clonePaintHint.
  ///
  /// In en, this message translates to:
  /// **'Paint where the source should be copied, then tap Apply'**
  String get clonePaintHint;

  /// No description provided for @setSource.
  ///
  /// In en, this message translates to:
  /// **'Set source'**
  String get setSource;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @histogram.
  ///
  /// In en, this message translates to:
  /// **'Histogram'**
  String get histogram;

  /// No description provided for @clippingWarnings.
  ///
  /// In en, this message translates to:
  /// **'Clipping warnings'**
  String get clippingWarnings;

  /// No description provided for @shadowClipping.
  ///
  /// In en, this message translates to:
  /// **'Crushed shadows'**
  String get shadowClipping;

  /// No description provided for @highlightClipping.
  ///
  /// In en, this message translates to:
  /// **'Blown highlights'**
  String get highlightClipping;

  /// No description provided for @histOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get histOriginal;

  /// No description provided for @histLayers.
  ///
  /// In en, this message translates to:
  /// **'Text & stickers'**
  String get histLayers;

  /// No description provided for @histPixels.
  ///
  /// In en, this message translates to:
  /// **'Retouch / AI'**
  String get histPixels;

  /// No description provided for @histOther.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get histOther;

  /// No description provided for @toolFrame.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get toolFrame;

  /// No description provided for @toolWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get toolWatermark;

  /// No description provided for @toolHeal.
  ///
  /// In en, this message translates to:
  /// **'Heal'**
  String get toolHeal;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @exportSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get exportSize;

  /// No description provided for @sizeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get sizeOriginal;

  /// No description provided for @sizeStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get sizeStory;

  /// No description provided for @fitPad.
  ///
  /// In en, this message translates to:
  /// **'Fit (add border)'**
  String get fitPad;

  /// No description provided for @fitCrop.
  ///
  /// In en, this message translates to:
  /// **'Fill (crop)'**
  String get fitCrop;

  /// No description provided for @saveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get saveToGallery;

  /// No description provided for @photoProjectName.
  ///
  /// In en, this message translates to:
  /// **'Photo · {date}'**
  String photoProjectName(String date);

  /// No description provided for @videoProjectName.
  ///
  /// In en, this message translates to:
  /// **'Video · {date}'**
  String videoProjectName(String date);

  /// No description provided for @copyOf.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String copyOf(String name);

  /// No description provided for @quickTools.
  ///
  /// In en, this message translates to:
  /// **'Quick tools'**
  String get quickTools;

  /// No description provided for @scanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan document'**
  String get scanDocument;

  /// No description provided for @collage.
  ///
  /// In en, this message translates to:
  /// **'Collage'**
  String get collage;

  /// No description provided for @batchEdit.
  ///
  /// In en, this message translates to:
  /// **'Batch edit'**
  String get batchEdit;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @noProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get noProjectsTitle;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @tipPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'100% on your device'**
  String get tipPrivateTitle;

  /// No description provided for @tipPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Every photo and video is processed on your phone. No cloud, no account, no tracking.'**
  String get tipPrivateBody;

  /// No description provided for @tipLooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Looks made from your photo'**
  String get tipLooksTitle;

  /// No description provided for @tipLooksBody.
  ///
  /// In en, this message translates to:
  /// **'Preview 45 looks live on your own photo, star your favorites and save your own presets.'**
  String get tipLooksBody;

  /// No description provided for @tipAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI that stays offline'**
  String get tipAiTitle;

  /// No description provided for @tipAiBody.
  ///
  /// In en, this message translates to:
  /// **'Remove backgrounds, erase objects, heal blemishes and upscale 4× — models download once and run on the device.'**
  String get tipAiBody;

  /// No description provided for @tipToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan, collage, batch'**
  String get tipToolsTitle;

  /// No description provided for @tipToolsBody.
  ///
  /// In en, this message translates to:
  /// **'Scan paper documents to PDF, build collages, and apply one look to many photos at once.'**
  String get tipToolsBody;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get haptics;

  /// No description provided for @exportDefaults.
  ///
  /// In en, this message translates to:
  /// **'Export defaults'**
  String get exportDefaults;

  /// No description provided for @exportMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Maximum size'**
  String get exportMaxSize;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary files'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'{size} freed'**
  String cacheCleared(String size);

  /// No description provided for @showTips.
  ///
  /// In en, this message translates to:
  /// **'Show tips again'**
  String get showTips;

  /// No description provided for @scanOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get scanOriginal;

  /// No description provided for @scanMagic.
  ///
  /// In en, this message translates to:
  /// **'Magic color'**
  String get scanMagic;

  /// No description provided for @scanNoShadow.
  ///
  /// In en, this message translates to:
  /// **'No shadows'**
  String get scanNoShadow;

  /// No description provided for @scanGray.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get scanGray;

  /// No description provided for @scanBw.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get scanBw;

  /// No description provided for @scanFitPage.
  ///
  /// In en, this message translates to:
  /// **'Fit page to image'**
  String get scanFitPage;

  /// No description provided for @scanSaveImages.
  ///
  /// In en, this message translates to:
  /// **'Save pages as images'**
  String get scanSaveImages;

  /// No description provided for @scanIntro.
  ///
  /// In en, this message translates to:
  /// **'Photograph a paper document. Edges are detected automatically, the page is flattened and cleaned up, then exported as a PDF — all on your device.'**
  String get scanIntro;

  /// No description provided for @scanCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get scanCamera;

  /// No description provided for @scanGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get scanGallery;

  /// No description provided for @scanCorners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get scanCorners;

  /// No description provided for @scanResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get scanResult;

  /// No description provided for @scanAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Edges were hard to find — drag the corners onto the page.'**
  String get scanAdjustHint;

  /// No description provided for @scanAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect edges'**
  String get scanAutoDetect;

  /// No description provided for @scanFullFrame.
  ///
  /// In en, this message translates to:
  /// **'Use whole photo'**
  String get scanFullFrame;

  /// No description provided for @scanAddPage.
  ///
  /// In en, this message translates to:
  /// **'Add page'**
  String get scanAddPage;

  /// No description provided for @cornerTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top-left corner'**
  String get cornerTopLeft;

  /// No description provided for @cornerTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top-right corner'**
  String get cornerTopRight;

  /// No description provided for @cornerBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom-right corner'**
  String get cornerBottomRight;

  /// No description provided for @cornerBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom-left corner'**
  String get cornerBottomLeft;

  /// No description provided for @batchDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} photos exported'**
  String batchDone(int done, int total);

  /// No description provided for @batchStart.
  ///
  /// In en, this message translates to:
  /// **'Export {count}'**
  String batchStart(int count);

  /// No description provided for @batchLook.
  ///
  /// In en, this message translates to:
  /// **'Look to apply'**
  String get batchLook;

  /// No description provided for @batchUseCopied.
  ///
  /// In en, this message translates to:
  /// **'Use copied edits'**
  String get batchUseCopied;

  /// No description provided for @batchNoCopied.
  ///
  /// In en, this message translates to:
  /// **'Copy edits in the photo editor first'**
  String get batchNoCopied;

  /// No description provided for @batchPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String batchPhotos(int count);

  /// No description provided for @batchAdd.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get batchAdd;

  /// No description provided for @batchIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick photos, choose a look or your copied edits, and export them all at full resolution.'**
  String get batchIntro;

  /// No description provided for @collageIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick up to 9 photos to arrange them in a layout with borders and a background.'**
  String get collageIntro;

  /// No description provided for @collagePick.
  ///
  /// In en, this message translates to:
  /// **'Choose photos'**
  String get collagePick;

  /// No description provided for @collageLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get collageLayout;

  /// No description provided for @collageBorder.
  ///
  /// In en, this message translates to:
  /// **'Borders'**
  String get collageBorder;

  /// No description provided for @collageSpacing.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get collageSpacing;

  /// No description provided for @frameSaved.
  ///
  /// In en, this message translates to:
  /// **'Frame saved to your gallery'**
  String get frameSaved;

  /// No description provided for @saveFrame.
  ///
  /// In en, this message translates to:
  /// **'Save frame as photo'**
  String get saveFrame;

  /// No description provided for @stabilize.
  ///
  /// In en, this message translates to:
  /// **'Stabilize'**
  String get stabilize;

  /// No description provided for @stabilizeHint.
  ///
  /// In en, this message translates to:
  /// **'Smooths shaky footage at export (two passes)'**
  String get stabilizeHint;

  /// No description provided for @lookStrength.
  ///
  /// In en, this message translates to:
  /// **'Filter strength'**
  String get lookStrength;

  /// No description provided for @keyframe.
  ///
  /// In en, this message translates to:
  /// **'Keyframe at playhead'**
  String get keyframe;

  /// No description provided for @clearKeyframes.
  ///
  /// In en, this message translates to:
  /// **'Clear keyframes'**
  String get clearKeyframes;

  /// No description provided for @keyframesHint.
  ///
  /// In en, this message translates to:
  /// **'{count} keyframes · move the playhead and change the strength to animate the filter'**
  String keyframesHint(int count);

  /// No description provided for @exportGif.
  ///
  /// In en, this message translates to:
  /// **'Animated GIF'**
  String get exportGif;

  /// No description provided for @exportGifHint.
  ///
  /// In en, this message translates to:
  /// **'480 px, 12 fps, first 30 s'**
  String get exportGifHint;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @aiErrDownload.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the AI model. Check your internet connection and try again.'**
  String get aiErrDownload;

  /// No description provided for @aiErrChecksum.
  ///
  /// In en, this message translates to:
  /// **'The downloaded AI model is damaged. Delete it in Settings › AI models and download it again.'**
  String get aiErrChecksum;

  /// No description provided for @aiErrNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'This tool needs its AI model. Download it first.'**
  String get aiErrNotDownloaded;

  /// No description provided for @aiErrSession.
  ///
  /// In en, this message translates to:
  /// **'This device couldn\'t load the AI model. If AI acceleration is on, turn it off in Settings and try again.'**
  String get aiErrSession;

  /// No description provided for @aiErrInference.
  ///
  /// In en, this message translates to:
  /// **'The AI model couldn\'t process this photo.'**
  String get aiErrInference;

  /// No description provided for @aiErrMemory.
  ///
  /// In en, this message translates to:
  /// **'Not enough memory for this photo. Try a smaller photo or close other apps.'**
  String get aiErrMemory;

  /// No description provided for @aiErrInput.
  ///
  /// In en, this message translates to:
  /// **'This photo couldn\'t be read.'**
  String get aiErrInput;

  /// No description provided for @modelNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Download AI model?'**
  String get modelNeededTitle;

  /// No description provided for @modelNeededBody.
  ///
  /// In en, this message translates to:
  /// **'This tool needs {names} ({size}). It is downloaded once and kept on this device. Your photos never leave the phone.'**
  String modelNeededBody(String names, String size);

  /// No description provided for @modelDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading AI model…'**
  String get modelDownloadingTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @errorLog.
  ///
  /// In en, this message translates to:
  /// **'Error log'**
  String get errorLog;

  /// No description provided for @errorLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent errors, stored only on this device'**
  String get errorLogSubtitle;

  /// No description provided for @errorLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No errors recorded.'**
  String get errorLogEmpty;

  /// No description provided for @errorLogCleared.
  ///
  /// In en, this message translates to:
  /// **'Error log cleared'**
  String get errorLogCleared;

  /// No description provided for @aiAcceleration.
  ///
  /// In en, this message translates to:
  /// **'AI acceleration (experimental)'**
  String get aiAcceleration;

  /// No description provided for @aiAccelerationHint.
  ///
  /// In en, this message translates to:
  /// **'Faster on some phones (XNNPACK). Turn it off if AI tools close the app.'**
  String get aiAccelerationHint;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get navTemplates;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create something new'**
  String get createTitle;

  /// No description provided for @createPhotoSub.
  ///
  /// In en, this message translates to:
  /// **'Open a photo from your gallery'**
  String get createPhotoSub;

  /// No description provided for @createVideoSub.
  ///
  /// In en, this message translates to:
  /// **'Trim, filter and join clips'**
  String get createVideoSub;

  /// No description provided for @createCollageSub.
  ///
  /// In en, this message translates to:
  /// **'Arrange several photos in one layout'**
  String get createCollageSub;

  /// No description provided for @createScanSub.
  ///
  /// In en, this message translates to:
  /// **'Turn paper into a clean PDF'**
  String get createScanSub;

  /// No description provided for @createBatchSub.
  ///
  /// In en, this message translates to:
  /// **'Apply one look to many photos'**
  String get createBatchSub;

  /// No description provided for @aiToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI tools'**
  String get aiToolsTitle;

  /// No description provided for @aiToolsShort.
  ///
  /// In en, this message translates to:
  /// **'AI tools'**
  String get aiToolsShort;

  /// No description provided for @onDevice.
  ///
  /// In en, this message translates to:
  /// **'Runs on your device'**
  String get onDevice;

  /// No description provided for @docScanner.
  ///
  /// In en, this message translates to:
  /// **'Document scanner'**
  String get docScanner;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchProjects.
  ///
  /// In en, this message translates to:
  /// **'Search projects'**
  String get searchProjects;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @allProjects.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get allProjects;

  /// No description provided for @noMatchingProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects match your search'**
  String get noMatchingProjects;

  /// No description provided for @templatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a look, then choose a photo to apply it to'**
  String get templatesSubtitle;

  /// No description provided for @modelNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Model download needed: {size}'**
  String modelNotInstalled(String size);

  /// No description provided for @noCustomPresets.
  ///
  /// In en, this message translates to:
  /// **'Save a look in the editor to see it here'**
  String get noCustomPresets;
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
