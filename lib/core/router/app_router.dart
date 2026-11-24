import 'package:go_router/go_router.dart';
import 'package:lumora/core/shell/app_shell.dart';
import 'package:lumora/features/ai/presentation/models_page.dart';
import 'package:lumora/features/batch/presentation/batch_page.dart';
import 'package:lumora/features/collage/presentation/collage_page.dart';
import 'package:lumora/features/home/presentation/home_page.dart';
import 'package:lumora/features/home/presentation/projects_page.dart';
import 'package:lumora/features/home/presentation/templates_page.dart';
import 'package:lumora/features/onboarding/presentation/onboarding_page.dart';
import 'package:lumora/features/photo_editor/presentation/photo_editor_page.dart';
import 'package:lumora/features/scanner/presentation/scanner_page.dart';
import 'package:lumora/features/settings/presentation/error_log_page.dart';
import 'package:lumora/features/settings/presentation/settings_page.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_page.dart';
import 'package:material_ui/material_ui.dart';

/// One-tap actions started from the home screen.
enum QuickAction {
  removeBackground,
  autoEnhance,
  upscale,
  eraser,
  heal,
  cutOutPerson,
  blurBackground,
  retouch,

  // v1.3.x: quick actions for the tools added in 1.3.
  depthBlur,
  relight,
  selectObject,
  erasePerson,
}

/// Arguments for opening the photo editor.
class PhotoEditorArgs {
  const PhotoEditorArgs({this.sourcePath, this.projectId, this.initialAction, this.initialPresetId});
  final String? sourcePath;
  final String? projectId;

  /// Look applied right after the photo is open (from the Templates tab).
  final String? initialPresetId;

  /// Runs right after the photo is open.
  final QuickAction? initialAction;
}

/// Arguments for opening the video editor.
class VideoEditorArgs {
  const VideoEditorArgs({this.paths = const [], this.projectId});
  final List<String> paths;
  final String? projectId;
}

/// Root navigator: editors and secondary pages cover the bottom bar.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Builds the router. Tabs (`/`, `/templates`, `/projects`, `/settings`)
/// live in a [StatefulShellRoute] with the floating glass navigation bar;
/// every other route opens full screen above it. All v1.1 paths still
/// resolve to the same pages.
GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/templates', builder: (_, _) => const TemplatesPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsPage())],
        ),
      ],
    ),
    GoRoute(
      path: '/photo',
      builder: (_, state) => PhotoEditorPage(args: state.extra as PhotoEditorArgs? ?? const PhotoEditorArgs()),
    ),
    GoRoute(
      path: '/video',
      builder: (_, state) => VideoEditorPage(args: state.extra as VideoEditorArgs? ?? const VideoEditorArgs()),
    ),
    GoRoute(path: '/models', builder: (_, _) => const ModelsPage()),
    GoRoute(path: '/errors', builder: (_, _) => const ErrorLogPage()),
    GoRoute(path: '/welcome', builder: (_, _) => const OnboardingPage()),
    GoRoute(path: '/scan', builder: (_, _) => const ScannerPage()),
    GoRoute(path: '/collage', builder: (_, _) => const CollagePage()),
    GoRoute(path: '/batch', builder: (_, _) => const BatchPage()),
  ],
);
