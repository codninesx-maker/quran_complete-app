import 'dart:core'; // Provides Uri encoding utilities (included by default, but good for clarity)

class ArchiveAudioHelper {
  static const String baseUrl = "https://archive.org/download/AlQuranWithBengaliBanglaTranslation-ReciterMisharyRashidAl-Afasy";

  // 📜 Accurate English translation maps matching the Archive.org file names exactly
  static const Map<int, String> _englishNamesPattern = {
    1: "Al-Fatihah ( The Opening )",
    2: "Al-Baqarah ( The Cow )",
    3: "Al-Imran ( The Family of Imran )",
    4: "An-Nisa ( The Women )",
    5: "Al-Maidah ( The Table spread with Food )",
    6: "Al-An'am ( The Cattle )",
    7: "Al-A'raf ( The Heights )",
    8: "Al-Anfal ( The Spoils of War )",
    9: "At-Tawbah ( The Repentance )",
    10: "Yunus ( Jonah )",
    11: "Hud ( Hud )",
    12: "Yusuf ( Joseph )",
    13: "Ar-Ra'd ( The Thunder )",
    14: "Ibrahim ( Abraham )",
    15: "Al-Hijr ( The Rocky Tract )",
    16: "An-Nahl ( The Bee )",
    17: "Al-Isra ( The Night Journey )",
    18: "Al-Kahf ( The Cave )",
    19: "Maryam ( Mary )",
    20: "Taha",
    21: "Al-Anbiya ( The Prophets )",
    22: "Al-Hajj ( The Pilgrimage )",
    23: "Al-Mu'minun ( The Believers )",
    24: "An-Nur ( The Light )",
    25: "Al-Furqan ( The Criterion )",
    26: "Ash-Shu'ara ( The Poets )",
    27: "An-Naml ( The Ant )",
    28: "Al-Qasas ( The Stories )",
    29: "Al-Ankabut ( The Spider )",
    30: "Ar-Rum ( The Romans )",
    31: "Luqman",
    32: "As-Sajdah ( The Prostration )",
    33: "Al-Ahzab ( The Combined Forces )",
    34: "Saba ( Sheba )",
    35: "Fatir ( The Originator )",
    36: "Ya-Sin",
    37: "As-Saffat ( Those Ranges in Ranks )",
    38: "Sad",
    39: "Az-Zumar ( The Groups )",
    40: "Ghafir ( The Forgiver )",
    41: "Fussilat ( Explained in Detail )",
    42: "Ash-Shura ( The Consultation )",
    43: "Az-Zukhruf ( The Gold Adornments )",
    44: "Ad-Dukhan ( The Smoke )",
    45: "Al-Jathiyah ( The Kneeling )",
    46: "Al-Ahqaf ( The Curved Sand-hills )",
    47: "Muhammad",
    48: "Al-Fath ( The Victory )",
    49: "Al-Hujurat ( The Dwellings )",
    50: "Qaf",
    51: "Adh-Dhariyat ( The Winds that Scatter )",
    52: "At-Tur ( The Mount )",
    53: "An-Najm ( The Star )",
    54: "Al-Qamar ( The Moon )",
    55: "Ar-Rahman ( The Most Gracious )",
    56: "Al-Waqi'ah ( The Event )",
    57: "Al-Hadid ( The Iron )",
    58: "Al-Mujadila ( The Pleading Woman )",
    59: "Al-Hashr ( The Gathering )",
    60: "Al-Mumtahanah ( The Woman to be Examined )",
    61: "As-Saff ( The Row )",
    62: "Al-Jumu'ah ( Friday )",
    63: "Al-Munafiqun ( The Hypocrites )",
    64: "At-Taghabun ( The Mutual Loss and Gain )",
    65: "At-Talaq ( The Divorce )",
    66: "At-Tahrim ( The Prohibition )",
    67: "Al-Mulk ( The Dominion )",
    68: "Al-Qalam ( The Pen )",
    69: "Al-Haqqah ( The Inevitable Reality )",
    70: "Al-Ma'arij ( The Ways of Ascent )",
    71: "Nuh ( Noah )",
    72: "Al-Jinn ( The Jinn )",
    73: "Al-Muzzammil ( The Enwrapped One )",
    74: "Al-Muddaththir ( The Cloaked One )",
    75: "Al-Qiyamah ( The Resurrection )",
    76: "Al-Insan ( Man )",
    77: "Al-Mursalat ( Those Sent Forth )",
    78: "An-Naba ( The Great News )",
    79: "An-Nazi'at ( Those Who Pull Out )",
    80: "Abasa ( He Frowned )",
    81: "At-Takwir ( The Overthrowing )",
    82: "Al-Infitar ( The Cleaving Asunder )",
    83: "Al-Mutaffifin ( Those Who Deal in Fraud )",
    84: "Al-Inshiqaq ( The Splitting Asunder )",
    85: "Al-Buruj ( The Big Stars )",
    86: "At-Tariq ( The Night-Comer )",
    87: "Al-A'la ( The Most High )",
    88: "Al-Ghashiyah ( The Overwhelming )",
    89: "Al-Fajr ( The Break of Day )",
    90: "Al-Balad ( The City )",
    91: "Ash-Shams ( The Sun )",
    92: "Al-Layl ( The Night )",
    93: "Ad-Duha ( The Forenoon Aftergrowth )",
    94: "Ash-Sharh ( The Opening Forth )",
    95: "At-Tin ( The Fig )",
    96: "Al-Alaq ( The Clot )",
    97: "Al-Qadr ( The Power )",
    98: "Al-Bayyinah ( The Clear Evidence )",
    99: "Az-Zalzalah ( The Earthquake )",
    100: "Al-Adiyat ( Those That Run )",
    101: "Al-Qari'ah ( The Striking Hour )",
    102: "At-Takathur ( The Piling Up )",
    103: "Al-Asr ( The Time )",
    104: "Al-Humazah ( The Slanderer )",
    105: "Al-Fil ( The Elephant )",
    106: "Quraysh",
    107: "Al-Ma'un ( The Small Kindnesses )",
    108: "Al-Kauthar ( A River in Paradise )",
    109: "Al-Kafrun ( The Disbelievers )",
    110: "An-Nasr ( The Help )",
    111: "Al-Masad ( The Palm Fiber )",
    112: "Al-Ikhlas ( The Purity )",
    113: "Al-Falaq ( The Daybreak )",
    114: "An-Nas ( Mankind )",
  };

  // 📜 Accurate Arabic script names matching Archive's specific naming metadata
  static const Map<int, String> _arabicNamesPattern = {
    1: "الفاتحة", 2: "البقرة", 3: "آل عمران", 4: "النساء", 5: "المائدة",
    6: "الأنعام", 7: "الأعراف", 8: "الأنفال", 9: "التوبة", 10: "يونس",
    11: "هود", 12: "يوسف", 13: "الرعد", 14: "إبراهيم", 15: "الحجر",
    16: "النحل", 17: "الإسراء", 18: "الكهف", 19: "مريم", 20: "طه",
    21: "الأنبياء", 22: "الحج", 23: "المؤمنون", 24: "النور", 25: "الفرقان",
    26: "الشعراء", 27: "النمل", 28: "القصص", 29: "العنكبوت", 30: "الروم",
    31: "لقمان", 32: "السجدة", 33: "الأحزاب", 34: "سبأ", 35: "فاطر",
    36: "يس", 37: "الصافات", 38: "ص", 39: "الزمر", 40: "غافر",
    41: "فصلت", 42: "الشورى", 43: "الزخرف", 44: "الدخان", 45: "الجاثية",
    46: "الأحقاف", 47: "محمد", 48: "الفتح", 49: "الحجرات", 50: "ق",
    51: "الذاريات", 52: "الطور", 53: "النجم", 54: "القمر", 55: "الرحمن",
    56: "الواقعة", 57: "الحديد", 58: "المجادلة", 59: "الحشر", 60: "الممتحنة",
    61: "الصف", 62: "الجمعة", 63: "المنافقون", 64: "التغابن", 65: "الطلاق",
    66: "التحريم", 67: "الملك", 68: "القلم", 69: "الحاقة", 70: "المعارج",
    71: "نوح", 72: "الجن", 73: "المزمل", 74: "المدثر", 75: "القيامة",
    76: "الإنسان", 77: "المرسلات", 78: "النبأ", 79: "النازعات", 80: "عبس",
    81: "التكوير", 82: "الانفطار", 83: "المطففين", 84: "الانشقاق", 85: "البروج",
    86: "الطارق", 87: "الأعلى", 88: "الغاشية", 89: "الفجر", 90: "البلد",
    91: "الشمس", 92: "الليل", 93: "الضحى", 94: "الشرح", 95: "التين",
    96: "العلق", 97: "القدر", 98: "البينة", 99: "الزلزلة", 100: "العاديات",
    101: "القارعة", 102: "التكاثر", 103: "العصر", 104: "الهمزة", 105: "الفيل",
    106: "قريش", 107: "الماعون", 108: "الكوثر", 109: "الكافرون", 110: "النصر",
    111: "المسد", 112: "الإخلاص", 113: "الفلق", 114: "الناس"
  };

  /// Dynamic URL builder that pieces together 114 filenames programmatically
  static String getStreamingUrl(int surahId) {
    if (surahId < 1 || surahId > 114) return "";

    final String prefix = surahId.toString().padLeft(3, '0');
    final String englishPart = _englishNamesPattern[surahId] ?? "";
    final String arabicPart = _arabicNamesPattern[surahId] ?? "";

    // Reconstructs the exact file layout string: "006 - Al-An'am ( The Cattle ) - سورة الأنعام.ogg"
    final String rawFileName = "$prefix - $englishPart - سورة $arabicPart.ogg";

    final encodedFile = Uri.encodeComponent(rawFileName);
    return "$baseUrl/$encodedFile";
  }

  /// Expose safe synthesized titles to harmonise UI rows without map lookups
  static String getSynthesizedFileName(int surahId) {
    if (surahId < 1 || surahId > 114) return "";
    final String prefix = surahId.toString().padLeft(3, '0');
    final String englishPart = _englishNamesPattern[surahId] ?? "";
    final String arabicPart = _arabicNamesPattern[surahId] ?? "";
    return "$prefix - $englishPart - سورة $arabicPart.ogg";
  }
}