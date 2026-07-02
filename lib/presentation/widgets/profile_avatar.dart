import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';

class ProfileAvatar extends ConsumerWidget {
  final double radius;
  
  const ProfileAvatar({super.key, this.radius = 18.0});

  void _showEditNameDialog(BuildContext context, WidgetRef ref) {
    final currentName = ref.read(userNameProvider);
    final controller = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          title: const Text(
            "Ubah Nama Pengguna",
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Nama",
              hintText: "Masukkan nama Anda",
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(userNameProvider.notifier).updateName(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userName = ref.watch(userNameProvider);
    final avatarLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'A';

    return GestureDetector(
      onTap: () => _showEditNameDialog(context, ref),
      child: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurface,
        radius: radius,
        child: Text(
          avatarLetter,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.72,
          ),
        ),
      ),
    );
  }
}
