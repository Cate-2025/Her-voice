/// Support-resource directory and emergency contacts (sections 3.8 and 3.9).
library;

class SupportResource {
  const SupportResource({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.contact,
    this.availability,
    this.walkIn = false,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String? contact;
  final String? availability;
  final bool walkIn;

  factory SupportResource.fromJson(Map<String, dynamic> json) {
    return SupportResource(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Support',
      category: json['category']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      contact: json['contact']?.toString(),
      availability: json['availability']?.toString(),
      walkIn: json['walkIn'] == true,
    );
  }
}

/// A quick-support destination. [type] is PHONE or SMS; the SMS entry is the
/// low-bandwidth fallback used when there is no mobile data (section 3.11).
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.label,
    required this.contact,
    required this.type,
    this.note,
  });

  final String id;
  final String label;
  final String contact;
  final String type;
  final String? note;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Support',
      contact: json['contact']?.toString() ?? '',
      type: json['type']?.toString() ?? 'PHONE',
      note: json['note']?.toString(),
    );
  }

  bool get isSms => type.toUpperCase() == 'SMS';
}

/// Response wrapper for the emergency-contact endpoint, which also carries the
/// disclaimer that HERVOICE does not replace emergency services.
class EmergencyDirectory {
  const EmergencyDirectory({required this.disclaimer, required this.contacts});

  final String disclaimer;
  final List<EmergencyContact> contacts;

  factory EmergencyDirectory.fromJson(Map<String, dynamic> json) {
    return EmergencyDirectory(
      disclaimer: json['disclaimer']?.toString() ?? '',
      contacts: ((json['contacts'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(EmergencyContact.fromJson)
          .toList(),
    );
  }
}

/// Support directory grouped by category for the browsing screen.
class SupportDirectory {
  const SupportDirectory({required this.categories, required this.resources});

  final List<String> categories;
  final List<SupportResource> resources;

  factory SupportDirectory.fromJson(Map<String, dynamic> json) {
    return SupportDirectory(
      categories: ((json['categories'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      resources: ((json['resources'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SupportResource.fromJson)
          .toList(),
    );
  }

  List<SupportResource> byCategory(String category) =>
      resources.where((SupportResource resource) => resource.category == category).toList();
}
