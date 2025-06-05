import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:mission_master/Utils/utils.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberBloc.dart';
import 'package:mission_master/bloc/addMemberToProject/addMemberstates.dart';
import 'package:mission_master/bloc/addMemberToProject/addmemberevents.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_bloc.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_events.dart';
import 'package:mission_master/bloc/removeMemberFromProjectBloc/removeMember_states.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace/header.dart';

class AddMemberScreen extends StatelessWidget {
  const AddMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final TextEditingController emailController = TextEditingController();
    var project = locator<Database>;
    return header(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.arrow_back_ios)),
              Expanded(
                child: Container(
                  alignment: Alignment.topLeft,
                  padding: EdgeInsets.symmetric(
                    vertical: size.height * 0.02,
                  ),
                  child: text(
                      title: 'Thêm thành viên',
                      fontSize: size.width * 0.05,
                      fontWeight: AppFonts.semiBold,
                      color: AppColors.black,
                      align: TextAlign.start),
                ),
              ),
            ],
          ),
          TextFormField(
            controller: emailController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            autofillHints: [AutofillHints.email],
            decoration: InputDecoration(
              suffixIcon: IconButton(
                onPressed: () {},
                icon: Icon(Icons.person_add_alt_1_outlined),
              ),
              hintText: "i.e: abc@gmail.com",
              hintStyle: TextStyle(
                color: AppColors.grey,
                fontSize: size.width * 0.04,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(size.width * 0.03),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(size.width * 0.03),
              ),
            ),
          ),
          Container(
            alignment: Alignment.topLeft,
            padding: EdgeInsets.only(top: size.height * 0.02),
            child: text(
                title: 'Thành viên đã thêm',
                fontSize: size.width * 0.03,
                fontWeight: AppFonts.semiBold,
                color: AppColors.grey,
                align: TextAlign.start),
          ),
          Expanded(
            child: StreamBuilder<Object>(
                stream: project().getMembersOfProject(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.connectionState ==
                          ConnectionState.active &&
                      snapshot.hasData) {
                    DocumentSnapshot snap = snapshot.data as DocumentSnapshot;

                    return snap['email'].length != 0
                        ? ListView.builder(
                            padding: EdgeInsets.only(
                              top: size.height * 0.02,
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: snap['email'].length,
                            itemBuilder: (context, index) {
                              print("members length:${snap['email']}");
                              return ListTile(
                                title: text(
                                    title: snap['email'][index],
                                    fontSize: size.width * 0.04,
                                    fontWeight: AppFonts.regular,
                                    color: AppColors.black,
                                    align: TextAlign.start),
                                leading: SizedBox(
                                  width: size.width * 0.1,
                                  height: size.height * 0.1,
                                  child: StreamBuilder(
                                      stream: FirebaseFirestore.instance
                                          .collection('User')
                                          .where('email',
                                              isEqualTo: snap['email'][index])
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return CircleAvatar(
                                            child: ClipOval(
                                              child: snapshot
                                                      .data!.docs.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: snapshot.data!
                                                          .docs[0]['photoUrl'],
                                                    )
                                                  : Icon(Icons.person),
                                            ),
                                          );
                                        } else {
                                          return Container();
                                        }
                                      }),
                                ),
                                trailing: BlocListener<
                                    RemoveMemberFromProjectBloc,
                                    RemoveMemberFromProjectStates>(
                                  listener: (context, state) {
                                    print(state);
                                    if (state
                                        is MemberRemovedFromProjectState) {
                                      Utils.showSnackBar(state.message);
                                    } else if (state is ErrorState) {
                                      Utils.showSnackBar(state.message);
                                    }
                                  },
                                  child: IconButton(
                                      onPressed: () {
                                        // print(snap['email'][index]);
                                        BlocProvider.of<
                                                    RemoveMemberFromProjectBloc>(
                                                context)
                                            .add(RemoveMemberFromProject(
                                                memberEmail: snap['email']
                                                    [index]));
                                      },
                                      icon: Icon(
                                        Icons.cancel_outlined,
                                        color: AppColors
                                            .workspaceGradientColor1[1],
                                      )),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: text(
                              title: "Chưa có thành viên nào được thêm",
                              fontSize: size.width * 0.04,
                              fontWeight: AppFonts.semiBold,
                              color: AppColors.black,
                              align: TextAlign.center,
                            ),
                          );
                  } else {
                    return Container();
                  }
                }),
          ),
          BlocListener<AddMemberToProjectBloc, AddMemberToProjectStates>(
            listener: (context, state) {
              if (state is MemberAddedToProjectState) {
                Utils.showSnackBar(state.message);
              } else if (state is AddErrorState) {
                Utils.showSnackBar(state.message);
              }
            },
            child: Container(
              width: size.width,
              padding: EdgeInsets.symmetric(
                vertical: size.height * 0.01,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.workspaceGradientColor1[2],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                  ),
                ),
                onPressed: () {
                  BlocProvider.of<AddMemberToProjectBloc>(context).add(
                      AddMemberToProject(memberEmail: emailController.text));
                  emailController.clear();
                },
                child: text(
                    title: 'Thêm',
                    fontSize: size.width * 0.04,
                    fontWeight: AppFonts.semiBold,
                    color: AppColors.black,
                    align: TextAlign.start),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
