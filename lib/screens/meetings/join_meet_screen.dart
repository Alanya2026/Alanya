import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/meeting_service.dart';
import 'ongoing_meet_screen.dart';

class JoinMeetScreen extends StatefulWidget {
  const JoinMeetScreen({super.key});

  @override
  State<JoinMeetScreen> createState() => _JoinMeetScreenState();
}

class _JoinMeetScreenState extends State<JoinMeetScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isCodeValid = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      setState(() {
        _isCodeValid = _codeController.text.trim().length >= 5;
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinMeeting() async {
    setState(() => _isJoining = true);

    try {
      final me = context.read<AuthProvider>().currentUser;
      if (me == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil non disponible, réessayez')),
        );
        return;
      }

      final meetingService =
          Provider.of<MeetingService>(context, listen: false);
      await meetingService.joinByRoom(
        roomCode: _codeController.text.trim(),
        myId: me.alanyaID,
        myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      );

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OngoingMeetScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la connexion à la réunion : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rejoindre une réunion'),
        actions: [
          TextButton(
            onPressed: _isCodeValid && !_isJoining ? _joinMeeting : null,
            child: _isJoining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Rejoindre',
                    style: TextStyle(
                      color: _isCodeValid
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          AppSpacing.hGapSm,
        ],
      ),
      body: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrez le code de réunion fourni par l\'organisateur',
              style: context.text.bodyLarge,
            ),
            AppSpacing.vGapXxl,
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: 'Exemple : abc-defg-hij',
              ),
              style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
            ),
            AppSpacing.vGapXxl,
            Text(
              'Pour rejoindre une réunion, vous avez besoin d\'un code comme abc-defg-hij. '
              'Si vous avez reçu un lien de réunion, vous pouvez cliquer sur le lien à la place.',
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
