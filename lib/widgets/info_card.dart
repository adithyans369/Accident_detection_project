import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Card(

      elevation: 3,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          children: [

            Icon(icon, size: 30, color: Colors.redAccent),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}