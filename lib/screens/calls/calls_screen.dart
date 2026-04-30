import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'incoming_call_screen.dart';
import 'keypad_screen.dart';
import '../shared/schedule_screen.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Calls',
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_call, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          final bool isMissed = index == 1 || index == 3;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.indigo.shade50,
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Colors.indigo,
              ),
            ),
            title: Text(
              'User ${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isMissed ? Colors.red : Colors.black87,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(
                  isMissed ? Icons.call_missed : Icons.call_made,
                  size: 16,
                  color: isMissed ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                const Text('Today, 10:30 AM'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.indigo),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IncomingCallScreen(
                      callerName: 'User ${index + 1}',
                      isVideoCall: index % 2 != 0, // Just to show both video and audio
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const KeypadScreen()));
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.dialpad, color: Colors.white),
      ),
    );
  }
}
