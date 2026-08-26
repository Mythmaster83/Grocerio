import '../entities/canonical_item.dart';

/// Lowercase, strip punctuation, collapse whitespace. Exposed because the seed
/// loader and the resolver must normalize identically — if they drift, exact
/// matches silently stop working.
String normalizeItemName(String raw) {
  final lowered = raw.toLowerCase();
  final buffer = StringBuffer();
  var lastWasSpace = true;
  for (final code in lowered.codeUnits) {
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLetter = code >= 0x61 && code <= 0x7A;
    if (isDigit || isLetter) {
      buffer.writeCharCode(code);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      buffer.write(' ');
      lastWasSpace = true;
    }
  }
  return buffer.toString().trim();
}

/// Maps a shopper's free text ("bannanas", "whole milk") onto a [CanonicalItem]
/// so price reports from different people land on the same record.
///
/// Pure and catalog-agnostic: the caller supplies the catalog. That keeps the
/// matching rules unit-testable with a three-item fixture instead of needing a
/// database, and it's the only reason this can live in `domain/`.
///
/// **Returning null is a success case.** A wrong match is worse than no match:
/// it attaches someone's milk price to their laundry detergent, and unlike a
/// missing price that error is invisible.
class ItemResolutionService {
  const ItemResolutionService();

  /// Length below which fuzzy matching is refused entirely — at three letters,
  /// edit distance 1 relates "can", "cat", and "cap".
  static const _minFuzzyLength = 5;

  CanonicalItem? resolve(String rawName, List<CanonicalItem> catalog) {
    final normalized = normalizeItemName(rawName);
    if (normalized.isEmpty || catalog.isEmpty) return null;

    final exact = _exactAliasMatch(normalized, catalog);
    if (exact != null) return exact;

    final contained = _containedAliasMatch(normalized, catalog);
    if (contained != null) return contained;

    return _fuzzyMatch(normalized, catalog);
  }

  CanonicalItem? _exactAliasMatch(String normalized, List<CanonicalItem> catalog) {
    for (final item in catalog) {
      for (final alias in item.aliasKeywords) {
        if (alias == normalized) return item;
      }
    }
    return null;
  }

  /// "organic whole milk" contains the alias "whole milk". The longest alias
  /// wins, so that input resolves to whole milk rather than to plain milk —
  /// specificity beats recall here because the price of a gallon of whole milk
  /// and a gallon of almond milk are different products, not noise.
  CanonicalItem? _containedAliasMatch(
    String normalized,
    List<CanonicalItem> catalog,
  ) {
    final tokens = normalized.split(' ').toSet();
    CanonicalItem? best;
    var bestScore = 0;

    for (final item in catalog) {
      for (final alias in item.aliasKeywords) {
        final aliasTokens = alias.split(' ');
        if (aliasTokens.length > tokens.length) continue;
        if (!aliasTokens.every(tokens.contains)) continue;

        // Token count dominates, character length breaks ties.
        final score = aliasTokens.length * 1000 + alias.length;
        if (score > bestScore) {
          bestScore = score;
          best = item;
        }
      }
    }
    return best;
  }

  /// Typo tolerance. One edit for short words, two for long ones, and an
  /// ambiguous best score resolves to null rather than a coin flip.
  CanonicalItem? _fuzzyMatch(String normalized, List<CanonicalItem> catalog) {
    if (normalized.length < _minFuzzyLength) return null;

    CanonicalItem? candidate;
    var bestDistance = 1 << 30;
    var ambiguous = false;

    for (final item in catalog) {
      for (final alias in item.aliasKeywords) {
        if (alias.length < _minFuzzyLength) continue;
        final limit = alias.length >= 7 ? 2 : 1;
        // Cheap reject before the O(n*m) distance computation.
        if ((alias.length - normalized.length).abs() > limit) continue;

        final distance = _levenshtein(normalized, alias);
        if (distance > limit) continue;

        if (distance < bestDistance) {
          bestDistance = distance;
          candidate = item;
          ambiguous = false;
        } else if (distance == bestDistance && candidate != item) {
          ambiguous = true;
        }
      }
    }

    return ambiguous ? null : candidate;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        current[j + 1] = substitution < insertion
            ? (substitution < deletion ? substitution : deletion)
            : (insertion < deletion ? insertion : deletion);
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }
}
