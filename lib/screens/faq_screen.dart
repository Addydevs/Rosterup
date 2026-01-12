import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/ad_banner.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final questions = [
      _FaqItem(
        question: 'What is RosterUp?',
        answer:
            'RosterUp helps you coordinate pickup games with your team — create teams, schedule games, and track who is in, maybe, or out.',
      ),
      _FaqItem(
        question: 'Do I have to use my real name?',
        answer:
            'We recommend using the name your teammates know you by so they can recognize you in rosters and chats.',
      ),
      _FaqItem(
        question: 'How do I join a team?',
        answer:
            'Ask your captain for the 6-character team code, then go to Teams → Join by code and enter the code there.',
      ),
      _FaqItem(
        question: 'How do I set up a new game?',
        answer:
            'Go to the Games tab, or open your team from the Teams tab. On the team screen, use “Add game” to pick a date, time, location, and player cap. You can choose whether the game is public or requires an access code.',
      ),
      _FaqItem(
        question: 'How do I search or discover games?',
        answer:
            'From the Games tab, tap the globe icon in the top-right to open Discover games. There you can filter by sport and optionally by distance if you allow location access, then tap a game to see details and join.',
      ),
      _FaqItem(
        question: 'How do I share my team code?',
        answer:
            'Open Teams, tap your team, then use the copy or share icons next to the team code to send it to your teammates.',
      ),
      _FaqItem(
        question: 'Can I type in my own language?',
        answer:
            'Yes. RosterUp works with any keyboard your phone supports. Add your language keyboard in your device settings and use it when typing in chat or forms.',
      ),
      _FaqItem(
        question: 'Why are notifications not coming through?',
        answer:
            'First, check Settings → Notifications inside RosterUp. Then, make sure notifications are allowed for RosterUp in your phone\'s system settings.',
      ),
      _FaqItem(
        question: 'How do I reset my password?',
        answer:
            'On the Log in screen, enter your email, then tap “Forgot password?”. We\'ll send a password reset link to that address so you can choose a new password.',
      ),
      _FaqItem(
        question: 'How can I send feedback or ask questions?',
        answer:
            'Open Settings, scroll to the Help section, and tap “Contact & feedback”. This opens your email app so you can write to us at rosterupapp@gmail.com.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final item = questions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  title: Text(
                    item.question,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.answer,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}
