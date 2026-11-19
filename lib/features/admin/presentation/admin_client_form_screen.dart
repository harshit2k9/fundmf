import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/presentation/session_providers.dart';
import '../../users/domain/user_profile.dart';

/// Admin-only provisioning form. The email becomes the Firestore document id,
/// so it is immutable after creation.
class AdminClientFormScreen extends ConsumerStatefulWidget {
  const AdminClientFormScreen({super.key, this.existing});

  final UserProfile? existing;

  @override
  ConsumerState<AdminClientFormScreen> createState() =>
      _AdminClientFormScreenState();
}

class _AdminClientFormScreenState
    extends ConsumerState<AdminClientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _pan;
  late final TextEditingController _phone;

  late bool _isApproved;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.fullName ?? '');
    _email = TextEditingController(text: existing?.email ?? '');
    _pan = TextEditingController(text: existing?.pan ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _isApproved = existing?.isApproved ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pan.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final profile = UserProfile(
      email: Validators.normalizeEmail(_email.text),
      fullName: _name.text.trim(),
      pan: Validators.normalizePan(_pan.text),
      phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
      uid: widget.existing?.uid ?? '',
      isApproved: _isApproved,
      clientId: widget.existing?.clientId ?? '',
      createdAt: widget.existing?.createdAt,
      linkedAt: widget.existing?.linkedAt,
      lastLoginAt: widget.existing?.lastLoginAt,
    );

    try {
      final repository = ref.read(userRepositoryProvider);
      if (_isEditing) {
        await repository.updateProfile(profile);
      } else {
        await repository.createProfile(profile);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '${profile.fullName} updated'
                : '${profile.fullName} provisioned — share their email so they can sign up',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = AppException.describe(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit client' : 'New client'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (existing != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: existing.isLinked
                                ? AppColors.emeraldWash
                                : AppColors.amberWash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            existing.isLinked
                                ? 'Linked to a Firebase account. Client ID ${existing.clientId.isEmpty ? '—' : existing.clientId}.'
                                : 'Not claimed yet. The profile is linked automatically on first sign-in.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: existing.isLinked
                                  ? AppColors.emeraldDeep
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Client profile',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline_rounded,
                                  size: 19),
                            ),
                            validator: (value) =>
                                Validators.required(value, 'Full name'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _email,
                            enabled: !_isEditing,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Email address',
                              helperText: _isEditing
                                  ? 'Email is the profile identifier and cannot be changed'
                                  : 'The investor must sign up with this exact email',
                              prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                                size: 19,
                              ),
                            ),
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _pan,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp('[A-Za-z0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(10),
                              _UpperCaseFormatter(),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'PAN number',
                              hintText: 'ABCDE1234F',
                              prefixIcon:
                                  Icon(Icons.credit_card_rounded, size: 19),
                            ),
                            validator: Validators.pan,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: '9876543210',
                              prefixIcon:
                                  Icon(Icons.phone_outlined, size: 19),
                            ),
                            validator: Validators.phone,
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            value: _isApproved,
                            onChanged: (value) =>
                                setState(() => _isApproved = value),
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: AppColors.emeraldDeep,
                            title: const Text(
                              'Approve account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Unapproved clients see the pending-approval screen',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.coralWash,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.coralDeep,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons.save_outlined
                                  : Icons.person_add_alt_1_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _isEditing ? 'Save changes' : 'Provision client',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Transactions are matched on PAN, so the PAN must match the '
                      'one in the CAMS statement emails.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.slateLight,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Forces PAN input to upper case as the admin types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
