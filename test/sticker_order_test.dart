import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_order.dart';

void main() {
  test('moves an item towards the beginning', () {
    expect(reorderedIds([1, 2, 3, 4], 3, 1), [1, 4, 2, 3]);
  });

  test('moves an item towards the end', () {
    expect(reorderedIds([1, 2, 3, 4], 0, 3), [2, 3, 4, 1]);
  });

  test('returns a copy when the item stays in place', () {
    final ids = [1, 2, 3];

    final result = reorderedIds(ids, 1, 1);

    expect(result, ids);
    expect(identical(result, ids), isFalse);
  });

  test('moves one installed pack up or down', () {
    expect(movePackBy([1, 2, 3], 1, -1), [2, 1, 3]);
    expect(movePackBy([1, 2, 3], 1, 1), [1, 3, 2]);
  });

  test('does not move beyond either end', () {
    expect(movePackBy([1, 2, 3], 0, -1), [1, 2, 3]);
    expect(movePackBy([1, 2, 3], 2, 1), [1, 2, 3]);
  });
}
