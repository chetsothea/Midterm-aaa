// One bank the shop takes KHQR payments into (ABA, ACLEDA, ...)
class PaymentAccount {
  final int? id; // null for the fallback account set in the API's .env
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String qrImageUrl; // '' when no QR picture was uploaded

  const PaymentAccount({
    this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.qrImageUrl = '',
  });

  factory PaymentAccount.fromJson(Map<String, dynamic> json) => PaymentAccount(
    id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
    bankName: '${json['bank_name'] ?? ''}',
    accountName: '${json['account_name'] ?? ''}',
    accountNumber: '${json['account_number'] ?? ''}',
    qrImageUrl: '${json['qr_image_url'] ?? ''}',
  );

  // /payment-info: the list of banks, or (older API) one bank at the top level
  static List<PaymentAccount> listFromInfo(Map<String, dynamic> info) {
    final list = info['accounts'];
    if (list is List && list.isNotEmpty) {
      return [
        for (final a in list)
          PaymentAccount.fromJson(Map<String, dynamic>.from(a)),
      ];
    }
    return [PaymentAccount.fromJson(info)];
  }

  // A short label and colour for the bank's tab
  String get shortName {
    final name = bankName.toUpperCase();
    if (name.contains('ABA')) return 'ABA';
    if (name.contains('ACLEDA')) return 'ACLEDA';
    if (name.contains('WING')) return 'Wing';
    return bankName.split(' ').first;
  }
}
