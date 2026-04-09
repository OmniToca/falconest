import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/repositories/task/supabase_task_insert_repository.dart';
import 'package:falconest/core/repositories/task/task_insert_sanitizer.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/features/worker/utils/worker_photo_annotation_flow.dart';

/// Modul v Supabase Storage pro fotky hlášení závad – cesta tenantId/tasks/uuid.jpg
const _storageModuleTasks = 'tasks';

/// Maximální počet fotek u jednoho hlášení závady (příprava na multi-photo).
const _maxPhotos = 3;

/// Dialog pro nahlášení problému v apartmánu – plná offline podpora.
///
/// Vytvoří nový úkol typu 'issue' v tabulce tasks. Při síťové chybě (offline)
/// uloží payload do MutationQueueService – odešle se po obnovení připojení.
/// Fotky se nahrávají pouze online – při odeslání s fotkami je vyžadováno připojení.
class IssueReporterDialog extends ConsumerStatefulWidget {
  const IssueReporterDialog({
    super.key,
    required this.tenantId,
    required this.apartmentId,
  });

  final String tenantId;
  final String apartmentId;

  @override
  ConsumerState<IssueReporterDialog> createState() => _IssueReporterDialogState();
}

class _IssueReporterDialogState extends ConsumerState<IssueReporterDialog> {
  final _controller = TextEditingController();
  final List<File> _photoFiles = [];
  bool _submitting = false;

  /// Speech-to-text – lokální přepis hlasu (offline na iOS/Android).
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  /// Text v poli před zahájením nahrávání – přepis se k němu připojí.
  String _baseTextBeforeListening = '';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _speechToText
          .initialize(
            onError: (error) {
              if (!mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'common.generic_error_user_friendly'.tr(),
                    ),
                    backgroundColor: Colors.orange.shade700,
                  ),
                );
              });
            },
          )
          .then((available) {
            if (!mounted) return;
            setState(() {
              _speechAvailable = available;
              _isListening = false;
            });
            if (!available) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('worker.issue_reporter_mic_not_available'.tr()),
                    backgroundColor: Colors.orange.shade700,
                  ),
                );
              });
            }
          })
          .catchError((e) {
            if (!mounted) return;
            setState(() {
              _speechAvailable = false;
              _isListening = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'common.generic_error_user_friendly'.tr(),
                  ),
                  backgroundColor: Colors.orange.shade700,
                ),
              );
            });
          });
    }
  }

  @override
  void dispose() {
    if (_isListening) {
      _speechToText.stop();
    }
    _controller.dispose();
    super.dispose();
  }

  /// Zahájí nebo ukončí nahrávání hlasu. Přepis se zapisuje do TextField.
  Future<void> _toggleListening() async {
    if (kIsWeb || !_speechAvailable) return;

    if (_isListening) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechToText.isAvailable) {
      try {
        final granted = await _speechToText.initialize(
          onError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'common.generic_error_user_friendly'.tr(),
                ),
                backgroundColor: Colors.orange.shade700,
              ),
            );
          },
        );
        if (!mounted) return;
        setState(() {
          _speechAvailable = granted;
          _isListening = false;
        });
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('worker.issue_reporter_mic_not_available'.tr()),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _speechAvailable = false;
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.generic_error_user_friendly'.tr(),
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }
    }

    _baseTextBeforeListening = _controller.text;
    final prefix = _baseTextBeforeListening.trim();
    final separator = prefix.isEmpty ? '' : ' ';

    final started = await _speechToText.listen(
      onResult: (result) {
        if (!mounted) return;
        final full = prefix.isEmpty
            ? result.recognizedWords
            : prefix + separator + result.recognizedWords;
        _controller.text = full;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(partialResults: true),
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.issue_reporter_mic_permission_denied'.tr()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
    if (mounted) setState(() => _isListening = started);
  }

  Future<void> _addPhoto() async {
    if (kIsWeb || _photoFiles.length >= _maxPhotos) return;
    final file = await pickWorkerPhotoWithAnnotation(
      context,
      source: ImageSource.camera,
    );
    if (file != null && mounted) {
      setState(() => _photoFiles.add(file));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photoFiles.removeAt(index));
  }

  /// Tlačítko mikrofonu s pulsující animací při nahrávání.
  Widget _buildMicButton() {
    final tooltip = _isListening
        ? 'worker.issue_reporter_mic_stop'.tr()
        : 'worker.issue_reporter_mic_start'.tr();
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: _isListening
            ? _PulsingMicIcon(color: Colors.red.shade700)
            : Icon(
                Icons.mic,
                color: _speechAvailable ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
        onPressed: _speechAvailable ? _toggleListening : null,
      ),
    );
  }

  Future<void> _submit() async {
    final desc = _controller.text.trim();
    if (desc.isEmpty) return;

    setState(() => _submitting = true);

    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (profileId == null || profileId.isEmpty) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.issue_reporter_error'.tr(namedArgs: {'error': 'Missing profile'})),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    final now = DateTime.now().toUtc();
    final dueIso = now.toIso8601String();

    // KROK 1: Nahrání fotek na Supabase Storage (pouze online).
    // PROČ: Fotky vyžadují síť. Při offline zobrazíme upozornění a neukládáme s fotkami.
    List<String> mediaUrls = [];
    if (_photoFiles.isNotEmpty) {
      try {
        for (final file in _photoFiles) {
          final url = await MediaService.instance.uploadMedia(
            file,
            tenantId: widget.tenantId,
            moduleName: _storageModuleTasks,
          );
          if (url != null && url.isNotEmpty) mediaUrls.add(url);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _submitting = false);
        final msg = isNetworkError(e)
            ? 'worker.issue_reporter_photo_required_online'.tr()
            : 'worker.issue_reporter_photo_upload_error'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
        );
        return;
      }
      if (mediaUrls.isEmpty && mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.issue_reporter_photo_upload_error'.tr()),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    }

    // KROK 2: Zápis úkolu do Supabase. Při síťové chybě (offline) uložíme do fronty.
    final payload = <String, dynamic>{
      'id': const Uuid().v4(),
      'tenant_id': widget.tenantId,
      'apartment_id': widget.apartmentId,
      'reference_number': generateTaskRef(),
      'task_type': 'issue',
      'status': 'pending',
      'title': 'worker.issue_reporter_task_title'.tr(),
      'description': desc,
      'created_by': profileId,
      'due_date': dueIso,
      'scheduled_start': dueIso,
      'local_updated_at': dueIso,
      'metadata': <String, dynamic>{},
      'media_urls': mediaUrls,
    };

    try {
      await SupabaseTaskInsertRepository.createTask(payload); // návratové id zatím nepotřebujeme

      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.issue_reporter_recorded'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final errorMsg = 'Postgrest: ${e.message} [code: ${e.code}${e.details != null ? ", details: ${e.details}" : ""}]';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      // Offline fallback – uložíme do fronty, odešle se po obnovení sítě.
      if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
        await MutationQueueService.instance.enqueueMutation(
          table: 'tasks',
          action: 'OFFLINE_ISSUE_TASK',
          payload: sanitizeTaskInsertPayload(Map<String, dynamic>.from(payload)),
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.issue_reporter_queued_offline'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.report_problem_outlined, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Text('worker.issue_reporter_title'.tr()),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'worker.issue_reporter_hint'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: kIsWeb
                    ? null
                    : _buildMicButton(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: kIsWeb || _photoFiles.length >= _maxPhotos
                  ? null
                  : _addPhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text('worker.issue_reporter_add_photo'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_photoFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoFiles.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _photoFiles[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton.filled(
                            iconSize: 18,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(28, 28),
                            ),
                            icon: const Icon(Icons.close),
                            onPressed: () => _removePhoto(index),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text('worker.issue_reporter_cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  final desc = _controller.text.trim();
                  if (desc.isEmpty) return;
                  _submit();
                },
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('worker.issue_reporter_submit'.tr()),
        ),
      ],
    );
  }
}

/// Ikona mikrofonu s pulsující animací – signalizuje aktivní nahrávání.
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon({required this.color});

  final Color color;

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(Icons.mic, color: widget.color, size: 24),
    );
  }
}
