import '../models/customer.dart';
import '../models/customer_details.dart';
import 'api_service.dart';

class CustomerService {
  final ApiService _apiService;

  CustomerService(this._apiService);

  /// Exact phone lookup. Returns null when the number has not been seen yet.
  Future<Customer?> lookupByPhone(String phone) async {
    final data = await _apiService.get(
      '/api/Customers/lookup?phone=${Uri.encodeComponent(phone.trim())}',
    );

    if (data == null) return null;

    return Customer.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Customer>> getCustomers({String? phone, String? search}) async {
    final query = <String>[];
    final searchText = search?.trim() ?? '';
    final phoneText = phone?.trim() ?? '';

    if (searchText.isNotEmpty) {
      query.add('search=${Uri.encodeComponent(searchText)}');
    } else if (phoneText.isNotEmpty) {
      query.add('phone=${Uri.encodeComponent(phoneText)}');
    }

    final endpoint = query.isEmpty
        ? '/api/Customers'
        : '/api/Customers?${query.join('&')}';

    final data = await _apiService.get(endpoint);

    return (data as List)
        .map((json) => Customer.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Partial name/phone search used by the Customers screen.
  Future<List<Customer>> searchCustomers(String query) =>
      getCustomers(search: query);

  Future<CustomerDetails> getCustomerDetails(int id) async {
    final data = await _apiService.get('/api/Customers/$id/details');

    return CustomerDetails.fromJson(data as Map<String, dynamic>);
  }

  /// Pays the customer without choosing invoices. The backend applies the
  /// amount to the oldest unpaid invoices first.
  Future<CustomerDetails> payCustomer({
    required int customerId,
    required double amount,
    required int method,
  }) async {
    final data = await _apiService.post('/api/Customers/$customerId/payments', {
      'amount': amount,
      'method': method,
    });

    return CustomerDetails.fromJson(data as Map<String, dynamic>);
  }
}
