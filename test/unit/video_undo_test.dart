import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/video_editor/domain/subtitles.dart';
import 'package:lumora/features/video_editor/domain/video_project.dart';
import 'package:lumora/features/video_editor/presentation/video_editor_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A5: undo/redo coverage. Every mutating controller op must push exactly
/// one history step so a single undo restores the prior project bit-for-bit
/// (compared through JSON) and redo replays it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late ProviderContainer c;
  late VideoEditorController ctrl;
  setUp(() {
    c = ProviderContainer();
    addTearDown(c.dispose);
    ctrl = c.read(videoEditorControllerProvider.notifier);
    // Seed one 10 s clip as the baseline "present".
    ctrl.update(
      (p) => p.copyWith(
        clips: const [VideoClip(id: 'c1', path: 'a.mp4', sourceDurationMs: 10000, outMs: 10000)],
      ),
    );
  });

  VideoProject project() => c.read(videoEditorControllerProvider).project;

  /// Runs [op], asserts the project changed, then asserts undo restores the
  /// exact prior project and redo replays the change.
  void checkUndoable(String name, void Function() op) {
    final before = project().toJson();
    op();
    final after = project().toJson();
    expect(after, isNot(before), reason: '$name must change the project');
    ctrl.undo();
    expect(project().toJson(), before, reason: 'undo of $name');
    ctrl.redo();
    expect(project().toJson(), after, reason: 'redo of $name');
    ctrl.undo(); // leave the baseline for the next check
  }

  test('clip edits: split, stabilize, preset, keyframes, music', () {
    ctrl.seek(4000);
    checkUndoable('splitAtPlayhead', ctrl.splitAtPlayhead);
    checkUndoable('setStabilize', () => ctrl.setStabilize('c1', enabled: true, strength: 0.8));
    checkUndoable('applyPreset', () => ctrl.applyPreset('noir'));
    ctrl.seek(2000);
    checkUndoable('toggleKeyframeAtPlayhead', ctrl.toggleKeyframeAtPlayhead);
    ctrl.toggleKeyframeAtPlayhead();
    checkUndoable('clearKeyframes', ctrl.clearKeyframes);
    checkUndoable('setMusic', () => ctrl.setMusic('m.mp3'));
  });

  test('text and caption ops each form one undo step', () {
    checkUndoable('addText', () => ctrl.addText('hello'));
    final textId = ctrl.addText('hello');
    checkUndoable('updateText', () => ctrl.updateText(textId, (t) => t.copyWith(text: 'hi')));
    checkUndoable('removeText', () => ctrl.removeText(textId));

    final track = SubtitleTrack(
      language: 'en',
      cues: [
        const SubtitleCue(startMs: 500, endMs: 1500, text: 'one two'),
        const SubtitleCue(startMs: 2000, endMs: 3000, text: 'three'),
      ],
    );
    checkUndoable('setCaptions', () => ctrl.setCaptions('c1', track));
    ctrl.setCaptions('c1', track);
    final capId = project().texts.firstWhere((t) => t.id.startsWith('cap')).id;
    checkUndoable('shiftCaption', () => ctrl.shiftCaption(capId, 250));
    checkUndoable('splitCaption', () => ctrl.splitCaption(capId, 1000));
    checkUndoable('mergeCaption', () => ctrl.mergeCaption(capId));
    checkUndoable('styleCaptions', () => ctrl.styleCaptions(fontSize: 0.06));
    checkUndoable('removeAllCaptions', ctrl.removeAllCaptions);
  });

  test('live edits replace instead of stacking until commit', () {
    ctrl.setLookIntensity(0.2, live: true);
    ctrl.setLookIntensity(0.4, live: true);
    ctrl.setLookIntensity(0.6, live: true);
    ctrl.commit();
    // One undo returns to the baseline, not to each intermediate value.
    ctrl.undo();
    expect(project().lookIntensity, isNot(0.6));
    expect(project().clips, hasLength(1), reason: 'baseline project');
  });
}
