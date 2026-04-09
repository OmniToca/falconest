import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:falconest/core/utils/app_logger.dart';

/// Maximální povolená velikost komprimované fotky v bytech (200 KB).
const int _maxPhotoSizeBytes = 200 * 1024;

/// Služba pro vyfocení a kompresi fotografie bytu.
///
/// Otevře nativní kameru, zkomprimuje snímek na max 200 KB a uloží ho
/// do lokálního adresáře aplikace. Proces komprese používá iterativní
/// snižování kvality, dokud není cílová velikost dosažena.
class PhotoService {
  PhotoService._();

  static final _picker = ImagePicker();

  /// Vyfotí byt kamerou, zkomprimuje na max 200 KB a vrátí cestu k souboru.
  ///
  /// Vrací null při zrušení uživatelem nebo chybě (web, odmítnutí oprávnění).
  static Future<String?> takeAndCompressApartmentPhoto(int taskId) async {
    if (kIsWeb) return null;

    // 1. Otevření nativní kamery – XFile obsahuje cestu k dočasnému souboru
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100, // Původní kvalita – komprese proběhne až níže
    );
    if (pickedFile == null) return null;

    final File sourceFile = File(pickedFile.path);
    if (!await sourceFile.exists()) return null;

    // 2. Cílová cesta v aplikaci – documentsDirectory je vhodný pro uživatelská data
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/task_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${photosDir.path}/task_${taskId}_$timestamp.jpg';

    // 3. Komprese – iterativní snižování kvality, dokud soubor není ≤ 200 KB
    final resultPath = await _compressToMaxSize(
      sourcePath: sourceFile.path,
      targetPath: targetPath,
      maxSizeBytes: _maxPhotoSizeBytes,
    );

    // 4. Smazání původního dočasného souboru z image_picker
    try {
      await sourceFile.delete();
    } catch (e, st) {
      AppLogger.error('PhotoService: smazání dočasného souboru po kompresi selhalo', e, st);
    }

    return resultPath;
  }

  /// Zkomprimuje obrázek na maximálně [maxSizeBytes] bytů.
  ///
  /// ## Detailní průběh komprese (česky):
  ///
  /// **1. Volba kvality JPEG (0–100):**
  /// První pokus začíná na kvalitě 85. JPEG používá ztrátovou kompresi –
  /// algoritmus nahradí podobné pixely průměrem, čímž odstraňuje drobné
  /// detaily, které lidské oko špatně rozlišuje. Kvalita 85 je vizuálně
  /// téměř bez ztráty, ale výrazně zmenší soubor oproti originálu.
  ///
  /// **2. Iterativní snižování kvality:**
  /// Po každé kompresi zkontrolujeme velikost souboru. Je-li > 200 KB,
  /// snížíme kvalitu o krok 10 (85→75→65…) a zkomprimujeme znovu do
  /// stejného cílového souboru. Nižší kvalita = větší „blokování“ barev,
  /// menší soubor, mírná ztráta ostrosti. Iterace končí při kvalitě 20.
  ///
  /// **3. Zmenšení rozlišení (minWidth/minHeight):**
  /// Parametr max 1024 px na delší straně zmenší obrázek při zachování
  /// poměru stran. Mobilní kamera pořizuje 3000×4000 px – pro důkaz
  /// provedeného úklidu stačí menší rozlišení, což výrazně sníží datový objem.
  ///
  /// **4. Fallback:**
  /// I při kvalitě 20 může velmi velká fotka přesáhnout 200 KB. V takovém
  /// případě vrátíme poslední zkomprimovaný soubor (lepší než žádná fotka).
  static Future<String?> _compressToMaxSize({
    required String sourcePath,
    required String targetPath,
    required int maxSizeBytes,
  }) async {
    int quality = 85;
    const int minQuality = 20;
    const int qualityStep = 10;

    // Maximální rozměr na delší straně – zmenšení urychlí kompresi a sníží velikost
    const int maxDimension = 1024;

    while (quality >= minQuality) {
      // Komprese: kvalita řídí JPEG kompresi, minWidth/minHeight mění rozlišení
      final String? resultPath = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        format: CompressFormat.jpeg,
      ).then((f) => f?.path);

      if (resultPath == null) return null;

      final File resultFile = File(resultPath);
      if (!await resultFile.exists()) return null;

      final int size = await resultFile.length();
      if (size <= maxSizeBytes) {
        return resultPath;
      }

      quality -= qualityStep;
    }

    // I při kvalitě 20 může být soubor > 200 KB (velká fotka). Vrátíme ho i tak.
    return targetPath;
  }
}
