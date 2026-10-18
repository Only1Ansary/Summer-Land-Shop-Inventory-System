import 'package:flutter/material.dart';

/// A module shortcut shown on the Home screen and pinnable by the user.
class HomeModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final String destinationId;

  const HomeModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destinationId,
  });
}

/// Every module that can be pinned on Home.
///
/// The length of this list is the hard ceiling for the user's pin limit.
const List<HomeModule> homeModules = [
  HomeModule(
    title: 'Products',
    subtitle: 'Catalog & variants',
    icon: Icons.inventory_2_rounded,
    destinationId: 'products',
  ),
  HomeModule(
    title: 'Inventory',
    subtitle: 'Stock by location',
    icon: Icons.warehouse_rounded,
    destinationId: 'inventory',
  ),
  HomeModule(
    title: 'New Sale',
    subtitle: 'Create an invoice',
    icon: Icons.point_of_sale_rounded,
    destinationId: 'sales',
  ),
  HomeModule(
    title: 'Sale Invoices',
    subtitle: 'View & search invoices',
    icon: Icons.receipt_long_rounded,
    destinationId: 'sale-invoices',
  ),
  HomeModule(
    title: 'Stock Transfers',
    subtitle: 'Move stock around',
    icon: Icons.swap_horiz_rounded,
    destinationId: 'transfers',
  ),
  HomeModule(
    title: 'Returns',
    subtitle: 'Process returns',
    icon: Icons.assignment_return_rounded,
    destinationId: 'returns',
  ),
  HomeModule(
    title: 'Purchases',
    subtitle: 'View & search invoices',
    icon: Icons.shopping_bag_rounded,
    destinationId: 'purchase-invoices',
  ),
  HomeModule(
    title: 'New Purchase',
    subtitle: 'Record a purchase',
    icon: Icons.shopping_cart_checkout_rounded,
    destinationId: 'add-purchase',
  ),
  HomeModule(
    title: 'Suppliers',
    subtitle: 'Manage suppliers',
    icon: Icons.factory_rounded,
    destinationId: 'suppliers',
  ),
  HomeModule(
    title: 'Settings',
    subtitle: 'Preferences & about',
    icon: Icons.settings_rounded,
    destinationId: 'settings',
  ),
  HomeModule(
    title: 'Reports',
    subtitle: 'Sales & stock insights',
    icon: Icons.assessment_rounded,
    destinationId: 'reports',
  ),
  HomeModule(
    title: 'Categories',
    subtitle: 'Organise products',
    icon: Icons.category_rounded,
    destinationId: 'categories',
  ),
  HomeModule(
    title: 'Colours',
    subtitle: 'Colour options',
    icon: Icons.palette_rounded,
    destinationId: 'colours',
  ),
  HomeModule(
    title: 'Sizes',
    subtitle: 'Size options',
    icon: Icons.straighten_rounded,
    destinationId: 'sizes',
  ),
  HomeModule(
    title: 'Locations',
    subtitle: 'Store locations',
    icon: Icons.location_on_rounded,
    destinationId: 'locations',
  ),
  HomeModule(
    title: 'Employees',
    subtitle: 'Staff & payroll',
    icon: Icons.badge_rounded,
    destinationId: 'employees',
  ),
];
