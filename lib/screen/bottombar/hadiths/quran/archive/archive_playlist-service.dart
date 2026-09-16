import 'dart:convert';
import 'package:dio/dio.dart';

class ArchivePlaylistService {
  final Dio _dio = Dio();

  num _parseSurahId(String name) {
    // Extracts the leading three digits (e.g., "002")
    final match = RegExp(r'^(\d{3})').firstMatch(name);
    return match != null ? int.parse(match.group(1)!) : -1;
  }

  Future<List<Map<String, dynamic>>> fetchOnlinePlaylist() async {
    const String apiTarget = "https://archive.org/metadata/AlQuranWithBengaliBanglaTranslation-ReciterMisharyRashidAl-Afasy";
    const String streamBase = "https://archive.org/download/AlQuranWithBengaliBanglaTranslation-ReciterMisharyRashidAl-Afasy";

    try {
      final response = await _dio.get(apiTarget);
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> filesList = data['files'] ?? [];

        List<Map<String, dynamic>> surahPlaylist = [];

        for (var file in filesList) {
          final String name = file['name'] ?? "";

          // Only isolate the primary audio formats (.mp3 or .ogg)
          // and filter out XML/Metadata files
          if ((name.endsWith('.mp3') || name.endsWith('.ogg')) && RegExp(r'^\d{3}').hasMatch(name)) {
            num surahId = _parseSurahId(name);

            surahPlaylist.add({
              'sura_id': surahId,
              'file_name': name,
              'stream_url': "$streamBase/${Uri.encodeComponent(name)}",
              'size_bytes': int.tryParse(file['size']?.toString() ?? '0') ?? 0,
            });
          }
        }

        // Sort sequentially 1 to 114
        surahPlaylist.sort((a, b) => a['sura_id'].compareTo(b['sura_id']));
        return surahPlaylist;
      }
    } catch (e) {
      print("Error fetching dynamic archive metadata tracklist: $e");
    }
    return [];
  }
}