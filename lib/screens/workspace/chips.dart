import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/widgets/text.dart';

class MemberChips extends StatelessWidget {
  final String memberEmail;
  final Function onDelete;
  const MemberChips(
      {super.key, required this.memberEmail, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return InputChip(
      label: text(
        title: memberEmail,
        align: TextAlign.center,
        color: AppColors.white,
        fontSize: size.width * 0.04,
        fontWeight: AppFonts.bold,
      ),
      labelStyle:
          const TextStyle(fontWeight: AppFonts.bold, color: AppColors.white),
      backgroundColor: AppColors.workspaceGradientColor1[1],
      side: const BorderSide(color: AppColors.white),
      // onPressed: () => print("input chip pressed"),
      deleteIconColor: Colors.white,

      onDeleted: () {
        onDelete();
      },
    );
  }
}
