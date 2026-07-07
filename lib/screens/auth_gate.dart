import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../models/app_user.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const _SupabaseSetupScreen();
    }

    return StreamBuilder(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = SupabaseService.client.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<AppUser?>(
          future: SupabaseService.fetchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return const LoginScreen();
            }

            return MainNavigation(
              role: profile.role.value,
              email: profile.email,
              userId: profile.id,
            );
          },
        );
      },
    );
  }
}

class _SupabaseSetupScreen extends StatelessWidget {
  const _SupabaseSetupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.cloud_off, size: 56),
              SizedBox(height: 16),
              Text(
                'Supabase belum dikonfigurasi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Tambahkan SUPABASE_URL dan SUPABASE_ANON_KEY saat menjalankan aplikasi.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
