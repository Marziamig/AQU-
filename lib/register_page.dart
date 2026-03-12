import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/terms_screen.dart';
import '../screens/privacy_screen.dart';

final supabase = Supabase.instance.client;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';

  bool _acceptTerms = false;

  bool _loading = false;
  String? _registerError;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

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

    if (!_acceptTerms) {
      setState(() {
        _registerError = 'Devi accettare Termini e Privacy.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _registerError = null;
    });

    try {
      await supabase.auth.signInWithOtp(
        email: _email.trim(),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Controlla la tua email'),
          content: const Text(
              'Ti abbiamo inviato un codice via email. Inseriscilo nella schermata successiva.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/verify-code',
                  arguments: _email.trim(),
                );
              },
              child: const Text('Inserisci codice'),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already registered')) {
        setState(() {
          _registerError =
              'Account già esistente. Hai dimenticato la password?';
        });
      } else {
        setState(() {
          _registerError = e.message;
        });
      }
    } catch (_) {
      setState(() {
        _registerError = 'Errore imprevisto.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsScreen()),
    );
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
    );
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
                    Image.asset(
                      'assets/logo.png',
                      height: 120,
                    ),
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
                              keyboardType: TextInputType.emailAddress,
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
                                errorText: _registerError,
                              ),
                              obscureText: true,
                              onChanged: (v) => _password = v,
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'Minimo 6 caratteri';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: _acceptTerms,
                              onChanged: (v) {
                                setState(() {
                                  _acceptTerms = v ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Wrap(
                                children: [
                                  const Text('Accetto i '),
                                  GestureDetector(
                                    onTap: _openTerms,
                                    child: const Text(
                                      'Termini e Condizioni',
                                      style: TextStyle(
                                          decoration: TextDecoration.underline),
                                    ),
                                  ),
                                  const Text(' e la '),
                                  GestureDetector(
                                    onTap: _openPrivacy,
                                    child: const Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                          decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD84D),
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _loading ? null : _submit,
                                child: const Text(
                                  'Registrati',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _goToLogin,
                              child: const Text('Hai già un account? Accedi'),
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
                child: CircularProgressIndicator(
                  color: Color(0xFFFFD84D),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
