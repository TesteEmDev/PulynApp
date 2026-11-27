/// "2026-10-05" ou "2026-10-05T00:00:00Z" -> "05/10/2026". Texto que não é uma data vira vazio.
String dataCurta(String? iso) {
  final data = DateTime.tryParse(iso ?? '');
  if (data == null) return '';
  return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
}
