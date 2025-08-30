class PhotoItem {
  final String imagePath;
  final String? barcode;
  int barcodeCount;
  
  PhotoItem({
    required this.imagePath,
    this.barcode,
    this.barcodeCount = 1,
  });
  
  // Конвертация в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'barcode': barcode,
      'barcodeCount': barcodeCount,
    };
  }
  
  // Создание из JSON
  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      imagePath: json['imagePath'] as String,
      barcode: json['barcode'] as String?,
      barcodeCount: json['barcodeCount'] as int? ?? 1,
    );
  }
  
  // Копирование с изменениями
  PhotoItem copyWith({
    String? imagePath,
    String? barcode,
    int? barcodeCount,
    bool clearBarcode = false,
  }) {
    return PhotoItem(
      imagePath: imagePath ?? this.imagePath,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      barcodeCount: barcodeCount ?? this.barcodeCount,
    );
  }
}