import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/utils/phone_normalizer.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

/// Client-side only auth repository - NO server calls
/// All data stored locally using SecureStorage and AppPreferences
/// Anonymous profiles with user-entered values
class ClientAuthRepository implements AuthRepository {
  ClientAuthRepository({
    secureStorageService,
    appPreferences,
  })  : _secureStorage = secureStorageService ?? SecureStorageServiceImpl(
          const FlutterSecureStorage(),
        ),
        _appPreferences = appPreferences ?? AppPreferences();

  final SecureStorageService _secureStorage;
  final AppPreferences _appPreferences;

  @override
  AppUser? get currentUser => _mapUser(_secureStorage.getUserId());

  @override
  Stream<AppUser?> authStateChanges() {
    final controller = StreamController<AppUser?>.broadcast();
    _secureStorage.addListener(() {
      controller.add(_mapUser(_secureStorage.getUserId()));
    });
    return controller.stream;
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return await signInAnonymously();
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    // Check if user has existing anonymous profile
    final existingUserId = _secureStorage.getUserId();
    
    if (existingUserId != null && existingUserId.isNotEmpty) {
      // User already has an anonymous profile - return success
      return const AuthSuccess();
    }
    
    // Generate new anonymous user ID
    final newUserId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
    
    // Store the anonymous user ID locally
    await _secureStorage.setUserId(newUserId);
    await _secureStorage.setDisplayName('');
    await _secureStorage.setPhone('');
    await _secureStorage.setIsAnonymous(true);
    await _secureStorage.setAvatarUrl('');
    await _secureStorage.setBio('');
    await _secureStorage.setPresence('offline');
    await _secureStorage.setLastSeenAt(DateTime.now().toIso8601String());
    await _secureStorage.setVerificationStatus('unverified');
    await _secureStorage.setSyncEnabled(true);
    await _secureStorage.setVerifiedAt(null);
    await _secureStorage.setDeviceModel('');
    await _secureStorage.setDeviceOs('');
    await _secureStorage.setDeviceManufacturer('');
    await _secureStorage.setDeviceIp('');
    await _secureStorage.setDeviceLocale('');
    await _secureStorage.setAppVersion('');
    
    // Store empty profile in preferences
    await _appPreferences.saveProfile({
      'id': newUserId,
      'displayName': '',
      'phone': '',
      'avatarUrl': '',
      'isAnonymous': true,
      'bio': '',
      'presence': 'offline',
      'lastSeenAt': DateTime.now().toIso8601String(),
      'verificationStatus': 'unverified',
      'syncEnabled': true,
      'verifiedAt': '',
      'deviceModel': '',
      'deviceOs': '',
      'deviceManufacturer': '',
      'deviceIp': '',
      'deviceLocale': '',
      'appVersion': '',
    });
    
    return const AuthSuccess();
  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // For client-side, signUp is same as signIn (anonymous)
    return await signInAnonymously();
  }

  @override
  Future<String?> linkGuestAccount({
    required String email,
    required String password,
  }) async {
    return null;
  }

  @override
  Future<String?> deleteAccount() async {
    await signOut();
    return null;
  }

  @override
  Future<void> signOut() async {
    await _secureStorage.clearAll();
    await _appPreferences.clear();
  }

  @override
  Future<bool> hasPersistedSession() async {
    final userId = _secureStorage.getUserId();
    return userId != null && userId.isNotEmpty;
  }

  @override
  Future<bool> refreshSessionIfAlive() async {
    // For client-side, just check if user ID exists
    return _secureStorage.getUserId() != null;
  }

  @override
  Future<UserProfile> fetchOwnProfile() async {
    final userId = _secureStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('Not authenticated.');
    }
    
    // Retrieve profile from local storage
    final profileData = _appPreferences.getProfile();
    if (profileData != null && profileData['id'] != null) {
      return UserProfile(
        id: profileData['id'] ?? '',
        displayName: profileData['displayName'] ?? '',
        phone: profileData['phone'] ?? '',
        isAnonymous: profileData['isAnonymous'] == true,
        avatarUrl: profileData['avatarUrl'] ?? '',
        presence: profileData['presence'] ?? 'offline',
        lastSeenAt: profileData['lastSeenAt'] != null 
            ? DateTime.parse(profileData['lastSeenAt'])
            : DateTime.now(),
        verificationStatus: profileData['verificationStatus'] ?? 'unverified',
        syncEnabled: profileData['syncEnabled'] ?? true,
        verifiedAt: profileData['verifiedAt'] != null 
            ? DateTime.parse(profileData['verifiedAt'])
            : null,
        deviceModel: profileData['deviceModel'] ?? '',
        deviceOs: profileData['deviceOs'] ?? '',
        deviceManufacturer: profileData['deviceManufacturer'] ?? '',
        deviceIp: profileData['deviceIp'] ?? '',
        deviceLocale: profileData['deviceLocale'] ?? '',
        appVersion: profileData['appVersion'] ?? '',
      );
    }
    
    // Return default anonymous profile
    return UserProfile(
      id: _secureStorage.getUserId() ?? '',
      displayName: '',
      phone: '',
      isAnonymous: true,
      avatarUrl: '',
      presence: 'offline',
      lastSeenAt: DateTime.now(),
      verificationStatus: 'unverified',
      syncEnabled: true,
      verifiedAt: null,
      deviceModel: '',
      deviceOs: '',
      deviceManufacturer: '',
      deviceIp: '',
      deviceLocale: '',
      appVersion: '',
    );
  }

  @override
  Future<void> updateOwnProfile({
    String? displayName,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    final userId = _secureStorage.getUserId();
    if (userId == null || userId.isEmpty) throw StateError('Not authenticated.');
    
    // Update in secure storage
    if (displayName != null) await _secureStorage.setDisplayName(displayName);
    if (phone != null) await _secureStorage.setPhone(phone);
    if (avatarUrl != null) await _secureStorage.setAvatarUrl(avatarUrl);
    if (bio != null) await _secureStorage.setBio(bio);
    
    // Update in preferences
    await _appPreferences.saveProfile({
      'id': _secureStorage.getUserId(),
      'displayName': displayName ?? _secureStorage.getDisplayName(),
      'phone': phone ?? _secureStorage.getPhone(),
      'avatarUrl': avatarUrl ?? _secureStorage.getAvatarUrl(),
      'bio': bio ?? _secureStorage.getBio(),
      'isAnonymous': true,
      'lastSeenAt': DateTime.now().toIso8601String(),
      'verificationStatus': 'unverified',
      'syncEnabled': true,
      'verifiedAt': '',
      'deviceModel': _secureStorage.getDeviceModel(),
      'deviceOs': _secureStorage.getDeviceOs(),
      'deviceManufacturer': _secureStorage.getDeviceManufacturer(),
      'deviceIp': _secureStorage.getDeviceIp(),
      'deviceLocale': _secureStorage.getDeviceLocale(),
      'appVersion': _secureStorage.getAppVersion(),
    });
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String deviceName,
    String? pushToken,
    String? deviceModel,
    String? deviceOs,
    String? deviceManufacturer,
    String? deviceIp,
    String? deviceLocale,
    String? appVersion,
  }) async {
    // Client-side: just store device info locally
    await _secureStorage.setDeviceInfo(
      deviceId: deviceId,
      platform: platform,
      deviceName: deviceName,
      pushToken: pushToken,
      deviceModel: deviceModel,
      deviceOs: deviceOs,
      deviceManufacturer: deviceManufacturer,
      deviceIp: deviceIp,
      deviceLocale: deviceLocale,
      appVersion: appVersion,
    );
  }

  @override
  Future<void> updatePresence(String status) async {
    // Client-side: just update local storage
    await _secureStorage.setPresence(status);
  }

  static AppUser? _mapUser(dynamic userId) {
    if (userId == null || userId.isEmpty) return null;
    return AppUser(
      id: userId,
      email: '',
    );
  }
}