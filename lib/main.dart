import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/student_home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'eta_notifier.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(create: (_) => EtaNotifier(), child: BechBusApp()),
  );
}

class BechBusApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Bech Bus',
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(),
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            appBarTheme: AppBarTheme(
              elevation: 0,
              centerTitle: true,
              titleTextStyle: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasData && snapshot.data != null) {
                // User is signed in
                return StudentHomeScreen(
                  studentName: snapshot.data!.email ?? 'User',
                );
              }
              // User is not signed in
              return LoginScreen();
            },
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
