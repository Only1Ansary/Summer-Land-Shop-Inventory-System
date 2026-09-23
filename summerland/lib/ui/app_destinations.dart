import 'package:flutter/material.dart';

import '../screens/categories/categories_screen.dart';
import '../screens/colours/colours_screen.dart';
import '../screens/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/invoices/create_invoice_screen.dart';
import '../screens/locations/locations_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/reports/best_selling_report_screen.dart';
import '../screens/reports/inventory_report_screen.dart';
import '../screens/reports/low_stock_report_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/sales_report_screen.dart';
import '../screens/reports/stock_movements_report_screen.dart';
import '../screens/returns/returns_screen.dart';
import '../screens/sizes/sizes_screen.dart';
import '../screens/stock/stock_transfer_screen.dart';

/// A single entry in the persistent app navigation.
class AppNavigationItem {
  final String id;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final String group;
  final Widget Function() builder;

  const AppNavigationItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.group,
    required this.builder,
  });
}

/// Central registry of every top-level destination in the app.
///
/// The [_items] list drives the desktop navigation rail and the mobile
/// drawer; the bottom navigation shows a curated subset for phones.
class AppDestinations {
  AppDestinations._();

  static final List<AppNavigationItem> items = [
    // Overview
    const AppNavigationItem(
      id: 'home',
      title: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      group: 'Overview',
      builder: _home,
    ),

    // Catalog
    const AppNavigationItem(
      id: 'products',
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      group: 'Catalog',
      builder: _products,
    ),
    const AppNavigationItem(
      id: 'categories',
      title: 'Categories',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      group: 'Catalog',
      builder: _categories,
    ),
    const AppNavigationItem(
      id: 'colours',
      title: 'Colours',
      icon: Icons.palette_outlined,
      selectedIcon: Icons.palette_rounded,
      group: 'Catalog',
      builder: _colours,
    ),
    const AppNavigationItem(
      id: 'sizes',
      title: 'Sizes',
      icon: Icons.straighten_outlined,
      selectedIcon: Icons.straighten_rounded,
      group: 'Catalog',
      builder: _sizes,
    ),

    // Stock
    const AppNavigationItem(
      id: 'inventory',
      title: 'Inventory',
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse_rounded,
      group: 'Stock',
      builder: _inventory,
    ),
    const AppNavigationItem(
      id: 'transfers',
      title: 'Stock Transfers',
      icon: Icons.swap_horiz_outlined,
      selectedIcon: Icons.swap_horiz_rounded,
      group: 'Stock',
      builder: _transfers,
    ),

    // Sales
    const AppNavigationItem(
      id: 'sales',
      title: 'Sales',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale_rounded,
      group: 'Sales',
      builder: _sales,
    ),
    const AppNavigationItem(
      id: 'returns',
      title: 'Returns',
      icon: Icons.assignment_return_outlined,
      selectedIcon: Icons.assignment_return_rounded,
      group: 'Sales',
      builder: _returns,
    ),

    // Reports
    const AppNavigationItem(
      id: 'reports',
      title: 'All Reports',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      group: 'Reports',
      builder: _reports,
    ),
    const AppNavigationItem(
      id: 'report-sales',
      title: 'Sales Report',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale_rounded,
      group: 'Reports',
      builder: _salesReport,
    ),
    const AppNavigationItem(
      id: 'report-inventory',
      title: 'Inventory Report',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      group: 'Reports',
      builder: _inventoryReport,
    ),
    const AppNavigationItem(
      id: 'report-low-stock',
      title: 'Low Stock',
      icon: Icons.warning_amber_outlined,
      selectedIcon: Icons.warning_amber_rounded,
      group: 'Reports',
      builder: _lowStockReport,
    ),
    const AppNavigationItem(
      id: 'report-movements',
      title: 'Stock Movements',
      icon: Icons.swap_vert_outlined,
      selectedIcon: Icons.swap_vert_rounded,
      group: 'Reports',
      builder: _movementsReport,
    ),
    const AppNavigationItem(
      id: 'report-best-selling',
      title: 'Best Selling',
      icon: Icons.trending_up_outlined,
      selectedIcon: Icons.trending_up_rounded,
      group: 'Reports',
      builder: _bestSellingReport,
    ),

    // Locations
    const AppNavigationItem(
      id: 'locations',
      title: 'Locations',
      icon: Icons.location_on_outlined,
      selectedIcon: Icons.location_on_rounded,
      group: 'Locations',
      builder: _locations,
    ),
  ];

  /// Destinations surfaced in the mobile bottom navigation bar.
  static const List<String> bottomNavIds = [
    'home',
    'products',
    'inventory',
    'sales',
    'reports',
  ];

  /// Ids that should highlight the "Reports" item in the bottom nav.
  static const Set<String> reportIds = {
    'reports',
    'report-sales',
    'report-inventory',
    'report-low-stock',
    'report-movements',
    'report-best-selling',
  };

  static AppNavigationItem byId(String id) {
    return items.firstWhere(
      (item) => item.id == id,
      orElse: () => items.first,
    );
  }

  /// Replaces the current top-level route with the destination screen.
  static void open(BuildContext context, String id) {
    if (id.isEmpty) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => byId(id).builder(),
      ),
    );
  }

  static Widget _home() => const HomeScreen();
  static Widget _products() => const ProductsScreen();
  static Widget _categories() => const CategoriesScreen();
  static Widget _colours() => const ColoursScreen();
  static Widget _sizes() => const SizesScreen();
  static Widget _inventory() => const InventoryScreen();
  static Widget _transfers() => const StockTransfersScreen();
  static Widget _sales() => const CreateInvoiceScreen();
  static Widget _returns() => const ReturnsScreen();
  static Widget _reports() => const ReportsScreen();
  static Widget _salesReport() => const SalesReportScreen();
  static Widget _inventoryReport() => const InventoryReportScreen();
  static Widget _lowStockReport() => const LowStockReportScreen();
  static Widget _movementsReport() => const StockMovementsReportScreen();
  static Widget _bestSellingReport() => const BestSellingReportScreen();
  static Widget _locations() => const LocationsScreen();
}