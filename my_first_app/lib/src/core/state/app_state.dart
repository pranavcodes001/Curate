import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  AppState._();

  static final AppState instance = AppState._();

  static const _keyOnboarding = 'onboarding_complete_v1';
  static const _keyInterests = 'user_interests_v1';
  static const _keyName = 'user_name_v1';
  static const _keyPhone = 'user_phone_v1';
  static const _keyExtraEmail = 'user_extra_email_v1';
  static const _keyDarkMode = 'user_dark_mode_v1';

  late final SharedPreferences _prefs;

  final ValueNotifier<bool> onboardingComplete = ValueNotifier<bool>(false);
  final ValueNotifier<List<String>> interests = ValueNotifier<List<String>>([]);
  final ValueNotifier<String> name = ValueNotifier<String>('');
  final ValueNotifier<String> phone = ValueNotifier<String>('');
  final ValueNotifier<String> extraEmail = ValueNotifier<String>('');
  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
  final ValueNotifier<Set<String>> topStoryIds = ValueNotifier<Set<String>>({});
  final ValueNotifier<int> savedThreadsRefreshTrigger = ValueNotifier<int>(0);
  final ValueNotifier<int> feedResetTrigger = ValueNotifier<int>(0);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    onboardingComplete.value = _prefs.getBool(_keyOnboarding) ?? false;
    interests.value = _prefs.getStringList(_keyInterests) ?? [];
    name.value = _prefs.getString(_keyName) ?? '';
    phone.value = _prefs.getString(_keyPhone) ?? '';
    extraEmail.value = _prefs.getString(_keyExtraEmail) ?? '';
    isDarkMode.value = _prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<void> updateProfile({
    String? nameVal,
    String? phoneVal,
    String? emailVal,
  }) async {
    if (nameVal != null) {
      name.value = nameVal;
      await _prefs.setString(_keyName, nameVal);
    }
    if (phoneVal != null) {
      phone.value = phoneVal;
      await _prefs.setString(_keyPhone, phoneVal);
    }
    if (emailVal != null) {
      extraEmail.value = emailVal;
      await _prefs.setString(_keyExtraEmail, emailVal);
    }
  }

  Future<void> toggleDarkMode(bool val) async {
    isDarkMode.value = val;
    await _prefs.setBool(_keyDarkMode, val);
  }

  Future<void> completeOnboarding(List<String> selected) async {
    interests.value = selected;
    onboardingComplete.value = true;
    await _prefs.setBool(_keyOnboarding, true);
    await _prefs.setStringList(_keyInterests, selected);
  }

  Future<void> resetOnboarding() async {
    onboardingComplete.value = false;
    interests.value = [];
    name.value = '';
    phone.value = '';
    extraEmail.value = '';
    await _prefs.clear();
  }

  Future<void> clearUserProfile() async {
    name.value = '';
    phone.value = '';
    extraEmail.value = '';
    interests.value = [];
    onboardingComplete.value = false;
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyPhone);
    await _prefs.remove(_keyExtraEmail);
    await _prefs.remove(_keyInterests);
    await _prefs.remove(_keyOnboarding);
  }
}
