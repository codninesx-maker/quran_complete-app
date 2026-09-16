class SpecialRecitation {
  final String title;
  final String suraName;
  final String verses;
  final String audioUrl;

  SpecialRecitation({
    required this.title,
    required this.suraName,
    required this.verses,
    required this.audioUrl,
  });
}

class SpecialRecitationsData {
  // Static list for global access
  static List<SpecialRecitation> jenniferGroutRecitations = [
    SpecialRecitation(
      title: "Sura Al-Fatihah",
      suraName: "Al-Fatihah",
      verses: "1-7",
      // Changed to the most stable direct link format
      audioUrl: "https://content.qurancentral.com/media/jennifer-grout/jennifer-grout-fatiha.mp3",
    ),
    SpecialRecitation(
      title: "Sura Al-Baqarah (End Verses)",
      suraName: "Al-Baqarah",
      verses: "285-286",
      audioUrl: "https://server.qurancentral.com/media/jennifer-grout/jennifer-grout-baqarah-285-286.mp3",
    ),
    SpecialRecitation(
      title: "Ayat al-Kursi",
      suraName: "Al-Baqarah",
      verses: "255",
      audioUrl: "https://server8.qurancentral.com/media/jennifer-grout/jennifer-grout-ayat-al-kursi.mp3",
    ),
    SpecialRecitation(
      title: "Sura Al-Ahzab",
      suraName: "Al-Ahzab",
      verses: "35",
      audioUrl: "https://server.qurancentral.com/media/jennifer-grout/jennifer-grout-al-ahzab.mp3",
    ),
    SpecialRecitation(
      title: "Sura Al-Qamar",
      suraName: "Al-Qamar",
      verses: "1-55",
      audioUrl: "https://server.qurancentral.com/media/jennifer-grout/jennifer-grout-al-qamar.mp3",
    ),
    SpecialRecitation(
      title: "Sura Fussilat",
      suraName: "Fussilat",
      verses: "30-36",
      audioUrl: "https://server.qurancentral.com/media/jennifer-grout/jennifer-grout-fussilat.mp3",
    ),
    SpecialRecitation(
      title: "Sura Al-Mulk",
      suraName: "Al-Mulk",
      verses: "1-30",
      audioUrl: "https://server.qurancentral.com/media/jennifer-grout/jennifer-grout-al-mulk.mp3",
    ),
  ];
}