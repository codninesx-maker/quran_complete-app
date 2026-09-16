import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuranRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _saveToLocal(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<List<Map<String, dynamic>>?> _readFromLocal(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString(key);
    if (cachedData != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(cachedData));
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAyas(int suraId) async {
    final String cacheKey = 'cached_ayas_$suraId';
    try {
      final response = await _client
          .from('aya')
          .select('*')
          .eq('sura_id', suraId)
          .order('aya_id', ascending: true);

      final List<Map<String, dynamic>> ayas = List<Map<String, dynamic>>.from(response);
      if (ayas.isNotEmpty) await _saveToLocal(cacheKey, ayas);
      return ayas;
    } catch (e) {
      final cached = await _readFromLocal(cacheKey);
      if (cached != null) {
        cached.sort((a, b) => (a['aya_id'] as int).compareTo(b['aya_id'] as int));
        return cached;
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllSuras() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'cached_suras_list';

    try {
      // 1. Check local cache first
      final String? cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        debugPrint("Suras loaded from offline cache");
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return List<Map<String, dynamic>>.from(decoded);
      }

      // 2. If no cache, fetch from Supabase
      debugPrint("No cache found. Fetching Suras from Supabase...");
      final response = await _client
          .from('sura')
          .select('*')
          .order('id', ascending: true);

      final List<Map<String, dynamic>> suras = List<Map<String, dynamic>>.from(response);

      // 3. Save to cache for next time
      if (suras.isNotEmpty) {
        await prefs.setString(cacheKey, jsonEncode(suras));
      }

      return suras;
    } catch (e) {
      debugPrint("Repo Error in getAllSuras: $e");
      // If fetch fails and no cache exists, return empty list
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAyasBySura(int suraId) async {
    final String cacheKey = 'cached_ayas_$suraId';
    try {
      final data = await _client
          .from('aya')
          .select('*')
          .eq('sura_id', suraId) // Ensure column name matches your SQL (sura_id)
          .order('aya_id', ascending: true);

      final result = List<Map<String, dynamic>>.from(data);
      await _saveToLocal(cacheKey, result);
      return result;
    } catch (e) {
      final localData = await _readFromLocal(cacheKey);
      if (localData != null) return localData;
      throw Exception('Offline: No cached verses');
    }
  }


  Future<List<Map<String, dynamic>>> searchInBangla(String query) async {
    try {
      final data = await _client
          .from('aya')
          .select('sura_id, aya_id, arabic_text, bangla_translation, aya_number')
          .ilike('bangla_translation', '%$query%')
          .limit(30)
          .order('sura_id', ascending: true)
          .order('aya_id', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Search Error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHadithsByCategory(int categoryId, int from, int to) async {
    return await _client
        .from('hadiths')
        .select('*')
        .eq('category_id', categoryId) // Filter by category
        .order('hadith_number', ascending: true)
        .range(from, to);
  }

  Future<List<Map<String, dynamic>>> getHadithsPaged(int from, int to) async {
    try {
      final data = await _client
          .from('hadiths')
          .select('*')
          .order('hadith_number', ascending: true)
          .range(from, to);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Only fallback to cache for the first page to keep it simple
      if (from == 0) {
        return await _readFromLocal('cached_hadiths_first_page') ?? [];
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDuas() async {
    try {
      final data = await _client
          .from('duas')
          .select('*')
          .order('id', ascending: true);

      final result = List<Map<String, dynamic>>.from(data);
      await _saveToLocal('cached_duas', result);
      return result;
    } catch (e) {
      final localData = await _readFromLocal('cached_duas');
      if (localData != null) return localData;
      throw Exception('Failed to load Duas offline.');
    }
  }

  /// Fetches Allah Names with Offline Fallback
  Future<List<Map<String, dynamic>>> getAllahNames() async {
    try {
      final data = await _client
          .from('allah')
          .select('*')
          .order('name_number', ascending: true);

      final result = List<Map<String, dynamic>>.from(data);
      await _saveToLocal('cached_allah_names', result);
      return result;
    } catch (e) {
      final localData = await _readFromLocal('cached_allah_names');
      if (localData != null) return localData;
      throw Exception('Failed to load names offline.');
    }
  }
}