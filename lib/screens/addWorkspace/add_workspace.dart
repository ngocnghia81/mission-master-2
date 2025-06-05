import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:mission_master/Utils/utils.dart';
import 'package:mission_master/bloc/addprojectBloc/project_bloc.dart';
import 'package:mission_master/bloc/addprojectBloc/project_events.dart';
import 'package:mission_master/bloc/addprojectBloc/project_states.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/events.dart';
import 'package:mission_master/bloc/memberBloc/member_bloc.dart';
import 'package:mission_master/bloc/memberBloc/member_events.dart';
import 'package:mission_master/bloc/memberBloc/member_states.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';

import 'package:mission_master/screens/workspace/chips.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace/header.dart';
import 'package:mission_master/widgets/workspace/task_field.dart';

class AddWorkspace extends StatefulWidget {
  const AddWorkspace({super.key});

  @override
  State<AddWorkspace> createState() => _AddWorkspaceState();
}

class _AddWorkspaceState extends State<AddWorkspace>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  List<String> memberEmails = [];
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(vsync: this, duration: Duration(seconds: 2));

    animation = Tween(begin: 0.0, end: 1.0).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    TextEditingController projectName = TextEditingController();
    TextEditingController projectDesc = TextEditingController();
    TextEditingController memberEmail = TextEditingController();

    return Scaffold(
      body: SingleChildScrollView(
        key: ValueKey<int>(2),
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: size.height * 0.02,
                bottom: size.height * 0.01,
              ),
              child: text(
                title: 'Tên dự án',
                fontSize: size.width * 0.05,
                fontWeight: AppFonts.semiBold,
                color: AppColors.black,
                align: TextAlign.start,
              ),
            ),
            TaskField(
              onPressed: () {},
              isMember: false,
              controller: projectName,
              NoOfLine: 1,
              deadline: false,
              title: 'VD: Thiết kế ứng dụng di động',
            ),
            Padding(
              padding: EdgeInsets.only(
                top: size.height * 0.02,
                bottom: size.height * 0.01,
              ),
              child: text(
                title: 'Mô tả dự án',
                fontSize: size.width * 0.05,
                fontWeight: AppFonts.semiBold,
                color: AppColors.black,
                align: TextAlign.start,
              ),
            ),
            TaskField(
              onPressed: () {},
              isMember: false,
              controller: projectDesc,
              NoOfLine: 8,
              deadline: false,
              title: 'Mô tả chi tiết về dự án của bạn',
            ),
            Padding(
              padding: EdgeInsets.only(
                top: size.height * 0.02,
                bottom: size.height * 0.01,
              ),
              child: text(
                title: 'Thêm thành viên',
                fontSize: size.width * 0.05,
                fontWeight: AppFonts.semiBold,
                color: AppColors.black,
                align: TextAlign.start,
              ),
            ),
            TaskField(
              onPressed: () {
                BlocProvider.of<MemberBloc>(context)
                    .add(AddMember(memberEmail.text));
                controller.forward();
                memberEmails.add(memberEmail.text);
                memberEmail.clear();
              },
              isMember: true,
              controller: memberEmail,
              NoOfLine: 1,
              deadline: false,
              title: 'Email thành viên (VD: abc@gmail.com)',
            ),
            Container(
              margin: EdgeInsets.only(top: 8, bottom: 16),
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (memberEmail.text.isNotEmpty) {
                    BlocProvider.of<MemberBloc>(context)
                        .add(AddMember(memberEmail.text));
                    controller.forward();
                    memberEmails.add(memberEmail.text);
                    memberEmail.clear();
                  }
                },
                icon: Icon(Icons.person_add, color: Colors.white),
                label: Text("Thêm thành viên", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                  ),
                ),
              ),
            ),
            BlocConsumer<MemberBloc, MembersStates>(
              listener: (context, state) {
                if (state is MemberErrorState) {
                  Utils.showSnackBar(state.message);
                }
              },
              builder: (context, state) {
                if (state is MemberAdded) {
                  print(state.members.length);
                  return SizeTransition(
                    sizeFactor: animation,
                    child: Wrap(
                      spacing: 2,
                      children: List.generate(
                          state.members.length,
                          (index) => MemberChips(
                              memberEmail: state.members[index],
                              onDelete: () {
                                BlocProvider.of<MemberBloc>(context)
                                    .add(RemoveMember(index));
                              })),
                    ),
                  );
                } else if (state is MemberRemoved) {
                  return SizeTransition(
                    sizeFactor: animation,
                    child: Wrap(
                      spacing: 2,
                      children: List.generate(
                          state.members.length,
                          (index) => MemberChips(
                              memberEmail: state.members[index],
                              onDelete: () {
                                BlocProvider.of<MemberBloc>(context)
                                    .add(RemoveMember(index));
                              })),
                    ),
                  );
                } else {
                  return Container();
                }
              },
            ),
            Container(
              width: size.width,
              height: size.height * 0.07,
              margin: EdgeInsets.only(
                top: size.height * 0.02,
                bottom: size.height * 0.02,
              ),
              child: ElevatedButton(
                onPressed: () {
                  DateTime? date = DateTime.now();
                  BlocProvider.of<ProjectBloc>(context).add(AddProject(
                      projectName.text,
                      projectDesc.text,
                      memberEmails,
                      "${date.day}/${date.month}/${date.year}"));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.workspaceGradientColor1[2],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      size.width * 0.03,
                    ),
                  ),
                ),
                child: text(
                  title: 'Tạo dự án',
                  fontSize: size.width * 0.05,
                  fontWeight: AppFonts.semiBold,
                  color: AppColors.white,
                  align: TextAlign.start,
                ),
              ),
            ),
            BlocListener<ProjectBloc, ProjectStates>(
              listener: (context, state) {
                if (state is ProjectAdded) {
                  Utils.showSnackBar(state.message);

                  BlocProvider.of<NavBarBloc>(context)
                      .add(currentPage(index: 2));

                  projectDesc.clear();
                  projectName.clear();
                  BlocProvider.of<MemberBloc>(context).add(AddAllMember());
                } else if (state is ErrorState) {
                  Utils.showSnackBar(state.message);
                }
              },
              child: const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
