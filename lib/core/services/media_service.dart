import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Univerzální služba pro výběr, kompresi a nahrávání médií do Supabase Storage.
///
/// Slouží pro účtenky do Peněženky, budoucí hlášení škod atd.
/// Fotky se komprimují na mobilu před odesláním – šetří serverovou kapacitu a data.
///
/// Multi-tenant struktura: každý tenant má vlastní složku `tenant_id/modul/soubor`.
/// Žádná agentura nesmí nahrávat do společného rootu!
class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Konstanty pro agresivní kompresi – úspora dat a kapacity.
  static const int _imageQuality = 60;
  static const int _maxWidth = 1200;
  static const int _maxHeight = 1200;

  /// Bucket pro všechna média aplikace (účtenky, fotky škod, …).
  static const String _bucket = 'falconest_media';

  /// Vybere obrázek z kamery nebo galerie a zkomprimuje ho přímo při focení/výběru.
  ///
  /// PROČ: Parametry imageQuality, maxWidth, maxHeight zajistí kompresi už na úrovni
  /// ImagePicker – nepotřebujeme další pass přes flutter_image_compress. Úspora paměti.
  ///
  /// Vrací null při zrušení uživatelem, odmítnutí oprávnění nebo na webu.
  Future<File?> pickAndCompressImage({required ImageSource source}) async {
    if (kIsWeb) return null;

    final XFile? xfile = await _picker.pickImage(
      source: source,
      imageQuality: _imageQuality,
      maxWidth: _maxWidth.toDouble(),
      maxHeight: _maxHeight.toDouble(),
    );
    if (xfile == null) return null;

    final File file = File(xfile.path);
    if (!await file.exists()) return null;

    return file;
  }

  /// Nahraje soubor do Supabase Storage v multi-tenant struktuře.
  ///
  /// Cesta: `tenantId/moduleName/uuid.jpg` – striktní oddělení dat agentur.
  ///
  /// PROČ try-catch: Zabraňuje pádu aplikace při chybě při nahrávání na Supabase Storage.
  /// Umožní volajícímu zachytit výjimku, zalogovat ji a zobrazit uživateli smysluplnou hlášku.
  ///
  /// [moduleName] – např. 'receipts' (účtenky), 'damage_reports' (hlášení škod).
  /// Vrací veřejnou URL nahraného souboru, nebo null při chybě.
  Future<String?> uploadMedia(
    File file, {
    required String tenantId,
    required String moduleName,
  }) async {
    if (tenantId.isEmpty || moduleName.isEmpty) return null;

    final fileName = '${_uuid.v4()}.jpg';
    final path = '$tenantId/$moduleName/$fileName';

    try {
      await SupabaseService.client.storage.from(_bucket).upload(
            path,
            file,
          );
      return SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      // PROČ: Zabraňuje pádu aplikace, pokud dojde k chybě při nahrávání na Supabase
      // Storage, a umožní logování. Volající může zachytit výjimku, zalogovat ji
      // a zobrazit uživateli smysluplnou hlášku.
      rethrow;
    }
  }

  /// Nahraje binární data do Supabase Storage – pro web, kde dart:io File neexistuje.
  ///
  /// PROČ: Na webu nemáme přístup k souborovému systému (File z dart:io). file_picker
  /// vrací PlatformFile s bytes (Uint8List) při withData: true. Tato metoda přijímá
  /// přímo bytes a použije Supabase uploadBinary(), což funguje napříč platformami.
  ///
  /// Cesta: `tenantId/moduleName/web_$fileName` – konzistence s mobilním uploadem,
  /// prefix „web_“ odlišuje soubory nahrané z administrace od mobilních.
  ///
  /// [fileName] – původní název souboru (např. letenka.pdf). Bude sanizován pro cestu
  /// (odstranění path separatorů, nebezpečných znaků).
  /// Vrací veřejnou URL nahraného souboru, nebo null při chybě.
  Future<String?> uploadMediaBytes(
    Uint8List bytes, {
    required String fileName,
    required String tenantId,
    required String moduleName,
  }) async {
    if (tenantId.isEmpty || moduleName.isEmpty) return null;
    if (bytes.isEmpty) return null;

    // Sanizace názvu – odstranit path separátory a nebezpečné znaky.
    final safeName = fileName
        .replaceAll(RegExp(r'[/\\]'), '')
        .replaceAll(RegExp(r'[^\w\-\.]'), '_');
    final baseName = safeName.isNotEmpty ? safeName : 'file';
    // UUID zamezí kolizi při opakovaném nahrání stejného souboru.
    final path = '$tenantId/$moduleName/web_${_uuid.v4()}_$baseName';

    try {
      await SupabaseService.client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
          );
      return SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      rethrow;
    }
  }
}
