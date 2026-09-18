import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/legal_spain/models/reservation_guest.dart';
import 'package:falconest/features/legal_spain/repositories/legal_spain_repository.dart';
import 'package:falconest/features/legal_spain/widgets/legal_guest_form.dart';

/// Veřejný magický odkaz `/checkin/:token` – host bez účtu vyplní skupinu a podepíše 14+.
class PublicCheckinScreen extends StatefulWidget {
  const PublicCheckinScreen({super.key, required this.token});

  final String token;

  @override
  State<PublicCheckinScreen> createState() => _PublicCheckinScreenState();
}

class _PublicCheckinScreenState extends State<PublicCheckinScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await LegalSpainRepository.publicBootstrap(widget.token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = data;
      if (data == null) _error = 'legal_spain.invalid_link'.tr();
    });
  }

  List<ReservationGuest> get _guests {
    final raw = _data?['guests'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ReservationGuest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
      );
    }
    final name = (_data?['apartment_name'] as String?) ?? '';
    final guestName = (_data?['guest_name'] as String?) ?? '';
    final houseRules = (_data?['house_rules'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('legal_spain.public_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          Text(guestName),
          if (houseRules.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('legal_spain.house_rules'.tr(), style: Theme.of(context).textTheme.titleSmall),
            Text(houseRules),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final g in _guests)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LegalGuestForm(
                  guest: g,
                  onSave: (updated) async {
                    await LegalSpainRepository.publicUpsertGuest(
                      token: widget.token,
                      guest: updated.toUpsertJson(),
                    );
                    await _load();
                  },
                  onSign: (b64) async {
                    var id = g.id;
                    if (id.isEmpty) {
                      final saved = await LegalSpainRepository.publicUpsertGuest(
                        token: widget.token,
                        guest: g.toUpsertJson(),
                      );
                      id = saved.id;
                    }
                    await LegalSpainRepository.publicSubmitSignature(
                      token: widget.token,
                      guestId: id,
                      pngBase64: b64,
                    );
                    await _load();
                  },
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              await LegalSpainRepository.publicUpsertGuest(
                token: widget.token,
                guest: {
                  'first_name': '',
                  'last_name': '',
                },
              );
              await _load();
            },
            icon: const Icon(Icons.person_add_outlined),
            label: Text('legal_spain.add_guest'.tr()),
          ),
        ],
      ),
    );
  }
}
