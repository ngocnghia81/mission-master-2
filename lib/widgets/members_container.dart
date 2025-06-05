import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';

class WorkSpaceMembers extends StatelessWidget {
  final int membersLength;
  const WorkSpaceMembers({super.key, required this.membersLength});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final projectController = Get.find<ProjectController>();
    var project = locator<Database>;
    return Row(
      children: [
        Container(
          margin: EdgeInsets.only(
            left: size.width * 0.04,
            top: size.height * 0.01,
          ),
          child: Stack(
            children: [
              StreamBuilder(
                  stream: project().getUserDetail(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      // DocumentSnapshot user = snapshot.data!.docs[0];
                      return CircleAvatar(
                        child: ClipOval(
                          child: snapshot.data!.docs.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: snapshot.data!.docs[0]['photoUrl']
                                      .toString())
                              : Icon(Icons.person),
                        ),
                      );
                    } else {
                      return Container();
                    }
                  }),
              membersLength != 0 && membersLength >= 2
                  ? StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('User')
                          .where('email',
                              isEqualTo: projectController.members.isNotEmpty && projectController.members.length > 1 
                                  ? projectController.members[1] 
                                  : '')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          print("members:${snapshot.data!.docs[0].data()}");
                          return Container(
                            margin: EdgeInsets.only(
                              left: size.width * 0.06,
                            ),
                            child: CircleAvatar(
                              child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: snapshot
                                        .data!.docs[0]['photoUrl']
                                        .toString(),
                                    errorWidget: (context, url, error) => Icon(Icons.person),
                                  )),
                            ),
                          );
                        } else {
                          return Container();
                        }
                      })
                  : SizedBox(),
              membersLength == 3
                  ? Container(
                      margin: EdgeInsets.only(
                        left: size.width * 0.12,
                      ),
                      child: CircleAvatar(
                        child: Text("${membersLength - (membersLength - 1)}+"),
                      ),
                    )
                  : SizedBox()
            ],
          ),
        ),
      ],
    );
  }
}
