import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Categories are entirely user-created (no fixed set), so a category's
/// look has to be *derived* rather than picked.
///
/// Color comes from the id; the icon is guessed from the name. Guessing
/// beats the old first-letter avatar — "B" told you nothing, a bowl of
/// food tells you it's biriyani at a glance — and when the guess misses
/// it falls back to a neutral tag rather than anything wrong.
class CategoryColors {
  CategoryColors._();

  /// Muted jewel tones, all held to a similar lightness and chroma band.
  /// The old palette mixed #16A34A with #CA8A04 and #DB2777, which is why
  /// five categories in one donut looked like spilled paint — harmonised,
  /// they read as a designed set.
  /// Warm oranges are deliberately absent: AppColors.warning owns that
  /// hue for the "Unlabelled" bucket, and a category sharing it produced
  /// two indistinguishable slices in the same donut.
  static const List<Color> _palette = [
    Color(0xFF3E6BB5), // dusty blue
    Color(0xFF2F8F6B), // jade
    Color(0xFF7B5EA7), // amethyst
    Color(0xFFC4564B), // terracotta
    Color(0xFF2B8A96), // teal
    Color(0xFFB5537F), // rose
    Color(0xFF5E8C3A), // moss
    Color(0xFF8A7B3E), // olive
    Color(0xFF5361B8), // indigo
    Color(0xFF9C5BA0), // orchid
  ];

  static Color forId(int id) => _palette[id % _palette.length];
}

/// Maps a free-text category name onto an icon by keyword.
///
/// Ordering matters: the first matching keyword wins, so put specific
/// terms ahead of generic ones that would swallow them (e.g. "recharge"
/// before "mobile", since "mobile recharge" should read as a bill, not a
/// handset purchase).
class CategoryIcons {
  CategoryIcons._();

  static const _rules = <List<String>, IconData>{
    ['coffee', 'tea', 'chai', 'cafe', 'starbuck']: PhosphorIconsRegular.coffee,
    [
      'food', 'eat', 'restaurant', 'hotel', 'lunch', 'dinner', 'breakfast',
      'meal', 'zomato', 'swiggy', 'biriyani', 'biryani', 'shawai', 'shawarma',
      'snack', 'juice', 'bakery'
    ]: PhosphorIconsRegular.forkKnife,
    ['grocer', 'super', 'market', 'vegetable', 'mart', 'bigbasket', 'provision']:
        PhosphorIconsRegular.shoppingCart,
    ['fuel', 'petrol', 'diesel', 'pump']: PhosphorIconsRegular.gasPump,
    ['train', 'irctc', 'rail', 'metro']: PhosphorIconsRegular.train,
    ['flight', 'air', 'indigo air']: PhosphorIconsRegular.airplaneTilt,
    ['bus', 'ksrtc']: PhosphorIconsRegular.bus,
    ['travel', 'uber', 'ola', 'cab', 'taxi', 'auto', 'ride', 'transport']:
        PhosphorIconsRegular.car,
    ['rent', 'house', 'home', 'maintenance']: PhosphorIconsRegular.house,
    ['recharge', 'mobile', 'airtel', 'jio', 'vodafone', 'data pack', 'topup']:
        PhosphorIconsRegular.deviceMobile,
    ['internet', 'wifi', 'broadband', 'fiber']: PhosphorIconsRegular.wifiHigh,
    ['electric', 'power', 'current', 'kseb']: PhosphorIconsRegular.lightning,
    ['water']: PhosphorIconsRegular.drop,
    ['cigar', 'cigerat', 'cigaret', 'smoke', 'tobacco']: PhosphorIconsRegular.cigarette,
    ['shop', 'amazon', 'flipkart', 'myntra', 'cloth', 'dress', 'apparel']:
        PhosphorIconsRegular.shoppingBag,
    ['laundry', 'iron']: PhosphorIconsRegular.tShirt,
    ['health', 'medic', 'pharma', 'hospital', 'doctor', 'clinic']:
        PhosphorIconsRegular.firstAidKit,
    ['gym', 'fitness', 'sport', 'workout']: PhosphorIconsRegular.barbell,
    ['salon', 'beauty', 'hair', 'grooming']: PhosphorIconsRegular.scissors,
    ['movie', 'cinema', 'entertain', 'netflix', 'spotify', 'music', 'district', 'game']:
        PhosphorIconsRegular.filmSlate,
    ['edu', 'course', 'book', 'school', 'college', 'fee', 'tuition']:
        PhosphorIconsRegular.graduationCap,
    ['invest', 'mutual', 'stock', 'sip', 'gold', 'saving']: PhosphorIconsRegular.trendUp,
    ['insurance', 'premium', 'policy']: PhosphorIconsRegular.shieldCheck,
    ['gift', 'donat', 'charity', 'temple']: PhosphorIconsRegular.gift,
    ['salary', 'income', 'credit']: PhosphorIconsRegular.wallet,
    ['pet', 'dog', 'cat']: PhosphorIconsRegular.pawPrint,
    ['friend', 'family', 'person', 'transfer', 'send', 'lend']:
        PhosphorIconsRegular.userCircle,
  };

  static IconData forName(String name) {
    final lower = name.toLowerCase();
    for (final entry in _rules.entries) {
      for (final keyword in entry.key) {
        if (lower.contains(keyword)) return entry.value;
      }
    }
    return PhosphorIconsRegular.tag;
  }
}
