import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/providers/auth_api_provider.dart';
import 'package:bridalglow_mobile/providers/auth_provider.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';
import 'package:bridalglow_mobile/providers/dress_availability_slot_provider.dart';
import 'package:bridalglow_mobile/providers/dress_price_rule_provider.dart';
import 'package:bridalglow_mobile/providers/dress_category_provider.dart';
import 'package:bridalglow_mobile/providers/dress_image_provider.dart';
import 'package:bridalglow_mobile/providers/dress_provider.dart';
import 'package:bridalglow_mobile/providers/dress_tag_provider.dart';
import 'package:bridalglow_mobile/providers/interaction_provider.dart';
import 'package:bridalglow_mobile/providers/notification_provider.dart';
import 'package:bridalglow_mobile/providers/payment_provider.dart';
import 'package:bridalglow_mobile/providers/recommendation_provider.dart';
import 'package:bridalglow_mobile/providers/refund_provider.dart';
import 'package:bridalglow_mobile/providers/rental_reservation_provider.dart';
import 'package:bridalglow_mobile/providers/review_provider.dart';
import 'package:bridalglow_mobile/providers/try_on_reservation_provider.dart';
import 'package:bridalglow_mobile/providers/user_provider.dart';
import 'package:bridalglow_mobile/screens/home_screen.dart';
import 'package:bridalglow_mobile/screens/login_screen.dart';
import 'package:bridalglow_mobile/utils/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  BaseProvider.init();

  const stripeKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  stripe.Stripe.publishableKey = stripeKey.isNotEmpty
      ? stripeKey
      : (dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '');
  stripe.Stripe.merchantIdentifier = 'merchant.flutter.stripe.test';
  stripe.Stripe.urlScheme = 'flutterstripe';
  await stripe.Stripe.instance.applySettings();

  runApp(const BridalGlowMobileApp());
}

class BridalGlowMobileApp extends StatelessWidget {
  const BridalGlowMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DressProvider()),
        ChangeNotifierProvider(create: (_) => DressCategoryProvider()),
        ChangeNotifierProvider(create: (_) => DressTagProvider()),
        ChangeNotifierProvider(create: (_) => InteractionProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
        ChangeNotifierProvider(create: (_) => DressImageProvider()),
        ChangeNotifierProvider(create: (_) => DressAvailabilitySlotProvider()),
        ChangeNotifierProvider(create: (_) => DressPriceRuleProvider()),
        ChangeNotifierProvider(create: (_) => TryOnReservationProvider()),
        ChangeNotifierProvider(create: (_) => RentalReservationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => RefundProvider()),
      ],
      child: MaterialApp(
        title: 'BridalGlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD4A5A5)),
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
        home: const SplashGate(),
      ),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await SessionStorage.loadSession();
    if (session == null) {
      _go(const LoginScreen());
      return;
    }

    AuthProvider.accessToken = session.accessToken;
    AuthProvider.refreshToken = session.refreshToken;
    UserProvider.currentUser = session.user;

    if (session.accessTokenExpiresAtUtc.isBefore(DateTime.now().toUtc())) {
      final refreshed = await AuthApiProvider.refresh(session.refreshToken);
      if (refreshed != null) {
        await SessionStorage.saveSession(refreshed);
        _go(const HomeScreen());
        return;
      }
      await SessionStorage.clearSession();
      if (mounted) context.read<InteractionProvider>().clearFavorites();
      _go(const LoginScreen());
      return;
    }

    _go(const HomeScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
