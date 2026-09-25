/// Utility functions for handling avatar images
library;

import '../config/api_config.dart';
import 'network_helper.dart';

/// Avatar ID list - matches backend ADVENTURER_AVATAR_IDS
const List<String> ADVENTURER_AVATAR_IDS = [
  'adventurer-1787066874693',
  'adventurer-1787066893641',
  'adventurer-1787066897643',
  'adventurer-1787066901609',
  'adventurer-1787066904754',
  'adventurer-1787066907832',
  'adventurer-1787066911577',
  'adventurer-1787066914937',
  'adventurer-1787066918306',
  'adventurer-1787066922497',
  'adventurer-1787066926169',
  'adventurer-1787066929218',
  'adventurer-1787066934106',
  'adventurer-1787066937610',
  'adventurer-1787066942696',
  'adventurer-1787066946714',
  'adventurer-1787066949874',
  'adventurer-1787066955258',
  'adventurer-1787066958801',
  'adventurer-1787066964514',
];

const String DEFAULT_AVATAR_ID = 'adventurer-1787066874693';

/// Gets the base URL for API calls
String _getBaseUrl() {
  String baseUrl = ApiConfig.getApiBaseUrl();
  // Resolve localhost for Android emulator
  baseUrl = NetworkHelper.resolveLocalhost(baseUrl);
  return baseUrl;
}

/// Converts an avatar ID to a loadable image URL
/// 
/// Avatar files are served from the backend at /avatars/{avatarId}.svg
/// If the ID is invalid or null, returns the default avatar URL
String getAvatarUrl(String? avatarId) {
  final id = avatarId ?? DEFAULT_AVATAR_ID;
  
  // Validate that the ID is a known avatar ID
  if (!ADVENTURER_AVATAR_IDS.contains(id)) {
    return getAvatarUrl(DEFAULT_AVATAR_ID);
  }
  
  // Return the full URL to the avatar SVG file
  return '${_getBaseUrl()}/avatars/$id.svg';
}

/// Checks if an avatar ID is valid
bool isValidAvatarId(String? avatarId) {
  return avatarId != null && ADVENTURER_AVATAR_IDS.contains(avatarId);
}

/// Gets a readable label for an avatar ID
String getAvatarLabel(String? avatarId) {
  if (avatarId == null) return 'Avatar padrão';
  
  final index = ADVENTURER_AVATAR_IDS.indexOf(avatarId);
  if (index == -1) return 'Avatar padrão';
  
  return 'Avatar Adventurer ${index + 1}';
}
