import 'package:jamiat/src/data/utils/format_helpers.dart';

class ProductSeller {
  const ProductSeller({
    required this.name,
    this.id,
    this.email,
    this.phone,
    this.image,
  });

  final String? id;
  final String name;
  final String? email;
  final String? phone;
  final String? image;

  factory ProductSeller.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image']?.toString().trim();
    return ProductSeller(
      id: (json['_id'] ?? json['id'])?.toString(),
      name: (json['name'] ?? '').toString().trim(),
      email: json['email']?.toString().trim(),
      phone: json['phone']?.toString().trim(),
      image: (rawImage == null || rawImage.isEmpty || rawImage == 'null')
          ? null
          : rawImage,
    );
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.isSaved,
    this.image,
    this.status,
    this.seller,
  });

  final String id;
  final String name;
  final String description;
  final num amount;
  final bool isSaved;
  final String? image;
  final String? status;
  final ProductSeller? seller;

  String get formattedPrice => formatRupee(amount);

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    ProductSeller? seller;
    final createdBy = json['created_by'];
    if (createdBy is Map<String, dynamic>) {
      seller = ProductSeller.fromJson(createdBy);
    } else if (createdBy is Map) {
      seller = ProductSeller.fromJson(Map<String, dynamic>.from(createdBy));
    }

    final rawImage = json['image']?.toString().trim();

    return ProductModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      amount: json['amount'] is num
          ? json['amount'] as num
          : num.tryParse('${json['amount']}') ?? 0,
      isSaved: json['is_saved'] == true,
      image: (rawImage == null || rawImage.isEmpty || rawImage == 'null')
          ? null
          : rawImage,
      status: json['status']?.toString(),
      seller: seller,
    );
  }

  ProductModel copyWith({bool? isSaved}) {
    return ProductModel(
      id: id,
      name: name,
      description: description,
      amount: amount,
      isSaved: isSaved ?? this.isSaved,
      image: image,
      status: status,
      seller: seller,
    );
  }
}

class ProductEnquiryModel {
  const ProductEnquiryModel({
    required this.id,
    required this.product,
    this.createdAt,
  });

  final String id;
  final ProductModel product;
  final DateTime? createdAt;

  factory ProductEnquiryModel.fromJson(Map<String, dynamic> json) {
    final productRaw = json['product'];
    final productMap = productRaw is Map<String, dynamic>
        ? productRaw
        : productRaw is Map
            ? Map<String, dynamic>.from(productRaw)
            : <String, dynamic>{};

    return ProductEnquiryModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      product: ProductModel.fromJson(productMap),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }
}
