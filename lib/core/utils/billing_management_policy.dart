import '../../models/models.dart';

enum BillingBucket { all, rent, utilities, other }

enum BillingStatusFilter {
  all,
  due,
  overdue,
  pending,
  verified,
  upcoming,
  voided,
}

abstract final class BillingManagementPolicy {
  static const utilityCategories = <String>{
    'electricity',
    'water',
    'internet',
    'utility',
  };

  static const additionalChargeCategories = <String>{
    'damage',
    'fine',
    'late_fee',
    'cleaning',
    'replacement',
    'other',
  };

  static bool isUtility(Payment payment) =>
      utilityCategories.contains(payment.category.trim().toLowerCase());

  static bool isAdditionalCharge(Payment payment) => additionalChargeCategories
      .contains(payment.category.trim().toLowerCase());

  static bool matchesBucket(Payment payment, BillingBucket bucket) {
    return switch (bucket) {
      BillingBucket.all => true,
      BillingBucket.rent => payment.isRent,
      BillingBucket.utilities => isUtility(payment),
      BillingBucket.other => isAdditionalCharge(payment),
    };
  }

  static bool matchesStatus(Payment payment, BillingStatusFilter status) {
    return switch (status) {
      BillingStatusFilter.all => true,
      BillingStatusFilter.due =>
        !payment.isVoided && !payment.isVerified && !payment.isUpcoming,
      BillingStatusFilter.overdue => payment.isOverdue,
      BillingStatusFilter.pending => payment.isPending,
      BillingStatusFilter.verified => payment.isVerified,
      BillingStatusFilter.upcoming => payment.isUpcoming,
      BillingStatusFilter.voided => payment.isVoided,
    };
  }

  static List<Payment> filter(
    Iterable<Payment> payments, {
    String query = '',
    BillingBucket bucket = BillingBucket.all,
    BillingStatusFilter status = BillingStatusFilter.all,
  }) {
    final normalized = query.trim().toLowerCase();
    final result = payments.where((payment) {
      if (!matchesBucket(payment, bucket) || !matchesStatus(payment, status)) {
        return false;
      }
      if (normalized.isEmpty) return true;
      final haystack = <String>[
        payment.tenantName ?? '',
        payment.tenantRoom ?? '',
        payment.label,
        payment.category,
        payment.status,
        payment.reference ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();

    result.sort((a, b) {
      final overdueCompare =
          (b.isOverdue ? 1 : 0).compareTo(a.isOverdue ? 1 : 0);
      if (overdueCompare != 0) return overdueCompare;
      final pendingCompare =
          (b.isPending ? 1 : 0).compareTo(a.isPending ? 1 : 0);
      if (pendingCompare != 0) return pendingCompare;
      return a.dueDate.compareTo(b.dueDate);
    });
    return result;
  }

  static Iterable<Payment> payableNow(Iterable<Payment> payments) =>
      payments.where((payment) =>
          !payment.isDeposit &&
          !payment.isVoided &&
          !payment.isVerified &&
          !payment.isUpcoming);

  static double outstandingNow(Iterable<Payment> payments) =>
      payableNow(payments)
          .fold<double>(0, (sum, payment) => sum + payment.outstandingAmount);

  static double utilityOutstanding(Iterable<Payment> payments) =>
      payableNow(payments)
          .where(isUtility)
          .fold<double>(0, (sum, payment) => sum + payment.outstandingAmount);

  static int pendingReviewCount(Iterable<Payment> payments) => payments
      .where((payment) => payment.isPending && !payment.isDeposit)
      .length;

  static int overdueCount(Iterable<Payment> payments) => payments
      .where((payment) => payment.isOverdue && !payment.isDeposit)
      .length;
}
