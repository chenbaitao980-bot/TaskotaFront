class QuotaExceededException implements Exception {
  final String message;
  final QuotaType type;

  const QuotaExceededException(this.message, this.type);

  @override
  String toString() => message;
}

enum QuotaType {
  project,
  task,
  aiDecompose,
  dataExport,
}
