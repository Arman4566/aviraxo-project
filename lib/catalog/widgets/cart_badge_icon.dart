import 'package:flutter/material.dart';

class CartBadgeIcon extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const CartBadgeIcon({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "$count",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
