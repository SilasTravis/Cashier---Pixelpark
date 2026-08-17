part of 'pos_account_bloc.dart';

class PosAccountState extends Equatable {
  const PosAccountState({
    this.phoneDigits = '',
    this.isSearching = false,
    this.results = const [],
    this.recentCustomers = const [],
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
  });

  final String phoneDigits;
  final bool isSearching;
  final List<Customer> results;

  /// Latest customers, shown as a browsable default before the cashier
  /// types anything — capped to 10 in the bloc.
  final List<Customer> recentCustomers;
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

  PosAccountState copyWith({
    String? phoneDigits,
    bool? isSearching,
    List<Customer>? results,
    List<Customer>? recentCustomers,
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
  }) {
    return PosAccountState(
      phoneDigits: phoneDigits ?? this.phoneDigits,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      recentCustomers: recentCustomers ?? this.recentCustomers,
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
    );
  }

  @override
  List<Object?> get props => [
    phoneDigits,
    isSearching,
    results,
    recentCustomers,
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
  ];
}
