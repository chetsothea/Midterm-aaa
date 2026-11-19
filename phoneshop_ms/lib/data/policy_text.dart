// The privacy policy and terms shown in the app. The same text is on the web
// at /privacy and /terms (phoneshop_api/resources/views/legal): change both
// together, and the date.

class PolicySection {
  final String km;
  final String en;
  final List<(String, String)> points; // (Khmer, English)

  const PolicySection(this.km, this.en, this.points);
}

const policyUpdated = '18/11/2026';

const privacySections = <PolicySection>[
  PolicySection("ព័ត៌មានដែលយើងប្រមូល", "What we collect", [
    (
      "ឈ្មោះ Email លេខទូរស័ព្ទ អាសយដ្ឋានដឹកជញ្ជូន និងរូប Profile ដែលអ្នកបញ្ចូល",
      "Name, e-mail, phone, delivery address and the profile picture you add",
    ),
    (
      "Order: ទូរស័ព្ទដែលទិញ តម្លៃ ការបង់ប្រាក់ ស្ថានភាពដឹកជញ្ជូន និង IMEI របស់ទូរស័ព្ទដែលបានលក់",
      "Orders: phones bought, prices, payment, delivery status and the IMEI of phones sold",
    ),
    (
      "Trade-in: ព័ត៌មាន និងរូបទូរស័ព្ទចាស់ដែលអ្នកផ្ញើ",
      "Trade-in: the details and photos of the old phone you send",
    ),
    (
      "ការវាយតម្លៃ មតិក្នុង Live ទូរស័ព្ទ ♥ និង Cart របស់អ្នក",
      "Your reviews, Live comments, ♥ phones and cart",
    ),
    (
      "លើឧបករណ៍: Token Login (ក្នុង Keychain/Keystore) Cart ភាសា និងរបៀបពន្លឺ/ងងឹត",
      "On your device: the login token (Keychain/Keystore), cart, language and light/dark mode",
    ),
  ]),
  PolicySection("ហេតុអ្វីយើងប្រើវា", "Why we use it", [
    (
      "ដើម្បីដំណើរការ Order ដឹកជញ្ជូន និងទាក់ទងអ្នក",
      "To process orders, deliver them and contact you",
    ),
    (
      "ដើម្បីផ្ទៀងផ្ទាត់ការបង់ប្រាក់ ធានា ទូរស័ព្ទ និង Trade-in",
      "To check payments, and to handle warranties and trade-ins",
    ),
    (
      "ដើម្បីផ្ញើលេខកូដកំណត់ពាក្យសម្ងាត់ និងការជូនដំណឹងអំពី Order",
      "To send password reset codes and order notifications",
    ),
    (
      "ដើម្បីការពារគណនី (ឧ. កំណត់ចំនួនដង Login)",
      "To protect accounts (e.g. limiting login attempts)",
    ),
  ]),
  PolicySection("អ្នកណាខ្លះឃើញវា", "Who sees it", [
    (
      "ហាង PS168 និងបុគ្គលិក (សម្រាប់ Order តែប៉ុណ្ណោះ)",
      "The PS168 shop and its staff (for orders only)",
    ),
    (
      "ក្រុមហ៊ុនដឹកជញ្ជូន: ឈ្មោះ លេខទូរស័ព្ទ និងអាសយដ្ឋាន ដើម្បីដឹកឥវ៉ាន់",
      "Delivery companies: name, phone and address, to deliver your parcel",
    ),
    (
      "ធនាគារ / Bakong: ពិនិត្យថាការបង់ប្រាក់ KHQR បានចូលហើយ",
      "Banks / Bakong: to confirm a KHQR payment arrived",
    ),
    (
      "Google: តែពេលអ្នកជ្រើស Login ជាមួយ Google",
      "Google: only if you choose to sign in with Google",
    ),
    (
      "យើងមិនលក់ ឬជួលព័ត៌មានរបស់អ្នកទៅអ្នកណាទេ",
      "We never sell or rent your information",
    ),
  ]),
  PolicySection("រយៈពេលរក្សាទុក", "How long we keep it", [
    ("គណនី: រហូតដល់អ្នកលុបវា", "Your account: until you delete it"),
    (
      "Order: ហាងរក្សាទុកសម្រាប់បញ្ជីគណនេយ្យ និងការធានា ទោះលុបគណនីក៏ដោយ (លែងភ្ជាប់នឹងគណនី)",
      "Orders: kept for the shop's accounts and warranties, even after the account is deleted (no longer linked to it)",
    ),
    (
      "លេខកូដកំណត់ពាក្យសម្ងាត់: 15 នាទី · Backup: 14 ថ្ងៃ",
      "Password reset codes: 15 minutes · Backups: 14 days",
    ),
  ]),
  PolicySection("សិទ្ធិរបស់អ្នក", "Your choices", [
    (
      "កែឈ្មោះ លេខទូរស័ព្ទ អាសយដ្ឋាន និងរូប នៅ គណនី › កែព័ត៌មាន",
      "Change your name, phone, address and picture in Account › Edit profile",
    ),
    (
      "លុបគណនី និងទិន្នន័យរបស់អ្នក នៅ គណនី › លុបគណនី",
      "Delete your account and data in Account › Delete account",
    ),
    (
      "សួរ ឬស្នើអ្វីផ្សេង តាម Telegram របស់ហាង",
      "Ask us anything through the shop's Telegram",
    ),
  ]),
  PolicySection("សុវត្ថិភាព", "Security", [
    (
      "ពាក្យសម្ងាត់ត្រូវបាន hash (មិនអាចអានបាន) ហើយការភ្ជាប់ទៅ server ប្រើ HTTPS",
      "Passwords are stored hashed (unreadable) and the app talks to the server over HTTPS",
    ),
    ("Token Login ផុតកំណត់ក្រោយ 30 ថ្ងៃ", "Login tokens expire after 30 days"),
  ]),
];

const termsSections = <PolicySection>[
  PolicySection("តម្លៃ និងស្តុក", "Prices and stock", [
    (
      "តម្លៃ និងស្តុកអាចប្រែប្រួល។ តម្លៃពិតគឺតម្លៃដែលបង្ហាញពេលបញ្ជាទិញ",
      "Prices and stock can change. The price you pay is the one shown when you order",
    ),
  ]),
  PolicySection("ការបង់ប្រាក់", "Payment", [
    (
      "Order KHQR ត្រូវបង់ក្នុង 30 នាទី បើមិនដូច្នោះទេ Order ត្រូវបានបោះបង់ ហើយស្តុកត្រឡប់ទៅហាងវិញ",
      "KHQR orders must be paid within 30 minutes, or they are cancelled and the stock goes back",
    ),
    (
      "បង់ពេលទទួល (COD): បង់ឱ្យអ្នកដឹកពេលទទួលឥវ៉ាន់",
      "Cash on delivery: pay the courier when the parcel arrives",
    ),
  ]),
  PolicySection("ការបោះបង់ និងបង្វិលប្រាក់", "Cancelling and refunds", [
    (
      "អ្នកអាចបោះបង់ Order បាន ពេលវានៅរង់ចាំ ឬកំពុងវេចខ្ចប់។ ពេលចាប់ផ្តើមដឹកជញ្ជូនហើយ មិនអាចបោះបង់បានទេ",
      "You can cancel an order while it is waiting or being packed. Once it ships it can't be cancelled",
    ),
    (
      "បើបានបង់ប្រាក់រួច ហាងនឹងទាក់ទងអ្នកដើម្បីបង្វិលប្រាក់",
      "If you already paid, the shop contacts you to refund you",
    ),
  ]),
  PolicySection("ការធានា", "Warranty", [
    (
      "ការធានាចាប់ផ្តើមពីថ្ងៃដឹកដល់ តាមចំនួនខែដែលបង្ហាញលើទូរស័ព្ទនីមួយៗ ហើយកត់ត្រាតាម IMEI",
      "The warranty starts on the delivery day, for the months shown on each phone, and is tracked by IMEI",
    ),
  ]),
  PolicySection("Trade-in និងកូដបញ្ចុះ", "Trade-in and codes", [
    (
      "តម្លៃ Trade-in ជាកូដបញ្ចុះ ដែលចេញតែពេលហាងទទួលទូរស័ព្ទចាស់ហើយ ប្រើបានម្តង ក្នុង 90 ថ្ងៃ ហើយមិនអាចដូរជាសាច់ប្រាក់បានទេ",
      "Trade-in value is a discount code, issued once the shop has the old phone, usable once within 90 days, not exchangeable for cash",
    ),
    (
      "កូដបញ្ចុះម្នាក់ប្រើបានម្តង តាមលក្ខខណ្ឌរបស់កូដនីមួយៗ",
      "Each discount code can be used once per customer, under its own conditions",
    ),
  ]),
  PolicySection("គណនី", "Your account", [
    (
      "សូមរក្សាពាក្យសម្ងាត់ជាការសម្ងាត់។ ហាងអាចបិទគណនីដែលប្រើខុសគោលបំណង",
      "Keep your password secret. The shop may block accounts that are misused",
    ),
  ]),
];
