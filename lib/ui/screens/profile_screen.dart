import 'package:flutter/material.dart';

import '../../data/countries.dart';
import '../../services/firebase_service.dart';
import '../../services/save_service.dart';
import '../../theme.dart';
import '../widgets/notebook.dart';

/// Tier-2 account screen: sign in with Google (email only), then pick a
/// display name + country to appear on the global leaderboard.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController(text: SaveService.instance.nickname);
  String _country =
      SaveService.instance.country.isEmpty ? 'IN' : SaveService.instance.country;
  String? _email;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (FirebaseService.instance.isSignedIn) {
      _email = SaveService.instance.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _signedIn => FirebaseService.instance.isSignedIn;

  Future<void> _google() async {
    setState(() => _busy = true);
    final email = await FirebaseService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _email = email;
    });
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in cancelled or failed.', style: hand(18))),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pick a name first.', style: hand(18))),
      );
      return;
    }
    setState(() => _busy = true);
    await FirebaseService.instance.saveProfile(name: name, country: _country);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Erase your name?', style: caveat(32)),
        content: Text(
          'This permanently deletes your account, leaderboard scores and '
          'profile. This cannot be undone.',
          style: hand(18),
        ),
        actions: [
          InkButton(
            label: 'Cancel',
            fontSize: 18,
            onTap: () => Navigator.of(context).pop(false),
          ),
          InkButton(
            label: 'Delete',
            fontSize: 18,
            color: InkPalette.redInk,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await FirebaseService.instance.deleteAccount();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _email = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Account deleted.' : 'Could not delete — try again online.',
          style: hand(18),
        ),
      ),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final offline = !FirebaseService.instance.available;
    return NotebookPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: InkPalette.ink),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              Text('Your Profile', style: caveat(40)),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (offline)
                      Text('Offline — connect to the internet to sign in.',
                          style: hand(20, color: InkPalette.inkFaded))
                    else if (_email == null) ...[
                      Text('Sign in to join the global leaderboard.',
                          style: hand(22)),
                      const SizedBox(height: 18),
                      _busy
                          ? const CircularProgressIndicator(
                              color: InkPalette.redInk)
                          : InkButton(
                              label: '  Sign in with Google  ',
                              color: InkPalette.redInk,
                              onTap: _google,
                            ),
                    ] else ...[
                      Text('Signed in as',
                          style: hand(18, color: InkPalette.inkFaded)),
                      Text(_email!, style: hand(20)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _nameCtrl,
                          maxLength: 14,
                          style: hand(22),
                          decoration: InputDecoration(
                            labelText: 'Display name',
                            labelStyle: hand(18, color: InkPalette.inkFaded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<String>(
                          initialValue: _country,
                          isExpanded: true,
                          style: hand(20, color: InkPalette.ink),
                          decoration: InputDecoration(
                            labelText: 'Country',
                            labelStyle: hand(18, color: InkPalette.inkFaded),
                          ),
                          items: [
                            for (final c in countries)
                              DropdownMenuItem(
                                value: c.code,
                                child: Text('${c.flag}  ${c.name}',
                                    style: hand(20)),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _country = v ?? _country),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _busy
                          ? const CircularProgressIndicator(
                              color: InkPalette.redInk)
                          : InkButton(
                              label: _signedIn ? 'Save' : 'Save & Join',
                              color: InkPalette.redInk,
                              onTap: _save,
                            ),
                      if (_signedIn && !_busy) ...[
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _deleteAccount,
                          child: Text('Delete account',
                              style: hand(16, color: InkPalette.inkFaded)),
                        ),
                      ],
                    ],
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
