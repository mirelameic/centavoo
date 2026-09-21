import 'package:flutter/material.dart';

const _iconMap = <String, IconData>{
  'plane': Icons.flight,
  'bed': Icons.bed,
  'home': Icons.home,
  'car': Icons.directions_car,
  'train': Icons.train,
  'bus': Icons.directions_bus,
  'bike': Icons.pedal_bike,
  'fuel': Icons.local_gas_station,
  'food': Icons.restaurant,
  'coffee': Icons.local_cafe,
  'wine': Icons.wine_bar,
  'shopping': Icons.shopping_bag,
  'gift': Icons.card_giftcard,
  'ticket': Icons.confirmation_number,
  'landmark': Icons.account_balance,
  'luggage': Icons.luggage,
  'backpack': Icons.backpack,
  'beach': Icons.beach_access,
  'mountain': Icons.terrain,
  'map': Icons.map,
  'phone': Icons.smartphone,
  'pill': Icons.medication,
  'leaf': Icons.eco,
  'bookmark': Icons.bookmark,
};

IconData? categoryIcon(String? name) => name == null ? null : _iconMap[name];

final iconOptions = _iconMap.keys.toList();
