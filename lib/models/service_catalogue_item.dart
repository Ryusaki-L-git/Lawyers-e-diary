class ServiceCatalogueItem {
  const ServiceCatalogueItem({
    required this.serviceId,
    required this.displayName,
    required this.description,
    required this.tokenPrice,
    required this.billingUnit,
    required this.available,
  });

  final String serviceId;
  final String displayName;
  final String description;
  final double tokenPrice;
  final String billingUnit;
  final bool available;

  factory ServiceCatalogueItem.fromJson(Map<String, dynamic> json) {
    return ServiceCatalogueItem(
      serviceId: json['serviceId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tokenPrice: (json['tokenPrice'] as num?)?.toDouble() ?? 0,
      billingUnit: json['billingUnit'] as String? ?? '',
      available: json['available'] as bool? ?? false,
    );
  }
}
