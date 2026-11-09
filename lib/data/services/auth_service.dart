import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_token_storage.dart';
import '../../core/network/api_exception.dart';
import '../models/api_response.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';

/// Authentication Service
class AuthService {
  final ApiClient _apiClient;
  static const String _userKey = 'user_data';
  final AuthTokenStorage _tokenStorage;

  AuthService({ApiClient? apiClient, AuthTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? AuthTokenStorage.instance,
        _apiClient = apiClient ??
            ApiClient(tokenStorage: tokenStorage ?? AuthTokenStorage.instance);

  /// Login
  Future<LoginData> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.authLogin,
      body: {
        'email': email,
        'password': password,
        'device_name': deviceName ?? ApiConfig.deviceName,
      },
    );

    // Check success first before parsing data
    if (response['success'] == false) {
      throw ApiException(
        message: response['message'] ?? 'Login failed',
        code: response['error_code'] ?? 'LOGIN_FAILED',
        errors: response['errors'] as Map<String, dynamic>?,
      );
    }

    // Parse response
    final apiResponse = ApiResponse<LoginData>.fromJson(
      response,
      (data) => LoginData.fromJson(data as Map<String, dynamic>),
    );

    if (!apiResponse.success || apiResponse.data == null) {
      throw ApiException(
        message: apiResponse.message,
        code: apiResponse.errorCode ?? 'LOGIN_FAILED',
      );
    }

    // Save token and user data
    await _saveAuthData(apiResponse.data!);

    return apiResponse.data!;
  }

  /// Register
  Future<LoginData> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.authRegister,
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'terms_accepted': '1',
      },
    );

    // Check success first before parsing data
    if (response['success'] == false) {
      throw ApiException(
        message: response['message'] ?? 'Registration failed',
        code: response['error_code'] ?? 'REGISTER_FAILED',
        errors: response['errors'] as Map<String, dynamic>?,
      );
    }

    // Parse response
    final apiResponse = ApiResponse<LoginData>.fromJson(
      response,
      (data) => LoginData.fromJson(data as Map<String, dynamic>),
    );

    if (!apiResponse.success || apiResponse.data == null) {
      throw ApiException(
        message: apiResponse.message,
        code: apiResponse.errorCode ?? 'REGISTER_FAILED',
      );
    }

    // Save token and user data
    await _saveAuthData(apiResponse.data!);

    return apiResponse.data!;
  }

  /// Save authentication data to secure/local storage.
  Future<void> _saveAuthData(LoginData loginData) async {
    await _tokenStorage.writeToken(loginData.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _userToJson(loginData.user));
    await prefs.setBool('isLoggedIn', true);
  }

  String _userToJson(UserModel user) => jsonEncode(user.toJson());

  /// Parse the cached user with the standard JSON decoder.
  UserModel? _parseUserFromJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;
      return UserModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Get saved token from platform secure storage. This also migrates the
  /// legacy SharedPreferences token on the first read.
  Future<String?> getToken() => _tokenStorage.readToken();

  /// Get saved user
  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      return _parseUserFromJson(userJson);
    }

    return null;
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Revoke the current server token when possible, then clear local auth.
  Future<void> logout() async {
    try {
      final token = await _tokenStorage.readToken();
      if (token != null && token.isNotEmpty) {
        await _apiClient.post(
          ApiConfig.authLogout,
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (_) {
      // Revocation errors must not keep local credentials on the device.
    } finally {
      await _clearLocalAuth();
    }
  }

  Future<void> _clearLocalAuth() async {
    try {
      await _tokenStorage.deleteToken();
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.setBool('isLoggedIn', false);
    }
  }

  /// Get authorization header
  Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getToken();

    if (token != null && token.isNotEmpty) {
      return {
        'Authorization': 'Bearer $token',
      };
    }

    return null;
  }

  /// Get user profile from API
  Future<UserModel> getProfile() async {
    final headers = await getAuthHeaders();

    if (headers == null) {
      throw ApiException(
        message: 'Not authenticated',
        code: 'NOT_AUTHENTICATED',
      );
    }

    final response = await _apiClient.get(
      ApiConfig.customerProfile,
      headers: headers,
    );

    // Check success first before parsing data
    if (response['success'] == false) {
      throw ApiException(
        message: response['message'] ?? 'Failed to retrieve user details',
        code: response['error_code'] ?? 'PROFILE_FETCH_FAILED',
        errors: response['errors'] as Map<String, dynamic>?,
      );
    }

    // Parse response - the API returns user data inside 'profile' key
    final apiResponse = ApiResponse<UserModel>.fromJson(
      response,
      (data) {
        final profileData = (data as Map<String, dynamic>)['profile'];
        return UserModel.fromJson(profileData as Map<String, dynamic>);
      },
    );

    if (!apiResponse.success || apiResponse.data == null) {
      throw ApiException(
        message: apiResponse.message,
        code: apiResponse.errorCode ?? 'PROFILE_FETCH_FAILED',
      );
    }

    // Update stored user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _userToJson(apiResponse.data!));

    return apiResponse.data!;
  }

  /// Delete the authenticated user account
  Future<void> deleteAccount({required String password}) async {
    final headers = await getAuthHeaders();
    if (headers == null) {
      throw ApiException(
        message: 'Not authenticated',
        code: 'NOT_AUTHENTICATED',
      );
    }

    await _apiClient.delete(
      ApiConfig.authDeleteAccount,
      headers: headers,
      body: {'password': password},
    );

    // Clear all local auth data after the server confirms account deletion.
    await _clearLocalAuth();
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? dateOfBirth,
    String? gender,
    File? avatar,
  }) async {
    final headers = await getAuthHeaders();

    if (headers == null) {
      throw ApiException(
        message: 'Not authenticated',
        code: 'NOT_AUTHENTICATED',
      );
    }

    // Combine first and last name into full name
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

    // If avatar is provided, use multipart request
    if (avatar != null) {
      final response = await _apiClient.postMultipart(
        ApiConfig.customerProfile,
        headers: headers,
        fields: {
          'name': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty)
            'date_of_birth': dateOfBirth,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          '_method': 'PUT',
        },
        files: {
          'avatar': avatar,
        },
      );

      // Check success
      if (response['success'] == false) {
        throw ApiException(
          message: response['message'] ?? 'Failed to update profile',
          code: response['error_code'] ?? 'PROFILE_UPDATE_FAILED',
          errors: response['errors'] as Map<String, dynamic>?,
        );
      }

      // Parse response
      final apiResponse = ApiResponse<UserModel>.fromJson(
        response,
        (data) => UserModel.fromJson(data as Map<String, dynamic>),
      );

      if (!apiResponse.success || apiResponse.data == null) {
        throw ApiException(
          message: apiResponse.message,
          code: apiResponse.errorCode ?? 'PROFILE_UPDATE_FAILED',
        );
      }

      // Update stored user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, _userToJson(apiResponse.data!));

      return apiResponse.data!;
    }

    // Regular PUT request without avatar
    final body = <String, dynamic>{
      'name': fullName,
    };

    // Only add optional fields if they have values
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    }
    if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
      body['date_of_birth'] = dateOfBirth;
    }
    if (gender != null && gender.isNotEmpty) {
      body['gender'] = gender;
    }

    final response = await _apiClient.put(
      ApiConfig.customerProfile,
      headers: headers,
      body: body,
    );

    // Check success first before parsing data
    if (response['success'] == false) {
      throw ApiException(
        message: response['message'] ?? 'Failed to update profile',
        code: response['error_code'] ?? 'PROFILE_UPDATE_FAILED',
        errors: response['errors'] as Map<String, dynamic>?,
      );
    }

    // Parse response
    final apiResponse = ApiResponse<UserModel>.fromJson(
      response,
      (data) => UserModel.fromJson(data as Map<String, dynamic>),
    );

    if (!apiResponse.success || apiResponse.data == null) {
      throw ApiException(
        message: apiResponse.message,
        code: apiResponse.errorCode ?? 'PROFILE_UPDATE_FAILED',
      );
    }

    // Update stored user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _userToJson(apiResponse.data!));

    return apiResponse.data!;
  }
}
