/// Model modulu z tabulky [modules] – katalog dostupných funkcí (finance, warehouse, staff, …).
///
/// [key] je identifikátor pro RLS a tenant_modules (např. 'dashboard', 'staff', 'finance').
/// [name] je zobrazený název z DB; v UI lze přepsat lokalizovaným klíčem z [ModuleIconMapper].
/// [orderIndex] určuje pořadí v menu (1 = první, 99 = na konec). Řazení v provideru.
/// [price] je cena v EUR (měsíční) – odpovídá sloupci price_eur v DB. Null = nezadáno.
/// [pricingType] = 'fixed' (paušál), 'per_apartment' (cena × počet bytů), 'per_user' (cena × počet uživatelů).
/// [description] je volitelný popis pro katalog (Super Admin).
/// [showInMenu] = false skrývá modul ze sidebaru (např. automatic_tasks jako podfunkce Úkolů).
/// [parentModuleKey] = klíč nadřazeného modulu (např. 'tasks' pro automatic_tasks).
class ModuleModel {
  const ModuleModel({
    required this.id,
    required this.key,
    required this.name,
    this.sortOrder = 0,
    this.orderIndex = 99,
    this.price,
    this.pricingType = 'fixed',
    this.description,
    this.showInMenu = true,
    this.parentModuleKey,
  });

  final String id;
  final String key;
  final String name;
  final int sortOrder;
  /// Logické pořadí v menu (1 = Dashboard první, 9 = Automation, 99 = ostatní na konec).
  final int orderIndex;
  /// Cena modulu (např. měsíční předplatné). Null = nezadáno / v UI zobrazit common.placeholder_dash.
  final num? price;
  /// 'fixed' | 'per_apartment' | 'per_user' – jak se cena násobí (počet bytů / uživatelů).
  final String pricingType;
  /// Volitelný popis modulu (katalog).
  final String? description;
  /// Zobrazit položku v sidebar menu. Null z DB se interpretuje jako true (zpětná kompatibilita).
  final bool showInMenu;
  /// Klíč nadřazeného modulu (např. 'tasks' pro automatic_tasks).
  final String? parentModuleKey;

  factory ModuleModel.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['sort_order'];
    int order = 0;
    if (rawOrder != null) {
      if (rawOrder is int) {
        order = rawOrder;
      } else if (rawOrder is num) {
        order = rawOrder.toInt();
      }
    }
    final rawOrderIndex = json['order_index'];
    int orderIdx = 99;
    if (rawOrderIndex != null) {
      if (rawOrderIndex is int) {
        orderIdx = rawOrderIndex;
      } else if (rawOrderIndex is num) {
        orderIdx = rawOrderIndex.toInt();
      }
    }
    num? price;
    final rawPrice = json['price_eur'] ?? json['price'] ?? json['monthly_price'];
    if (rawPrice != null) {
      if (rawPrice is num) {
        price = rawPrice;
      } else if (rawPrice is String) {
        price = num.tryParse(rawPrice);
      }
    }
    final rawType = json['pricing_type'] as String?;
    final pricingType = (rawType == null || rawType.isEmpty)
        ? 'fixed'
        : (rawType == 'per_apartment' || rawType == 'per_user' ? rawType : 'fixed');

    final description = (json['description'] as String?)?.trim();
    final rawShowInMenu = json['show_in_menu'];
    final showInMenu = rawShowInMenu == null ? true : (rawShowInMenu == true || rawShowInMenu == 1);
    final parentModuleKey = (json['parent_module_key'] as String?)?.trim();
    return ModuleModel(
      id: json['id'] as String? ?? '',
      key: (json['key'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      sortOrder: order,
      orderIndex: orderIdx,
      price: price,
      pricingType: pricingType,
      description: description?.isEmpty == true ? null : description,
      showInMenu: showInMenu,
      parentModuleKey: parentModuleKey?.isEmpty == true ? null : parentModuleKey,
    );
  }

  /// Mapování pro INSERT/UPDATE v Supabase. Cena VŽDY jde do sloupce price_eur (DB neobsahuje 'price').
  /// Explicitně posíláme price_eur vždy, aby nedocházelo k „tichému“ neuložení (DB očekává price_eur).
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      'price_eur': price ?? 0,
      'pricing_type': pricingType,
      'order_index': orderIndex,
      'show_in_menu': showInMenu,
      'parent_module_key': parentModuleKey,
    };
  }
}
