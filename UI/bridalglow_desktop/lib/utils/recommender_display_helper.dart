/// Formats internal recommender model version strings for UI display.
///
/// Examples:
/// - `ibcf-v1` → `IBCF v1`
/// - `ibcf-v1-20260702-143022` → `IBCF v1 (02.07.2026)`
String formatRecommenderModelVersionForDisplay(String modelVersion) {
  if (modelVersion.isEmpty) return modelVersion;

  final timestampPattern = RegExp(r'-(\d{8})-(\d{6})$');
  final match = timestampPattern.firstMatch(modelVersion);

  var base = modelVersion;
  DateTime? runDate;
  if (match != null) {
    base = modelVersion.substring(0, match.start);
    final dateStr = match.group(1)!;
    runDate = DateTime.tryParse(
      '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}',
    );
  }

  final readable = _formatBaseModelName(base);
  if (runDate != null) {
    final day = runDate.day.toString().padLeft(2, '0');
    final month = runDate.month.toString().padLeft(2, '0');
    return '$readable ($day.$month.${runDate.year})';
  }
  return readable;
}

String _formatBaseModelName(String base) {
  final parts = base.split('-');
  if (parts.length >= 2) {
    final algo = parts.first.toUpperCase();
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].startsWith('v')) {
        return '$algo ${parts[i]}';
      }
    }
    return '$algo ${parts.sublist(1).join(' ')}';
  }
  return base.toUpperCase();
}
