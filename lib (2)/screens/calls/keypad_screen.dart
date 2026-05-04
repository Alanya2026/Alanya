import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import 'ongoing_call_screen.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _phoneNumber = '';
  User? _foundUser;
  bool _isSearching = false;

  void _onKeyPress(String value) {
    setState(() {
      if (_phoneNumber.length < 15) {
        _phoneNumber += value;
        _foundUser = null; // Reset user when typing
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_phoneNumber.isNotEmpty) {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
        _foundUser = null;
      }
    });
  }

  Future<void> _searchUser() async {
    if (_phoneNumber.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final userData = await apiClient.getUserByPhone(_phoneNumber);
      setState(() {
        _foundUser = userData.isNotEmpty
            ? User.fromJson(userData[0] as Map<String, dynamic>)
            : null;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _foundUser = null;
        _isSearching = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
    }
  }

  Future<void> _onCall({bool isVideo = false}) async {
    if (_foundUser == null) {
      await _searchUser();
      if (_foundUser == null) return;
    }

    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final userData = await apiClient.getMe();
    final myId = userData['alanyaID'] ?? 0;

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: _foundUser!.alanyaID,
      myId: myId,
      myName: userData['nom'] ?? userData['pseudo'] ?? '',
      isVideo: isVideo,
    );
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OngoingCallScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Spacer(),
          // Number display or User found
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            height: 80,
            alignment: Alignment.center,
            child: _isSearching
                ? const CircularProgressIndicator()
                : _foundUser != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _foundUser!.nom,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${_foundUser!.pseudo}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _phoneNumber,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
          ),
          const SizedBox(height: 20),
          // Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                const SizedBox(height: 24),
                _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                const SizedBox(height: 24),
                _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                const SizedBox(height: 24),
                _buildRow(['*', '0', '#'], ['', '+', '']),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Call Button Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Video call button
                if (_foundUser != null)
                  GestureDetector(
                    onTap: () => _onCall(isVideo: true),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.indigo),
                      ),
                      child: const Icon(
                        CupertinoIcons.videocam_fill,
                        color: Colors.indigo,
                        size: 28,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 64),
                GestureDetector(
                  onTap: () => _onCall(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.phone_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: IconButton(
                    onPressed: _onDelete,
                    icon: Icon(
                      _foundUser != null ? Icons.clear : CupertinoIcons.delete_left,
                      size: 28,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> numbers, List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return GestureDetector(
          onTap: () => _onKeyPress(numbers[index]),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  numbers[index],
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
                if (letters[index].isNotEmpty)
                  Text(
                    letters[index],
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
