import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/invoice.dart';
import '../models/purchase_invoice.dart';
import '../services/shop_profile_service.dart';
import '../ui/app_widgets.dart';

/// Result of a print attempt that did not fail.
enum PrintOutcome { printed, cancelled }

/// Thrown when building or sending the receipt failed (as opposed to the
/// user cancelling the dialog).
class InvoicePrintException implements Exception {
  InvoicePrintException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'InvoicePrintException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Fixed texts of the receipt. Replace these with fields from the shop
/// profile once it exposes them.
class ReceiptBranding {
  ReceiptBranding._();

  static const String fallbackName = 'SUMMAR LAND';
  static const String address = 'بلقاس ش/السوق العمومي';
  static const String phones = '01221546669 - 0502784129';

  /// Optional. If the asset is missing the logo is simply left out.
  static const String logoAsset = 'assets/Summer Land Logo.png';

  static const List<String> saleFooter = [
    'المرتجع في نفس اليوم و التبديل خلال يومين',
    'لا يوجد تبديل او استرجاع داخلي او لانجيري',
  ];
}

/// Renders sale and purchase invoices as an Arabic-only 80mm thermal receipt.
///
/// * Pass a [Printer] to print silently (`Printing.directPrintPdf`). Let the
///   user pick it once in settings and persist it.
/// * Without a printer the system print dialog is shown instead.
///
/// Layout note: the page is deliberately NOT wrapped in an RTL
/// `Directionality`. Rows and tables are built in physical left-to-right
/// order (already reversed for Arabic), and only the text itself is RTL.
/// That makes the result independent of how a given `pdf` version treats
/// directionality in Row/Table.
class InvoicePrinter {
  InvoicePrinter._();

  static const PdfPageFormat _format = PdfPageFormat.roll80;
  static const double _epsilon = 0.005;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Payment and customer details are read from [invoice] when available, so
  /// older invoices (created before customers were tracked) still print as
  /// fully paid with no customer line.
  static Future<PrintOutcome> printSaleInvoice(
      Invoice invoice, {
        String? customerName,
        double? paidAmount,
        double? previousBalance,
        Printer? printer,
      }) async {
    final gross = invoice.items
        .fold<double>(0, (s, i) => s + i.totalBeforeDiscount);
    final itemDiscounts = invoice.items
        .fold<double>(0, (s, i) => s + (i.totalBeforeDiscount - i.totalPrice));
    final discount = itemDiscounts + invoice.discountAmount;
    final net = invoice.totalAmount;
    final paid = paidAmount ?? (invoice.paidAmount > 0 ? invoice.paidAmount : net);
    final remaining = net - paid;
    final autoPrevious = (invoice.customerTotalDebt - remaining)
        .clamp(0, double.infinity)
        .toDouble();
    final previous = previousBalance ?? autoPrevious;
    final account = previous + remaining;
    final pieces = invoice.items.fold<int>(0, (s, i) => s + i.quantity);
    final partyName = (customerName?.trim().isNotEmpty ?? false)
        ? customerName!.trim()
        : (invoice.customerDisplayName ?? 'عميل عام');

    final paymentLabels = <String>[];
    for (final payment in invoice.payments) {
      final label = _paymentMethodArabic(payment.method);
      if (!paymentLabels.contains(label)) paymentLabels.add(label);
    }
    if (paymentLabels.isEmpty && invoice.paymentMethod != null) {
      paymentLabels.add(_paymentMethodArabic(invoice.paymentMethod!));
    }

    final lines = [
      for (final item in invoice.items)
        _Line(
          code: '${item.modelNumber}',
          name: _withVariant(item.productName, item.sizeName, item.colourName),
          quantity: '${item.quantity}',
          price: _amount(item.unitPrice),
          total: _amount(item.totalBeforeDiscount),
        ),
    ];

    final doc = await _buildDocument(
      title: 'فاتورة بيع',
      partyLabel: 'الاسم',
      partyName: partyName,
      staffName: invoice.employeeName,
      date: invoice.createdAt,
      number: '${invoice.id}',
      lines: lines,
      summary: [
        [
          _fixed(gross),
          'قيمة الفاتورة',
          'ع القطع $pieces',
          'ع أصناف ${invoice.items.length}',
        ],
        [_fixed(net), 'صافي الفاتورة', _fixed(0), 'مبلغ مضاف'],
        [_fixed(paid), 'المبلغ المدفوع', _fixed(discount), 'خصم'],
        [
          _amount(remaining),
          'المبلغ المتبقي',
          _amount(previous),
          'السابق عليه :',
        ],
      ],
      accountLine: 'إجمالي الحساب عليه : ${_amount(account)}',
      footer: [
        if (invoice.customerPhone != null &&
            invoice.customerPhone!.trim().isNotEmpty)
          'رقم العميل: ${invoice.customerPhone}',
        if (paymentLabels.isNotEmpty)
          'طريقة الدفع: ${paymentLabels.join(' / ')}',
        ...ReceiptBranding.saleFooter,
        if (discount > _epsilon)
          'العروض والخصومات وفرت لك ${_fixed(discount)} جنيه',
      ],
    );
    return _send(doc, name: 'Sale Invoice ${invoice.id}', printer: printer);
  }

  static Future<PrintOutcome> printPurchaseInvoice(
      PurchaseInvoice invoice, {
        Printer? printer,
      }) async {
    final itemsSum =
    invoice.items.fold<double>(0, (s, i) => s + i.totalPrice);
    final fees = invoice.fees.fold<double>(0, (s, f) => s + f.amount);
    // totalCost = goods after discount + fees.
    final discount = (itemsSum - (invoice.totalCost - fees))
        .clamp(0, double.infinity)
        .toDouble();
    final pieces = invoice.items.fold<int>(0, (s, i) => s + i.quantity);
    final previous = invoice.supplierTotalDebt - invoice.debt;

    final lines = [
      for (final item in invoice.items)
        _Line(
          code: '${item.productId}',
          name: (item.productName ?? '').trim().isNotEmpty
              ? item.productName!
              : 'صنف ${item.productId}',
          quantity: '${item.quantity}',
          price: _amount(item.unitPurchasePrice),
          total: _amount(item.totalPrice),
        ),
    ];

    final doc = await _buildDocument(
      title: 'فاتورة شراء',
      partyLabel: 'المورد',
      partyName: invoice.supplierName,
      date: invoice.date ?? invoice.createdAt,
      number: '${invoice.id}',
      lines: lines,
      summary: [
        [
          _fixed(itemsSum),
          'قيمة الفاتورة',
          'ع القطع $pieces',
          'ع أصناف ${invoice.items.length}',
        ],
        [_fixed(invoice.totalCost), 'صافي الفاتورة', _fixed(fees), 'مبلغ مضاف'],
        [
          _fixed(invoice.totalPaid),
          'المبلغ المدفوع',
          _fixed(discount),
          'خصم',
        ],
        [
          _amount(invoice.debt),
          'المبلغ المتبقي',
          _amount(previous),
          'السابق للمورد :',
        ],
      ],
      accountLine:
      'إجمالي المستحق للمورد : ${_amount(invoice.supplierTotalDebt)}',
      footer: const [],
    );
    return _send(doc, name: 'Purchase Invoice ${invoice.id}', printer: printer);
  }

  // ---------------------------------------------------------------------------
  // Shared document skeleton
  // ---------------------------------------------------------------------------

  static Future<pw.Document> _buildDocument({
    required String title,
    required String partyLabel,
    required String partyName,
    String? staffName,
    required DateTime date,
    required String number,
    required List<_Line> lines,
    required List<List<String>> summary,
    required String accountLine,
    required List<String> footer,
  }) async {
    final theme = await _loadTheme();
    final logo = await _loadLogo();

    final profileName = ShopProfileService.instance.profile.value.name.trim();
    final shopName =
    profileName.isNotEmpty ? profileName : ReceiptBranding.fallbackName;

    final doc = pw.Document(theme: theme, title: title);
    doc.addPage(
      pw.Page(
        pageFormat: _format,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Shop block: logo on the left, name/address/phones on the right.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.SizedBox(
                    width: 20 * PdfPageFormat.mm,
                    height: 20 * PdfPageFormat.mm,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        shopName,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      _arabic(
                        ReceiptBranding.address,
                        size: 10,
                        align: pw.TextAlign.right,
                      ),
                      pw.Text(
                        ReceiptBranding.phones,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.5, height: 4),
            // Party name on the right, cashier/employee on the left.
            if ((staffName ?? '').trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 6),
                child: _arabic(
                  staffName!.trim(),
                  size: 10,
                  align: pw.TextAlign.left,
                ),
              ),
            _arabic(title, size: 10, bold: true, align: pw.TextAlign.right),
            pw.SizedBox(height: 2),
            // Barcode with the invoice number on the left, date on the right.
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: number,
                  width: 36 * PdfPageFormat.mm,
                  height: 12 * PdfPageFormat.mm,
                  textStyle: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  formatDisplayDateTime(date),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            _itemsTable(lines),
            pw.SizedBox(height: 4),
            _summaryTable(summary),
            pw.SizedBox(height: 4),
            _arabic(
              accountLine,
              size: 12,
              bold: true,
              align: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 4),
            for (final line in footer)
              _arabic(line, size: 9, align: pw.TextAlign.center),
          ],
        ),
      ),
    );
    return doc;
  }

  /// Columns in physical order, left to right:
  /// total | price | quantity | name | code.
  static pw.Widget _itemsTable(List<_Line> lines) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: pw.FlexColumnWidth(17),
        1: pw.FlexColumnWidth(16),
        2: pw.FlexColumnWidth(11),
        3: pw.FlexColumnWidth(40),
        4: pw.FlexColumnWidth(16),
      },
      children: [
        pw.TableRow(
          children: [
            _cell('الاجمالي', bold: true),
            _cell('السعر', bold: true),
            _cell('الكمية', bold: true),
            _cell('الاسم', bold: true),
            _cell('كود', bold: true),
          ],
        ),
        for (final line in lines)
          pw.TableRow(
            children: [
              _cell(line.total),
              _cell(line.price),
              _cell(line.quantity),
              _cell(line.name, align: pw.TextAlign.right),
              _cell(line.code),
            ],
          ),
      ],
    );
  }

  /// Four cells per row, in physical order (left to right).
  static pw.Widget _summaryTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: pw.FlexColumnWidth(26),
        1: pw.FlexColumnWidth(28),
        2: pw.FlexColumnWidth(20),
        3: pw.FlexColumnWidth(26),
      },
      children: [
        for (final row in rows)
          pw.TableRow(children: [for (final text in row) _cell(text)]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Text helpers
  // ---------------------------------------------------------------------------

  static pw.TextStyle _style(double size, bool bold) => pw.TextStyle(
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  /// Arabic (right-to-left) text. Digits and Latin runs inside it are still
  /// laid out correctly by the bidi algorithm.
  static pw.Widget _arabic(
      String text, {
        double size = 12,
        bool bold = false,
        pw.TextAlign align = pw.TextAlign.right,
      }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Text(text, textAlign: align, style: _style(size, bold)),
    );
  }

  static pw.Widget _cell(
      String text, {
        bool bold = false,
        double size = 6,
        pw.TextAlign align = pw.TextAlign.center,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: _arabic(text, size: size, bold: bold, align: align),
    );
  }

  /// Whole numbers print without decimals ("1079"), others with two
  /// ("749.50"), like the sample receipt's item table.
  static String _amount(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.truncateToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(2);
  }

  /// Always two decimals ("7630.00"), like the sample's summary box.
  static String _fixed(double value) {
    final rounded = (value * 100).round() / 100;
    return (rounded == 0 ? 0.0 : rounded).toStringAsFixed(2);
  }

  static String _paymentMethodArabic(int method) {
    switch (method) {
      case 1:
        return 'فيزا';
      case 2:
        return 'إنستاباي';
      case 3:
        return 'فودافون كاش';
      case 0:
      default:
        return 'كاش';
    }
  }

  static String _withVariant(String name, String? size, String? colour) {
    final variant = [size, colour]
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .join(' / ');
    return variant.isEmpty ? name : '$name ($variant)';
  }

  // ---------------------------------------------------------------------------
  // Fonts, logo, printing
  // ---------------------------------------------------------------------------

  static Future<pw.ThemeData>? _themeFuture;

  /// Loads the fonts once (concurrent callers share one future). A failed
  /// load is not cached and surfaces as an exception.
  static Future<pw.ThemeData> _loadTheme() {
    return _themeFuture ??= () async {
      try {
        final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/tahoma.ttf'));
        final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/tahomabd.ttf'));
        return pw.ThemeData.withFont(base: regular, bold: bold);
      } catch (e) {
        _themeFuture = null;
        throw InvoicePrintException('Could not load receipt fonts', e);
      }
    }();
  }

  static bool _logoTried = false;
  static pw.MemoryImage? _logo;

  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_logoTried) return _logo;
    _logoTried = true;
    try {
      final data = await rootBundle.load(ReceiptBranding.logoAsset);
      _logo = pw.MemoryImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      _logo = null; // No logo asset: print without it.
    }
    return _logo;
  }

  static Future<PrintOutcome> _send(
      pw.Document doc, {
        required String name,
        Printer? printer,
      }) async {
    try {
      final bytes = await doc.save();
      final printed = printer != null
          ? await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) async => bytes,
        name: name,
        format: _format,
      )
          : await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: name,
        format: _format,
      );
      return printed ? PrintOutcome.printed : PrintOutcome.cancelled;
    } on InvoicePrintException {
      rethrow;
    } catch (e) {
      throw InvoicePrintException('Printing failed', e);
    }
  }
}

class _Line {
  const _Line({
    required this.code,
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  final String code;
  final String name;
  final String quantity;
  final String price;
  final String total;
}