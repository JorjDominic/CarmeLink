enum ConfidentialReviewAction {
  underReview('under_review', 'Mark confidential report under review',
      'Mark under review', 'Confidential report marked under review.'),
  resolve('resolved', 'Resolve confidential report', 'Resolve report',
      'Confidential report resolved.'),
  dismiss('dismissed', 'Dismiss confidential report', 'Dismiss report',
      'Confidential report dismissed.');

  const ConfidentialReviewAction(
      this.status, this.title, this.confirmLabel, this.successMessage);
  final String status, title, confirmLabel, successMessage;

  static ConfidentialReviewAction forStatus(String status) =>
      values.firstWhere((action) => action.status == status);
}
