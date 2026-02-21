/// Vrací lokalizační klíč pro typ ceny modulu (fixed, per_apartment, per_user).
/// Použití: getPricingTypeLabelKey(module.pricingType).tr()
String getPricingTypeLabelKey(String type) {
  switch (type) {
    case 'per_apartment':
      return 'settings.pricing_per_apartment';
    case 'per_user':
      return 'settings.pricing_per_user';
    case 'fixed':
    default:
      return 'settings.pricing_fixed';
  }
}
