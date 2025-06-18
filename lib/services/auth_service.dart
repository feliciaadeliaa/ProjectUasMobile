import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final PocketBase pb;

  AuthService(this.pb);

  // Check if user is authenticated
  bool get isAuthenticated => pb.authStore.isValid;

  // Get current user
  dynamic get currentUser => pb.authStore.model;

  // Get current user ID
  String? get currentUserId => pb.authStore.model?.id;

  // Login with email and password
  Future<bool> login(String email, String password) async {
    try {
      print('🔐 Attempting login for: $email');
      
      final authData = await pb.collection('users').authWithPassword(email, password);
      
      if (authData.record != null) {
        print('✅ Login successful for user: ${authData.record!.id}');
        print('📧 User email: ${authData.record!.data['email']}');
        print('👤 User name: ${authData.record!.data['name'] ?? 'No name'}');
        
        // Save auth state
        await _saveAuthState();
        
        return true;
      } else {
        print('❌ Login failed: No user record returned');
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      
      // Handle specific error messages
      if (e.toString().contains('400')) {
        throw Exception('Invalid email or password');
      } else if (e.toString().contains('404')) {
        throw Exception('User not found');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your connection.');
      } else {
        throw Exception('Login failed: ${e.toString()}');
      }
    }
  }

  // Register new user with better error handling
  Future<bool> register(String email, String password, String name) async {
    try {
      print('📝 Attempting registration for: $email');
      
      // Validate input
      if (email.trim().isEmpty || password.isEmpty || name.trim().isEmpty) {
        throw Exception('All fields are required');
      }
      
      if (password.length < 8) {
        throw Exception('Password must be at least 8 characters long');
      }
      
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }
      
      final userData = {
        'email': email.trim(),
        'password': password,
        'passwordConfirm': password,
        'name': name.trim(),
        // Remove emailVisibility as it might not be allowed
      };

      print('📝 Creating user with data: $userData');

      // Add a small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
      
      final record = await pb.collection('users').create(body: userData);
      
      if (record.id.isNotEmpty) {
        print('✅ Registration successful for user: ${record.id}');
        print('📧 User email: ${record.data['email']}');
        print('👤 User name: ${record.data['name']}');
        
        // Auto-login after registration
        print('🔄 Attempting auto-login...');
        final loginSuccess = await login(email.trim(), password);
        
        if (loginSuccess) {
          print('✅ Auto-login after registration successful');
          return true;
        } else {
          print('⚠️ Registration successful but auto-login failed');
          return true; // Still consider registration successful
        }
      } else {
        print('❌ Registration failed: No user ID returned');
        return false;
      }
    } catch (e) {
      print('❌ Registration error: $e');
      
      String errorMessage = e.toString();
      
      // Handle specific PocketBase error messages
      if (errorMessage.contains('Failed to create record')) {
        if (errorMessage.contains('email')) {
          throw Exception('Email already exists or invalid email format');
        } else if (errorMessage.contains('password')) {
          throw Exception('Password must be at least 8 characters');
        } else {
          throw Exception('Registration failed. Please check your information.');
        }
      } else if (errorMessage.contains('validation_invalid_email')) {
        throw Exception('Invalid email format');
      } else if (errorMessage.contains('validation_length_out_of_range')) {
        throw Exception('Password must be at least 8 characters');
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (errorMessage.contains('Exception: ')) {
        // Re-throw our custom exceptions
        rethrow;
      } else {
        throw Exception('Registration failed: Please try again');
      }
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      print('🚪 Logging out user: ${currentUserId}');
      
      pb.authStore.clear();
      
      // Clear saved auth state
      await _clearAuthState();
      
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Even if there's an error, clear the auth state
      pb.authStore.clear();
      await _clearAuthState();
    }
  }

  // Refresh authentication token
  Future<bool> refreshAuth() async {
    try {
      if (!isAuthenticated) {
        print('⚠️ Cannot refresh: User not authenticated');
        return false;
      }

      print('🔄 Refreshing authentication...');
      
      await pb.collection('users').authRefresh();
      
      print('✅ Auth refresh successful');
      await _saveAuthState();
      
      return true;
    } catch (e) {
      print('❌ Auth refresh failed: $e');
      
      // If refresh fails, clear auth state
      pb.authStore.clear();
      await _clearAuthState();
      
      return false;
    }
  }

  // Check if auth is valid and refresh if needed
  Future<bool> validateAuth() async {
    try {
      if (!isAuthenticated) {
        print('⚠️ User not authenticated');
        return false;
      }

      // Try to make a simple authenticated request
      try {
        await pb.collection('users').getOne(currentUserId!);
        print('✅ Auth validation successful');
        return true;
      } catch (e) {
        print('⚠️ Auth validation failed, attempting refresh...');
        return await refreshAuth();
      }
    } catch (e) {
      print('❌ Auth validation error: $e');
      return false;
    }
  }

  // Save auth state to SharedPreferences
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = pb.authStore.token;
      final model = pb.authStore.model;
      
      if (token.isNotEmpty && model != null) {
        await prefs.setString('pb_token', token);
        await prefs.setString('pb_user_id', model.id);
        await prefs.setString('pb_user_email', model.data['email'] ?? '');
        await prefs.setString('pb_user_name', model.data['name'] ?? '');
        print('💾 Auth state saved');
      }
    } catch (e) {
      print('❌ Error saving auth state: $e');
    }
  }

  // Clear auth state from SharedPreferences
  Future<void> _clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pb_token');
      await prefs.remove('pb_user_id');
      await prefs.remove('pb_user_email');
      await prefs.remove('pb_user_name');
      print('🗑️ Auth state cleared');
    } catch (e) {
      print('❌ Error clearing auth state: $e');
    }
  }

  // Load auth state from SharedPreferences
  Future<bool> loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('pb_token');
      
      if (token != null && token.isNotEmpty) {
        // Restore auth state dengan token
        pb.authStore.save(token, null);
        print('📱 Auth state loaded from storage');
        
        // Validate auth dengan mencoba refresh
        return await validateAuth();
      } else {
        print('📱 No auth state found in storage');
        return false;
      }
    } catch (e) {
      print('❌ Error loading auth state: $e');
      return false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (!isAuthenticated) return null;

      final record = await pb.collection('users').getOne(currentUserId!);
      
      return {
        'id': record.id,
        'email': record.data['email'],
        'name': record.data['name'] ?? '',
        'avatar': record.data['avatar'] ?? '',
        'created': record.created,
        'updated': record.updated,
      };
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<bool> updateProfile({String? name, String? avatar}) async {
    try {
      if (!isAuthenticated) return false;

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (avatar != null) updateData['avatar'] = avatar;

      if (updateData.isEmpty) return true;

      await pb.collection('users').update(currentUserId!, body: updateData);
      
      print('✅ Profile updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  // Change password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      if (!isAuthenticated) return false;

      await pb.collection('users').update(currentUserId!, body: {
        'oldPassword': oldPassword,
        'password': newPassword,
        'passwordConfirm': newPassword,
      });
      
      print('✅ Password changed successfully');
      return true;
    } catch (e) {
      print('❌ Error changing password: $e');
      
      if (e.toString().contains('400')) {
        throw Exception('Invalid old password or new password too weak');
      } else {
        throw Exception('Failed to change password');
      }
    }
  }

  // Test connection to PocketBase
  Future<bool> testConnection() async {
    try {
      await pb.health.check();
      print('✅ PocketBase connection successful');
      return true;
    } catch (e) {
      print('❌ PocketBase connection failed: $e');
      return false;
    }
  }
}
