import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';

  bool _loading = false;
  String? _loginError;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _loginError = null;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _email.trim(),
        password: _password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Login fallito');
      }

      final profile = await supabase
          .from('profiles')
          .select('id,is_deleted')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && profile['is_deleted'] == true) {
        final reactivate = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Account eliminato'),
            content: const Text(
              'Questo account era stato eliminato. Vuoi riattivarlo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Riattiva'),
              ),
            ],
          ),
        );

        if (reactivate == true) {
          await supabase
              .from('profiles')
              .update({'is_deleted': false}).eq('id', user.id);

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
          return;
        } else {
          await supabase.auth.signOut();
          setState(() => _loading = false);
          return;
        }
      }

      /// PROFILO ESISTE → HOME
      if (profile != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      /// PROFILO NON ESISTE → CHIEDI NOME
      _askNameAndSave(user.id);
    } on AuthException {
      setState(() {
        _loginError = 'Email o password non corrette.';
      });
      _formKey.currentState!.validate();
    } catch (_) {
      setState(() {
        _loginError = 'Errore imprevisto.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.trim().isEmpty) {
      setState(() {
        _loginError = 'Inserisci prima la tua email';
      });
      return;
    }

    try {
      await supabase.auth.signInWithOtp(email: _email.trim());

      if (!mounted) return;

      Navigator.pushNamed(context, '/verify-code', arguments: _email.trim());
    } catch (_) {
      setState(() {
        _loginError = 'Errore nel recupero password';
      });
    }
  }

  void _askNameAndSave(String userId) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Come ti chiami?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              await supabase.from('profiles').insert({
                'id': userId,
                'full_name': controller.text.trim(),
              });

              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: const Text('Continua'),
          ),
        ],
      ),
    );
  }

  void _goToRegister() {
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6ED),
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Image.asset('assets/logo.png', height: 120),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => _email = v,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Inserisci la tua email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: const OutlineInputBorder(),
                                errorText: _loginError,
                              ),
                              obscureText: true,
                              onChanged: (v) => _password = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Inserisci la password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD84D),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _loading ? null : _submit,
                                child: const Text(
                                  'Accedi',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _goToRegister,
                              child: const Text(
                                'Non hai un account? Registrati',
                              ),
                            ),
                            TextButton(
                              onPressed: _resetPassword,
                              child: const Text('Hai dimenticato la password?'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD84D)),
              ),
            ),
        ],
      ),
    );
  }
}
