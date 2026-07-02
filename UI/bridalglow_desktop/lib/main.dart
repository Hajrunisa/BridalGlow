import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';
import 'package:bridalglow_desktop/providers/dress_category_provider.dart';
import 'package:bridalglow_desktop/providers/dress_image_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/dress_availability_slot_provider.dart';
import 'package:bridalglow_desktop/providers/dress_price_rule_provider.dart';
import 'package:bridalglow_desktop/providers/dress_tag_provider.dart';
import 'package:bridalglow_desktop/providers/try_on_reservation_provider.dart';
import 'package:bridalglow_desktop/providers/rental_reservation_provider.dart';
import 'package:bridalglow_desktop/providers/payment_provider.dart';
import 'package:bridalglow_desktop/providers/refund_provider.dart';
import 'package:bridalglow_desktop/providers/finance_provider.dart';
import 'package:bridalglow_desktop/providers/user_provider.dart';
import 'package:bridalglow_desktop/providers/review_provider.dart';
import 'package:bridalglow_desktop/providers/maintenance_record_provider.dart';
import 'package:bridalglow_desktop/providers/reports_provider.dart';
import 'package:bridalglow_desktop/providers/recommendation_provider.dart';
import 'package:bridalglow_desktop/providers/notification_provider.dart';
import 'package:bridalglow_desktop/providers/notification_refresh_coordinator.dart';
import 'package:bridalglow_desktop/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (silently ignored if the file is absent)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Initialise the single API base URL before any widget or static helper
  // can use it.  Must be called after dotenv.load().
  BaseProvider.init();

  runApp(const BridalGlowDesktopApp());
}

class BridalGlowDesktopApp extends StatelessWidget {
  const BridalGlowDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DressCategoryProvider()),
        ChangeNotifierProvider(create: (_) => DressTagProvider()),
        ChangeNotifierProvider(create: (_) => DressProvider()),
        ChangeNotifierProvider(create: (_) => DressImageProvider()),
        ChangeNotifierProvider(create: (_) => DressAvailabilitySlotProvider()),
        ChangeNotifierProvider(create: (_) => DressPriceRuleProvider()),
        ChangeNotifierProvider(create: (_) => TryOnReservationProvider()),
        ChangeNotifierProvider(create: (_) => RentalReservationProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => RefundProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceRecordProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationRefreshCoordinator()),
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(
            refreshCoordinator: context.read<NotificationRefreshCoordinator>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'BridalGlow Desktop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD4A5A5),
          ),
          useMaterial3: true,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
