import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import 'ongoing_call_screen.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _phoneNumber = '';

  void _onKeyPress(String value) {
    setState(() {
      if (_phoneNumber.length < 15) {
        _phoneNumber += value;
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_phoneNumber.isNotEmpty) {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      }
    });
  }

  void _onCall() async {
    if (_phoneNumber.isEmpty) return;
    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      receiverId: int.tryParse(_phoneNumber) ?? 0,
      isVideo: false,
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
          // Number display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            height: 80,
            alignment: Alignment.center,
            child: Text(
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
                const SizedBox(width: 64), // Balance the row
                GestureDetector(
                  onTap: _onCall,
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
                    icon: const Icon(CupertinoIcons.delete_left, size: 28, color: Colors.grey),
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
