import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/mc.dart';
import '../models/saved_place.dart';
import '../providers/saved_places_provider.dart';
import '../services/saved_places_service.dart';
import '../../../core/network/friendly_error.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              McNavHeader(
                title: 'Saved places',
                fallback: '/account',
                trailing: GestureDetector(
                  onTap: () => _openForm(context, ref),
                  child: const Ico('plus', size: 24, color: Brand.blue),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: places.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load your saved places.',
                            style: tw(FontWeight.w700, 14, Brand.sub)),
                        const SizedBox(height: 10),
                        McGhostButton(
                          'Retry',
                          full: false,
                          onTap: () => ref.invalidate(savedPlacesProvider),
                        ),
                      ],
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? _EmptyState(onAdd: () => _openForm(context, ref))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _PlaceCard(
                            place: list[i],
                            onEdit: () => _openForm(context, ref, existing: list[i]),
                            onDelete: () => _confirmDelete(context, ref, list[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {SavedPlace? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _SavedPlaceForm(existing: existing),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SavedPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this place?'),
        content: Text('"${place.label}" will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: tw(FontWeight.w700, 14, Brand.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Remove', style: tw(FontWeight.w800, 14, Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(savedPlacesServiceProvider).delete(place.id);
      ref.invalidate(savedPlacesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Ico('heart', size: 40, color: Brand.faint),
            const SizedBox(height: 14),
            Text('No saved places yet', style: tw(FontWeight.w800, 16)),
            const SizedBox(height: 6),
            Text('Add Home, Work, or another address for faster booking.',
                textAlign: TextAlign.center,
                style: tw(FontWeight.w600, 13, Brand.sub)),
            const SizedBox(height: 18),
            McButton('Add a place', icon: 'plus', full: false, onTap: onAdd),
          ],
        ),
      );
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onEdit, required this.onDelete});
  final SavedPlace place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onEdit,
        child: McCard(
          padding: 14,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Brand.fill, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Ico(
                    place.label.toLowerCase() == 'home' ? 'home' : 'pin',
                    size: 22,
                    color: Brand.sub,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.label, style: tw(FontWeight.w900, 15)),
                    const SizedBox(height: 2),
                    Text(place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(FontWeight.w600, 12.5, Brand.sub)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Ico('trash', size: 20, color: Brand.faint),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Add/edit form for a saved place, shown in a modal bottom sheet.
class _SavedPlaceForm extends ConsumerStatefulWidget {
  const _SavedPlaceForm({this.existing});
  final SavedPlace? existing;

  @override
  ConsumerState<_SavedPlaceForm> createState() => _SavedPlaceFormState();
}

class _SavedPlaceFormState extends ConsumerState<_SavedPlaceForm> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _latCtrl = TextEditingController(text: e == null ? '' : e.lat.toString());
    _lngCtrl = TextEditingController(text: e == null ? '' : e.lng.toString());
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (label.isEmpty || address.isEmpty || lat == null || lng == null) {
      setState(() => _error = 'Fill in label, address, and a valid latitude/longitude.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(savedPlacesServiceProvider);
      final existing = widget.existing;
      if (existing == null) {
        await service.create(label: label, address: address, lat: lat, lng: lng);
      } else {
        await service.update(existing.id, label: label, address: address, lat: lat, lng: lng);
      }
      ref.invalidate(savedPlacesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return McSheet(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            McTitle(isEdit ? 'Edit place' : 'Add a place', size: 20),
            const SizedBox(height: 18),
            McField(
              icon: 'heart',
              placeholder: 'Label (e.g. Home, Work)',
              controller: _labelCtrl,
              editable: true,
            ),
            const SizedBox(height: 12),
            McField(
              icon: 'pin',
              placeholder: 'Address',
              controller: _addressCtrl,
              editable: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: McField(
                    placeholder: 'Latitude',
                    controller: _latCtrl,
                    editable: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: McField(
                    placeholder: 'Longitude',
                    controller: _lngCtrl,
                    editable: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: tw(FontWeight.w600, 13, Colors.red)),
            ],
            const SizedBox(height: 18),
            McButton(
              _saving ? 'Saving…' : 'Save place',
              icon: _saving ? null : 'check',
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
