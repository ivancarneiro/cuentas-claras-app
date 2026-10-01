import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/monthly_summary.dart';
import '../models/saving.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _api;

  DataProvider(this._api);

  bool _isLoading = false;
  String? _error;

  // Households
  List<Map<String, dynamic>> _households = [];
  List<Map<String, dynamic>> get households => _households;

  // Categories
  List<Category> _categories = [];
  List<Category> get categories => _categories;

  // Transactions
  List<Transaction> _transactions = [];
  List<Transaction> get transactions => _transactions;

  // Monthly Summary
  MonthlySummary? _monthlySummary;
  MonthlySummary? get monthlySummary => _monthlySummary;

  // Savings
  SavingsSummary? _savingsSummary;
  SavingsSummary? get savingsSummary => _savingsSummary;
  final List<SavingAccount> _savingAccounts = [];
  List<SavingAccount> get savingAccounts => _savingAccounts;

  // Platform Admin (App Owner)
  List<Map<String, dynamic>> _adminUsers = [];
  List<Map<String, dynamic>> get adminUsers => _adminUsers;
  List<Map<String, dynamic>> _authorizedEmails = [];
  List<Map<String, dynamic>> get authorizedEmails => _authorizedEmails;

  // Filters
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  int? _selectedHouseholdId;
  int? get selectedHouseholdId => _selectedHouseholdId;

  int? _defaultHouseholdId;
  int? get defaultHouseholdId => _defaultHouseholdId;

  Future<void> setSelectedHousehold(int? householdId, {bool saveAsDefault = false}) async {
    if (_selectedHouseholdId == householdId && !saveAsDefault) return;
    _selectedHouseholdId = householdId;
    if (saveAsDefault && householdId != null) {
      _defaultHouseholdId = householdId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('default_household_id', householdId);
    }
    notifyListeners();
    await refreshAll();
  }

  Future<void> setDefaultHousehold(int householdId) async {
    _defaultHouseholdId = householdId;
    _selectedHouseholdId = householdId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_household_id', householdId);
    notifyListeners();
    await refreshAll();
  }

  // Pending invitations
  List<Map<String, dynamic>> _pendingInvitations = [];
  List<Map<String, dynamic>> get pendingInvitations => _pendingInvitations;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void setMonth(int month, int year) {
    _selectedMonth = month;
    _selectedYear = year;
    notifyListeners();
    refreshAll();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Households ──────────────────────────────────────────────────

  Future<void> loadHouseholds() async {
    try {
      _households = (await _api.getMyHouseholds())
          .cast<Map<String, dynamic>>();

      final prefs = await SharedPreferences.getInstance();
      final savedDefault = prefs.getInt('default_household_id');
      if (savedDefault != null && _households.any((h) => h['id'] == savedDefault)) {
        _defaultHouseholdId = savedDefault;
      } else if (_households.isNotEmpty) {
        _defaultHouseholdId = _households.first['id'] as int;
      }

      if (_selectedHouseholdId == null) {
        _selectedHouseholdId = _defaultHouseholdId;
      } else if (!_households.any((h) => h['id'] == _selectedHouseholdId)) {
        _selectedHouseholdId = _defaultHouseholdId;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }


  Future<bool> createHousehold(String name) async {
    try {
      await _api.createHousehold({'name': name});
      await loadHouseholds();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteHousehold(int householdId) async {
    try {
      await _api.deleteHousehold(householdId);
      await loadHouseholds();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }


  Future<Map<String, dynamic>?> inviteMember(int householdId, String email, {String role = 'read'}) async {
    try {
      final res = await _api.inviteMember(householdId, email, role: role);
      await loadHouseholds();
      return res;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadPendingInvitations() async {
    try {
      _pendingInvitations = (await _api.getPendingInvitations())
          .cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> acceptInvitation(String token) async {
    try {
      await _api.acceptInvitation(token);
      await loadHouseholds();
      await loadPendingInvitations();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineInvitation(int invitationId) async {
    try {
      await _api.declineInvitation(invitationId);
      await loadHouseholds();
      await loadPendingInvitations();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelInvitation(int invitationId) => declineInvitation(invitationId);


  Future<bool> updateMemberRole(int householdId, int memberId, String role) async {
    try {
      await _api.updateMemberRole(householdId, memberId, role);
      await loadHouseholds();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(int householdId, int memberId) async {
    try {
      await _api.removeMember(householdId, memberId);
      await loadHouseholds();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Categories ──────────────────────────────────────────────────

  Future<void> loadCategories() async {
    try {
      final data = await _api.getCategories(householdId: _selectedHouseholdId);
      _categories = data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Category?> createCategory(Map<String, dynamic> data) async {
    try {
      if (data['household_id'] == null && _selectedHouseholdId != null) {
        data['household_id'] = _selectedHouseholdId;
      }
      final res = await _api.createCategory(data);
      await loadCategories();
      final cat = Category.fromJson(res);
      return cat;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCategory(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateCategory(id, data);
      await loadCategories();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await _api.deleteCategory(id);
      await loadCategories();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Transactions ────────────────────────────────────────────────

  Future<void> loadTransactions() async {
    try {
      final data = await _api.getTransactions(
        month: _selectedMonth,
        year: _selectedYear,
        householdId: _selectedHouseholdId,
      );
      _transactions = data.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMonthlySummary() async {
    try {
      final data = await _api.getMonthlySummary(
        _selectedMonth,
        _selectedYear,
        householdId: _selectedHouseholdId,
      );
      _monthlySummary = MonthlySummary.fromJson(data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> addTransaction(Map<String, dynamic> data) async {
    try {
      if (data['household_id'] == null && _selectedHouseholdId != null) {
        data['household_id'] = _selectedHouseholdId;
      }
      await _api.createTransaction(data);
      await loadTransactions();
      await loadMonthlySummary();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransaction(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateTransaction(id, data);
      await loadTransactions();
      await loadMonthlySummary();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      await _api.deleteTransaction(id);
      await loadTransactions();
      await loadMonthlySummary();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Savings ─────────────────────────────────────────────────────

  Future<void> loadSavings() async {
    try {
      final data = await _api.getSavingsSummary(
        householdId: _selectedHouseholdId,
        year: _selectedYear,
      );
      _savingsSummary = SavingsSummary.fromJson(data);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadSavingAccounts() async {
    try {
      final data = await _api.getSavingAccounts(householdId: _selectedHouseholdId);
      _savingAccounts
        ..clear()
        ..addAll(data.map((e) => SavingAccount.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createSavingAccount(Map<String, dynamic> data) async {
    try {
      if (data['household_id'] == null && _selectedHouseholdId != null) {
        data['household_id'] = _selectedHouseholdId;
      }
      await _api.createSavingAccount(data);
      await loadSavingAccounts();
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSavingAccount(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateSavingAccount(id, data);
      await loadSavingAccounts();
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSavingAccount(int id) async {
    try {
      await _api.deleteSavingAccount(id);
      await loadSavingAccounts();
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createSaving(Map<String, dynamic> data) async {
    try {
      await _api.createSaving(data);
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSaving(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateSaving(id, data);
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSaving(int id) async {
    try {
      await _api.deleteSaving(id);
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setMonthlyFlow(int year, int month, double amountArs, {String? note}) async {
    try {
      await _api.setMonthlyFlow(year: year, month: month, amountArs: amountArs, note: note);
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMonthlyFlow(int year, int month) async {
    try {
      await _api.deleteMonthlyFlow(year: year, month: month);
      await loadSavings();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Platform Admin (App Owner) ──────────────────────────────────

  Future<void> loadAdminData() async {
    try {
      final res = await _api.getAdminUsers();
      _adminUsers = (res['users'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _authorizedEmails = (res['authorized_emails'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> authorizeEmail(String email, {String? notes}) async {
    try {
      await _api.authorizeEmail(email, notes: notes);
      await loadAdminData();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> revokeAuthorizedEmail(int id) async {
    try {
      await _api.revokeAuthorizedEmail(id);
      await loadAdminData();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleUserStatus(int userId) async {
    try {
      await _api.toggleUserStatus(userId);
      await loadAdminData();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Refresh All ─────────────────────────────────────────────────

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([
      loadCategories(),
      loadTransactions(),
      loadMonthlySummary(),
      loadSavings(),
      loadHouseholds(),
      loadSavingAccounts(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  // ── Helpers ─────────────────────────────────────────────────────

  List<Category> getCategoriesByType(String type) =>
      _categories.where((c) => c.type == type).toList();

  List<Category> get incomeCategories => getCategoriesByType('income');
  List<Category> get fixedExpenseCategories => getCategoriesByType('fixed_expense');
  List<Category> get variableExpenseCategories => getCategoriesByType('variable_expense');
}
