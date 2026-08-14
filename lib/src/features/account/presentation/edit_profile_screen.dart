import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/services/rider_auth_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  late final TextEditingController _accessibilityCtrl;
  bool _marketingConsent = false;
  String? _formError;
  bool _uploadingPicture = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    _nameCtrl = TextEditingController(text: auth.fullName ?? '');
    _emailCtrl = TextEditingController(text: auth.email ?? '');
    _emergencyNameCtrl = TextEditingController(text: auth.emergencyContactName ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: auth.emergencyContactPhone ?? '');
    _accessibilityCtrl = TextEditingController(text: auth.accessibilityNeeds ?? '');
    _marketingConsent = auth.marketingConsent;

    // A restored session may predate these fields — refresh from the API so
    // emergency contact / accessibility / consent show the latest values.
    Future.microtask(() async {
      await ref.read(authNotifierProvider.notifier).loadProfile();
      if (!mounted) return;
      final refreshed = ref.read(authNotifierProvider);
      _nameCtrl.text = refreshed.fullName ?? _nameCtrl.text;
      _emailCtrl.text = refreshed.email ?? _emailCtrl.text;
      _emergencyNameCtrl.text = refreshed.emergencyContactName ?? '';
      _emergencyPhoneCtrl.text = refreshed.emergencyContactPhone ?? '';
      _accessibilityCtrl.text = refreshed.accessibilityNeeds ?? '';
      setState(() => _marketingConsent = refreshed.marketingConsent);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _accessibilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Please enter your full name.');
      return;
    }
    setState(() => _formError = null);
    final email = _emailCtrl.text.trim();
    final emergencyName = _emergencyNameCtrl.text.trim();
    final emergencyPhone = _emergencyPhoneCtrl.text.trim();
    final accessibility = _accessibilityCtrl.text.trim();
    final ok = await ref.read(authNotifierProvider.notifier).updateProfile(
          fullName: name,
          email: email.isEmpty ? null : email,
          emergencyContactName: emergencyName.isEmpty ? null : emergencyName,
          emergencyContactPhone: emergencyPhone.isEmpty ? null : emergencyPhone,
          marketingConsent: _marketingConsent,
          accessibilityNeeds: accessibility.isEmpty ? null : accessibility,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _pickPicture() async {
    final source = await showPictureSourcePicker(context);
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPicture = true);
    await ref.read(authNotifierProvider.notifier).uploadProfilePicture(File(picked.path));
    if (mounted) setState(() => _uploadingPicture = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final token = ref.watch(authTokenProvider);
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McNavHeader(title: 'Personal info', fallback: '/account'),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _uploadingPicture ? null : _pickPicture,
                          child: SizedBox(
                            width: 92,
                            height: 92,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (_uploadingPicture)
                                  const SizedBox(
                                    width: 92,
                                    height: 92,
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                else if (auth.hasProfilePicture && token != null)
                                  ClipOval(
                                    child: Image.network(
                                      ref.read(riderAuthServiceProvider).profilePictureUrl(Env.apiBaseUrl),
                                      headers: {'Authorization': 'Bearer $token'},
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => const McAvatar(size: 92),
                                    ),
                                  )
                                else
                                  const McAvatar(size: 92),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Brand.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: const Center(
                                      child: Ico('camera', size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      McField(
                        icon: 'user',
                        placeholder: 'Your full name',
                        controller: _nameCtrl,
                        editable: true,
                      ),
                      const SizedBox(height: 12),
                      McField(
                        icon: 'msg',
                        placeholder: 'Email (optional)',
                        controller: _emailCtrl,
                        editable: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 22),
                      Text('EMERGENCY CONTACT',
                          style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
                      const SizedBox(height: 10),
                      McField(
                        icon: 'alert',
                        placeholder: "Contact's name (optional)",
                        controller: _emergencyNameCtrl,
                        editable: true,
                      ),
                      const SizedBox(height: 12),
                      McField(
                        icon: 'phone',
                        placeholder: "Contact's phone (optional)",
                        controller: _emergencyPhoneCtrl,
                        editable: true,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 22),
                      Text('ACCESSIBILITY',
                          style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
                      const SizedBox(height: 10),
                      McField(
                        icon: 'access',
                        placeholder: 'Accessibility needs (optional)',
                        controller: _accessibilityCtrl,
                        editable: true,
                      ),
                      const SizedBox(height: 12),
                      McToggleField(
                        icon: 'bell',
                        label: 'Send me offers & updates',
                        value: _marketingConsent,
                        onChanged: (v) => setState(() => _marketingConsent = v),
                      ),
                      if (_formError != null) ...[
                        const SizedBox(height: 12),
                        Text(_formError!, style: tw(FontWeight.w600, 13, Colors.red)),
                      ] else if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(auth.error!, style: tw(FontWeight.w600, 13, Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              McButton(
                auth.isLoading ? 'Saving…' : 'Save changes',
                icon: auth.isLoading ? null : 'check',
                onTap: auth.isLoading ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
