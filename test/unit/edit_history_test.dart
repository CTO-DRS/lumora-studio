import 'package:flutter_test/flutter_test.dart';
import 'package:lumora/features/photo_editor/domain/adjustments.dart';
import 'package:lumora/features/photo_editor/domain/edit_history.dart';
import 'package:lumora/features/photo_editor/domain/edit_state.dart';

void main() {
  group('EditHistory', () {
    test('push / undo / redo', () {
      var h = EditHistory<int>(0);
      expect(h.canUndo, isFalse);
      h = h.push(1).push(2).push(3);
      expect(h.present, 3);
      expect(h.undoDepth, 3);
      h = h.undo();
      expect(h.present, 2);
      expect(h.canRedo, isTrue);
      h = h.undo().undo();
      expect(h.present, 0);
      expect(h.canUndo, isFalse);
      h = h.undo(); // no-op
      expect(h.present, 0);
      h = h.redo().redo();
      expect(h.present, 2);
    });

    test('push clears the redo branch', () {
      var h = EditHistory<int>(0).push(1).push(2).undo();
      expect(h.canRedo, isTrue);
      h = h.push(5);
      expect(h.canRedo, isFalse);
      expect(h.undo().present, 1);
    });

    test('identical push is ignored', () {
      final h = EditHistory<int>(1).push(1);
      expect(h.undoDepth, 0);
    });

    test('replace + commit coalesces a gesture into one undo step', () {
      var h = EditHistory<int>(0);
      for (var i = 1; i <= 50; i++) {
        h = h.replace(i);
      }
      expect(h.present, 50);
      expect(h.hasPendingTransaction, isTrue);
      h = h.commit();
      expect(h.undoDepth, 1);
      expect(h.undo().present, 0);
    });

    test('undo during an open transaction commits first', () {
      final h = EditHistory<int>(0).replace(3).replace(4).undo();
      expect(h.present, 0);
      expect(h.redo().present, 4);
    });

    test('commit with unchanged value creates no step', () {
      final h = EditHistory<int>(7).replace(7).commit();
      expect(h.undoDepth, 0);
    });

    test('max depth is respected', () {
      var h = EditHistory<int>(0, maxDepth: 5);
      for (var i = 1; i <= 20; i++) {
        h = h.push(i);
      }
      expect(h.undoDepth, 5);
    });

    test('works with EditState values', () {
      var h = EditHistory(EditState.initial);
      h = h.push(h.present.copyWith(adjustments: const Adjustments(exposure: 1)));
      h = h.push(h.present.copyWith(adjustments: const Adjustments(exposure: 1, contrast: 0.5)));
      expect(h.undo().present.adjustments.contrast, 0);
      expect(h.undo().undo().present, EditState.initial);
    });
  });
}
