import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace_container.dart';

class AllWorkspace extends StatelessWidget {
  const AllWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var project = locator<Database>;
    int colorIndex1 = 0;
    int colorIndex2 = 0;
    final projectController = ProjectController();
    return Scaffold(
      body: Container(
        margin: EdgeInsets.only(
          right: size.width * 0.03,
          left: size.width * 0.03,
        ),
        child: StreamBuilder(
          stream: project().getAllProjects(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else {
              return snapshot.data!.docs.isNotEmpty &&
                      snapshot.connectionState == ConnectionState.active
                  ? GridView.builder(
                      itemCount: snapshot.data!.docs.length,
                      padding: EdgeInsets.only(
                        top: size.height * 0.01,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        DocumentSnapshot snap =
                            snapshot.data!.docs[index];
                        if (colorIndex1 == 3 || colorIndex2 == 3) {
                          colorIndex1 = 0;
                          colorIndex2 = 0;
                        }

                        return InkWell(
                          onTap: () {
                            projectController.members.clear();
                            Navigator.of(context).pushNamed(AppRoutes.workSpaceDetail);
                            projectController.projectId.value =
                                snap['projectId'];
                            projectController.projectCreationDate.value =
                                snap['createdOn'];
                            projectController.projectCreatedBy.value =
                                snap['projectCreatedBy'];
                            projectController.projectName.value =
                                snap['projectName'];
                            projectController.projectDescription.value =
                                snap['projectDescription'];
                            projectController.members
                                .addAll(snap['email']);
                          },
                          child: WorkSpaceContainer(
                            projectId: snap['projectId'].toString(),
                            projectCreationDate: snap['createdOn'],
                            membersLength: snap['email'].length,
                            projectName: snap['projectName'],
                            all: true,
                            color1: AppColors
                                .workspaceGradientColor1[colorIndex1++],
                            color2: AppColors
                                .workspaceGradientColor2[colorIndex2++],
                          ),
                        );
                      },
                    )
                  : Center(
                      child: text(
                        title: 'Không có không gian làm việc nào',
                        align: TextAlign.center,
                        color: AppColors.grey,
                        fontSize: size.width * 0.045,
                        fontWeight: AppFonts.semiBold,
                      ),
                    );
            }
          },
        ),
      ),
    );
  }
}
