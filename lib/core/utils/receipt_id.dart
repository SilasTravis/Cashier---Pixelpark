String formatReceiptId(String id) {
  final normalized = id.trim();
  return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
}
