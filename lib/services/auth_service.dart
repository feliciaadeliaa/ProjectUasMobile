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

  // Register new user
  Future<bool> register(String email, String password, String name) async {
    try {
      print('📝 Attempting registration for: $email');
      
      final userData = {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
      };

      final record = await pb.collection('users').create(body: userData);
      
      if (record.id.isNotEmpty) {
        print('✅ Registration successful for user: ${record.id}');
        
        // Auto-login after registration
        final loginSuccess = await login(email, password);
        
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
      
      // Handle specific error messages
      if (e.toString().contains('400')) {
        if (e.toString().contains('email')) {
          throw Exception('Email already exists or invalid format');
        } else if (e.toString().contains('password')) {
          throw Exception('Password must be at least 8 characters');
        } else {
          throw Exception('Invalid registration data');
        }
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your connection.');
      } else {
        throw Exception('Registration failed: ${e.toString()}');
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
      // Use the token and model data directly from authStore
      final token = pb.authStore.token;
      final model = pb.authStore.model;
      
      if (token.isNotEmpty && model != null) {
        await prefs.setString('pb_token', token);
        await prefs.setString('pb_model', model.toJson().toString());
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
      await prefs.remove('pb_auth');
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
      final modelData = prefs.getString('pb_model');
      
      if (token != null && token.isNotEmpty && modelData != null) {
        // Manually restore the auth state
        pb.authStore.save(token, null); // The model will be validated on next request
        print('📱 Auth state loaded from storage');
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
