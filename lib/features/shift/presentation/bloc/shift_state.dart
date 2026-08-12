part of 'shift_bloc.dart';

class ShiftState extends Equatable {
  const ShiftState({
    this.isLoading = false,
    this.shift,
    this.lastClosed,
    this.errorMessage,
  });

  final bool isLoading;
  final Shift? shift;

  /// Populated right after a close so the UI can show a summary dialog.
  final Shift? lastClosed;
  final String? errorMessage;

  bool get hasOpenShift => shift != null && shift!.isOpen;

  ShiftState copyWith({
    bool? isLoading,
    Shift? shift,
    bool clearShift = false,
    Shift? lastClosed,
    String? errorMessage,
  }) {
    return ShiftState(
      isLoading: isLoading ?? this.isLoading,
      shift: clearShift ? null : (shift ?? this.shift),
      lastClosed: lastClosed ?? this.lastClosed,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isLoading, shift, lastClosed, errorMessage];
}
