/// Returns a new list with the item at [from] inserted at [to].
List<int> reorderedIds(List<int> ids, int from, int to) {
  if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) {
    return List<int>.of(ids);
  }
  final result = List<int>.of(ids);
  result.insert(to, result.removeAt(from));
  return result;
}

/// Moves the item at [index] by one position, when the target is in range.
List<int> movePackBy(List<int> ids, int index, int delta) {
  final target = index + delta;
  if (delta.abs() != 1 ||
      index < 0 ||
      index >= ids.length ||
      target < 0 ||
      target >= ids.length) {
    return List<int>.of(ids);
  }
  return reorderedIds(ids, index, target);
}
