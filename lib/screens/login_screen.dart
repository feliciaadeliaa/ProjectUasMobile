import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final PocketBase pb;

  const LoginScreen({super.key, required this.pb});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  late AuthService authService;
  
  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    authService = AuthService(widget.pb);
    
    // Pre-fill with test credentials for easier testing
    // _emailController.text = 'test@example.com';
    // _passwordController.text = 'testpassword';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool success = false;
      
      if (_isLoginMode) {
        print('🔐 Attempting login...');
        success = await authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (success) {
          print('✅ Login successful!');
          _showMessage('Welcome back!', Colors.green);
          
          // Small delay to show success message
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Navigate to home
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/');
          }
        }
      } else {
        print('📝 Attempting registration...');
        
        // Additional validation for registration
        if (_nameController.text.trim().isEmpty) {
          _showMessage('Please enter your full name', Colors.red);
          return;
        }
        
        if (_passwordController.text.length < 8) {
          _showMessage('Password must be at least 8 characters', Colors.red);
          return;
        }
        
        success = await authService.register(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        
        if (success) {
          print('✅ Registration successful!');
          _showMessage('Account created successfully! Welcome!', Colors.green);
          
          // Small delay to show success message
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Navigate to home
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/');
          }
        }
      }
    } catch (e) {
      print('❌ Auth error: $e');
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Handle specific error cases
      if (errorMessage.contains('email already exists')) {
        errorMessage = 'An account with this email already exists. Try logging in instead.';
      } else if (errorMessage.contains('invalid email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (errorMessage.contains('password')) {
        errorMessage = 'Password must be at least 8 characters long.';
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      _showMessage(errorMessage, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      // Clear form errors
      _formKey.currentState?.reset();
      
      // Keep email and password for easier testing, but clear name
      if (_isLoginMode) {
        _nameController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // App Logo/Title
              Icon(
                Icons.task_alt,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'TaskFlow',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your tasks efficiently',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      _isLoginMode ? 'Welcome Back' : 'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Name field (only for registration)
                    if (!_isLoginMode) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          helperText: 'Enter your full name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (!_isLoginMode && value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isLoginMode ? 'Login' : 'Register',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Toggle mode button
                    TextButton(
                      onPressed: _isLoading ? null : _toggleMode,
                      child: Text(
                        _isLoginMode
                            ? "Don't have an account? Register"
                            : 'Already have an account? Login',
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              
              const SizedBox(height: 16),
              
              
            ],
          ),
        ),
      ),
    );
  }
}
