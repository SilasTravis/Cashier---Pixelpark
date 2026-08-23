part of 'pos_account_bloc.dart';

class PosAccountState extends Equatable {
  const PosAccountState({
    this.phoneDigits = '',
    this.searchQuery = '',
    this.isSearching = false,
    this.results = const [],
    this.recentCustomers = const [],
    this.customerHistory = const [],
    this.customerPage = 1,
    this.hasMoreCustomers = true,
    this.isLoadingMoreCustomers = false,
    this.selectedCustomer,
    this.isBusy = false,
    this.errorMessage,
    this.plans = const [],
    this.isLoadingPlans = false,
    this.products = const [],
    this.playing = const [],
    this.activePasses = const [],
    this.lastEntryResult,
    this.lastParentPass,
    this.companionPriceUzs = defaultCompanionPriceUzs,
  });

  /// Fallback HAMROH price used until (or if) `GET /v1/pos/config` answers —
  /// matches the backend constant at the time this build shipped.
  static const defaultCompanionPriceUzs = 10000;

  final String phoneDigits;
  final String searchQuery;
  final bool isSearching;
  final List<Customer> results;

  /// Latest customers, shown as a browsable default before the cashier
  /// types anything — capped to 10 in the bloc.
  final List<Customer> recentCustomers;

  /// Customers opened by this cashier during the current app session.
  final List<Customer> customerHistory;
  final int customerPage;
  final bool hasMoreCustomers;
  final bool isLoadingMoreCustomers;
  final Customer? selectedCustomer;
  final bool isBusy;
  final String? errorMessage;

  /// Standard/VIP tariffs — fetched once at page load, not per customer.
  final List<KidsPlan> plans;
  final bool isLoadingPlans;

  /// Ticket-type products sellable at the plan-entry checkout — fetched
  /// once at page load, same lifecycle as [plans].
  final List<Product> products;

  /// The selected customer's currently-inside children with live due-so-far
  /// — refreshed on selection and after each checkout.
  final List<PlayingChild> playing;

  /// Each child's still-valid day pass — the "already on this plan today"
  /// badge; same refresh lifecycle as [playing].
  final List<ActivePass> activePasses;

  /// Set right after a plan-entry request so the UI can pop the
  /// entrance-QR slip dialog and surface any per-child failures; cleared
  /// once acknowledged.
  final PosEntryResult? lastEntryResult;

  /// Set right after a parent-QR request so the UI can print the sticker;
  /// cleared once acknowledged — same lifecycle as [lastEntryResult].
  final ParentPass? lastParentPass;

  /// Price of one paid HAMROH companion sticker — server-owned, fetched at
  /// page load; the compiled-in default covers older backends.
  final int companionPriceUzs;

  PosAccountState copyWith({
    String? phoneDigits,
    String? searchQuery,
    bool? isSearching,
    List<Customer>? results,
    List<Customer>? recentCustomers,
    List<Customer>? customerHistory,
    int? customerPage,
    bool? hasMoreCustomers,
    bool? isLoadingMoreCustomers,
    Customer? selectedCustomer,
    bool clearSelected = false,
    bool? isBusy,
    String? errorMessage,
    List<KidsPlan>? plans,
    bool? isLoadingPlans,
    List<Product>? products,
    List<PlayingChild>? playing,
    List<ActivePass>? activePasses,
    PosEntryResult? lastEntryResult,
    bool clearLastEntryResult = false,
    ParentPass? lastParentPass,
    bool clearLastParentPass = false,
    int? companionPriceUzs,
  }) {
    return PosAccountState(
      phoneDigits: phoneDigits ?? this.phoneDigits,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      recentCustomers: recentCustomers ?? this.recentCustomers,
      customerHistory: customerHistory ?? this.customerHistory,
      customerPage: customerPage ?? this.customerPage,
      hasMoreCustomers: hasMoreCustomers ?? this.hasMoreCustomers,
      isLoadingMoreCustomers:
          isLoadingMoreCustomers ?? this.isLoadingMoreCustomers,
      selectedCustomer: clearSelected
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      isBusy: isBusy ?? this.isBusy,
      errorMessage: errorMessage,
      plans: plans ?? this.plans,
      isLoadingPlans: isLoadingPlans ?? this.isLoadingPlans,
      products: products ?? this.products,
      playing: playing ?? this.playing,
      activePasses: activePasses ?? this.activePasses,
      lastEntryResult: clearLastEntryResult
          ? null
          : (lastEntryResult ?? this.lastEntryResult),
      lastParentPass: clearLastParentPass
          ? null
          : (lastParentPass ?? this.lastParentPass),
      companionPriceUzs: companionPriceUzs ?? this.companionPriceUzs,
    );
  }

  @override
  List<Object?> get props => [
    phoneDigits,
    searchQuery,
    isSearching,
    results,
    recentCustomers,
    customerHistory,
    customerPage,
    hasMoreCustomers,
    isLoadingMoreCustomers,
    selectedCustomer,
    isBusy,
    errorMessage,
    plans,
    isLoadingPlans,
    products,
    playing,
    activePasses,
    lastEntryResult,
    lastParentPass,
    companionPriceUzs,
  ];
}
