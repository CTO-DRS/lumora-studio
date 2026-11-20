import 'package:flutter/foundation.dart';

/// Immutable undo/redo stack for any value type.
///
/// * [push] records a new present value and clears the redo branch.
/// * [replace] changes the present without creating an undo step – used while
///   a slider is being dragged; call [commit] at the end of the gesture so the
///   whole drag becomes a single undo step.
@immutable
class EditHistory<T> {
  factory EditHistory(T initial, {int maxDepth = 200}) => EditHistory._(const [], initial, const [], maxDepth, null);
  const EditHistory._(this._past, this.present, this._future, this.maxDepth, this._pendingBase);

  final List<T> _past;
  final T present;
  final List<T> _future;
  final int maxDepth;

  /// Value before an uncommitted transaction started (see [replace]).
  final T? _pendingBase;

  bool get canUndo => _past.isNotEmpty || _pendingBase != null;
  bool get canRedo => _future.isNotEmpty;
  int get undoDepth => _past.length;
  int get redoDepth => _future.length;
  bool get hasPendingTransaction => _pendingBase != null;

  EditHistory<T> push(T value) {
    final base = commit();
    if (value == base.present) return base;
    final past = [...base._past, base.present];
    final trimmed = past.length > maxDepth ? past.sublist(past.length - maxDepth) : past;
    return EditHistory._(trimmed, value, const [], maxDepth, null);
  }

  /// Updates the present value as part of a transaction (no undo step yet).
  EditHistory<T> replace(T value) => EditHistory._(_past, value, const [], maxDepth, _pendingBase ?? present);

  /// Closes a transaction started with [replace].
  EditHistory<T> commit() {
    final base = _pendingBase;
    if (base == null) return this;
    if (base == present) {
      return EditHistory._(_past, present, _future, maxDepth, null);
    }
    final past = [..._past, base];
    final trimmed = past.length > maxDepth ? past.sublist(past.length - maxDepth) : past;
    return EditHistory._(trimmed, present, const [], maxDepth, null);
  }

  EditHistory<T> undo() {
    final h = commit();
    if (h._past.isEmpty) return h;
    return EditHistory._(
      h._past.sublist(0, h._past.length - 1),
      h._past.last,
      [h.present, ...h._future],
      maxDepth,
      null,
    );
  }

  EditHistory<T> redo() {
    final h = commit();
    if (h._future.isEmpty) return h;
    return EditHistory._([...h._past, h.present], h._future.first, h._future.sublist(1), maxDepth, null);
  }

  /// Every recorded state, oldest first: undo steps, the present, then the
  /// redo branch. [currentIndex] points at the present.
  List<T> get timeline {
    final h = commit();
    return List.unmodifiable([...h._past, h.present, ...h._future]);
  }

  int get currentIndex => commit()._past.length;

  /// Moves the present to entry [index] of [timeline] without losing any
  /// step: everything after it stays redoable.
  EditHistory<T> jumpTo(int index) {
    final all = timeline;
    if (index < 0 || index >= all.length) return commit();
    return EditHistory._(all.sublist(0, index), all[index], all.sublist(index + 1), maxDepth, null);
  }

  /// Jumps back to the very first state while keeping everything redoable.
  EditHistory<T> resetTo(T value) => push(value);
}
