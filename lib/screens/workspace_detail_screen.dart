import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mission_master/Utils/utils.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/widgets/task_card.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/team_mood_widget.dart';
import 'package:mission_master/screens/statistics/project_statistics_screen.dart';
import 'package:mission_master/screens/task/task_detail_screen.dart';
import 'package:mission_master/screens/workspace/gantt_chart_screen.dart';
import 'package:mission_master/screens/workspace/kanban_board_screen.dart';
import 'package:mission_master/screens/workspace/workspace_board_screen.dart';
import 'package:mission_master/screens/workspace/workspace_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';

class WorkspaceDetail extends StatefulWidget {
  const WorkspaceDetail({super.key});

  @override
  _WorkspaceDetailState createState() => _WorkspaceDetailState();
}

class _WorkspaceDetailState extends State<WorkspaceDetail> {
  final projectController = ProjectController();
  late double width = 0;
  late double height = 0;
  bool _showOnlyMyTasks = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        width = size.width;
        height = size.height;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    width = size.width;
    height = size.height;
    
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        elevation: 0.0,
        color: AppColors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            2,
            (index) => SizedBox(
              width: width * 0.4,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.workspaceGradientColor1[index],
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.05,
                    vertical: height * 0.02,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      width * 0.03,
                    ),
                  ),
                ),
                onPressed: () {
                  if (index == 0) {
                    Navigator.of(context).pushNamed(AppRoutes.addMember);
                  } else if (index == 1) {
                    Navigator.of(context).pushNamed(AppRoutes.addTask);
                  } else {}
                },
                child: text(
                  title: ViLabels.projectDetailButtonLabel[index],
                  fontSize: width * 0.04,
                  fontWeight: AppFonts.semiBold,
                  color: AppColors.white,
                  align: TextAlign.start,
                ),
              ),
            ),
          ),
        ),
      ),
      appBar: AppBar(
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(AppRoutes.main);
          },
        ),
        title: text(
          color: AppColors.black,
          title: ViLabels.workspaceDetails,
          fontSize: width * 0.06,
          fontWeight: AppFonts.semiBold,
          align: TextAlign.start,
        ),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.06,
            vertical: height * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFeatureButton(
                        icon: Icons.analytics_outlined,
                        label: 'Thống kê',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectStatisticsScreen(
                                projectId: projectController.projectId.string,
                                projectName: projectController.projectName.string,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFeatureButton(
                        icon: Icons.chat_outlined,
                        label: 'Chat',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkspaceChatScreen(
                                projectId: projectController.projectId.string,
                                projectName: projectController.projectName.string,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFeatureButton(
                        icon: Icons.announcement_outlined,
                        label: 'Thông báo',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkspaceBoardScreen(
                                projectId: projectController.projectId.string,
                                projectName: projectController.projectName.string,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFeatureButton(
                        icon: Icons.view_kanban_outlined,
                        label: 'Kanban',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KanbanBoardScreen(
                                projectId: projectController.projectId.string,
                                projectName: projectController.projectName.string,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      _buildFeatureButton(
                        icon: Icons.stacked_line_chart,
                        label: 'Gantt',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GanttChartScreen(
                                projectId: projectController.projectId.string,
                                projectName: projectController.projectName.string,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              text(
                title: projectController.projectName.string,
                fontSize: width * 0.06,
                fontWeight: AppFonts.bold,
                color: AppColors.black,
                align: TextAlign.start,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  2,
                  (index) => Container(
                    width: width * 0.4,
                    decoration: BoxDecoration(
                      color:
                          AppColors.workspaceGradientColor1[0].withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        width * 0.03,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: height * 0.02,
                    ),
                    margin: EdgeInsets.only(
                      top: height * 0.01,
                      right: width * 0.03,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            right: width * 0.012,
                          ),
                          child: Icon(
                            [
                              Icons.calendar_month_outlined,
                              Icons.people
                            ][index],
                            size: width * 0.08,
                            color: AppColors.workspaceGradientColor2[0],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text(
                              title: ViLabels.projectDetailLabel[index],
                              fontSize: width * 0.035,
                              fontWeight: AppFonts.normal,
                              color: AppColors.grey,
                              align: TextAlign.start,
                            ),
                            index == 0
                                ? text(
                                    title: projectController
                                        .projectCreationDate.value,
                                    fontSize: width * 0.04,
                                    fontWeight: AppFonts.semiBold,
                                    color: AppColors.black,
                                    align: TextAlign.start,
                                  )
                                : StreamBuilder(
                                    stream: FirebaseFirestore.instance
                                        .collection('User')
                                        .doc(projectController
                                            .projectCreatedBy.string)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.connectionState ==
                                              ConnectionState.active) {
                                        DocumentSnapshot snap = snapshot.data!;
                                        return text(
                                          title: snap.exists
                                              ? snap['userName']
                                              : "User Name",
                                          fontSize: width * 0.04,
                                          fontWeight: AppFonts.semiBold,
                                          color: AppColors.black,
                                          align: TextAlign.start,
                                        );
                                      } else {
                                        return Container();
                                      }
                                    })
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: height * 0.01,
                ),
                child: text(
                  title: ViLabels.description,
                  fontSize: width * 0.05,
                  fontWeight: AppFonts.semiBold,
                  color: AppColors.black,
                  align: TextAlign.start,
                ),
              ),
              text(
                title: projectController.projectDescription.string,
                fontSize: width * 0.04,
                fontWeight: AppFonts.normal,
                color: AppColors.grey,
                align: TextAlign.start,
              ),
              
              // 🤖 AI Team Mood Analysis
              TeamMoodWidget(
                projectId: projectController.projectId.string,
                projectName: projectController.projectName.string,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: height * 0.01,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    text(
                      title: ViLabels.tasks,
                      fontSize: width * 0.05,
                      fontWeight: AppFonts.semiBold,
                      color: AppColors.black,
                      align: TextAlign.start,
                    ),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Tất cả',
                            style: TextStyle(
                              color: !_showOnlyMyTasks ? Colors.white : Colors.black,
                              fontWeight: !_showOnlyMyTasks ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: !_showOnlyMyTasks,
                          selectedColor: AppColors.workspaceGradientColor1[0],
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _showOnlyMyTasks = false;
                              });
                            }
                          },
                        ),
                        SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Của tôi',
                            style: TextStyle(
                              color: _showOnlyMyTasks ? Colors.white : Colors.black,
                              fontWeight: _showOnlyMyTasks ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: _showOnlyMyTasks,
                          selectedColor: AppColors.workspaceGradientColor1[1],
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _showOnlyMyTasks = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: height * 0.5,
                child: StreamBuilder(
                    stream: projectController.projectId.string.isNotEmpty
                        ? FirebaseFirestore.instance
                            .collection('Tasks')
                            .doc(projectController.projectId.string)
                            .collection('projectTasks')
                            .snapshots()
                        : const Stream<QuerySnapshot>.empty(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || projectController.projectId.string.isEmpty) {
                        return Center(
                          child: Text(
                            'Không có dữ liệu nhiệm vụ hoặc ID dự án không hợp lệ',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        );
                      } else {
                        final docs = snapshot.data!.docs;
                        final filteredDocs = _showOnlyMyTasks
                            ? docs.where((doc) {
                                final members = List<String>.from(doc['Members'] ?? []);
                                return members.contains(Auth.auth.currentUser?.email);
                              }).toList()
                            : docs;
                            
                        return filteredDocs.isNotEmpty
                            ? ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  DocumentSnapshot snap = filteredDocs[index];
                                  return Container(
                                    margin: EdgeInsets.symmetric(
                                      vertical: height * 0.01,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          width: 1, color: Colors.grey),
                                      borderRadius: BorderRadius.circular(
                                        10.0,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        showBottomSheet(
                                          backgroundColor: AppColors.white,
                                          elevation: 0.0,
                                          enableDrag: true,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              width * 0.1,
                                            ),
                                          ),
                                          context: context,
                                          builder: (context) {
                                            return Container(
                                              width: width,
                                              height: height * 0.55,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: width * 0.1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.white,
                                                borderRadius: BorderRadius.only(
                                                  topRight: Radius.circular(
                                                      width * 0.1),
                                                  topLeft: Radius.circular(
                                                      width * 0.1),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.grey,
                                                    blurRadius: 0.3,
                                                    spreadRadius: 0.2,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: width * 0.8,
                                                    height: height * 0.01,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.grey
                                                          .withOpacity(0.3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        width * 0.1,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      vertical: height * 0.02,
                                                    ),
                                                    child: text(
                                                      title: ViLabels.taskDetails,
                                                      fontSize: width * 0.06,
                                                      fontWeight: AppFonts.bold,
                                                      color: AppColors.black,
                                                      align: TextAlign.center,
                                                    ),
                                                  ),
                                                  Divider(),
                                                  SizedBox(
                                                    height: height * 0.01,
                                                  ),
                                                  text(
                                                    title: ViLabels.taskName,
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.black,
                                                    align: TextAlign.center,
                                                  ),
                                                  text(
                                                    title: snap['taskName'],
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.grey,
                                                    align: TextAlign.center,
                                                  ),
                                                  SizedBox(
                                                    height: height * 0.01,
                                                  ),
                                                  text(
                                                    title: ViLabels.description,
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.black,
                                                    align: TextAlign.center,
                                                  ),
                                                  text(
                                                    title: snap['description'],
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.grey,
                                                    align: TextAlign.start,
                                                  ),
                                                  SizedBox(
                                                    height: height * 0.01,
                                                  ),
                                                  text(
                                                    title: "${ViLabels.assignedTo}:",
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.black,
                                                    align: TextAlign.center,
                                                  ),
                                                  ListView.builder(
                                                    itemCount:
                                                        snap['Members'].length,
                                                    shrinkWrap: true,
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemBuilder:
                                                        (context, index) {
                                                      return text(
                                                        title: snap['Members']
                                                                [index]
                                                            .toString(),
                                                        fontSize: width * 0.04,
                                                        fontWeight:
                                                            AppFonts.medium,
                                                        color: AppColors.grey,
                                                        align: TextAlign.start,
                                                      );
                                                    },
                                                  ),
                                                  SizedBox(
                                                    height: height * 0.01,
                                                  ),
                                                  text(
                                                    title: ViLabels.deadline,
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.black,
                                                    align: TextAlign.center,
                                                  ),
                                                  text(
                                                    title:
                                                        "${snap['deadlineDate']} | ${snap['deadlineTime']}",
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.grey,
                                                    align: TextAlign.start,
                                                  ),
                                                  SizedBox(
                                                    height: height * 0.01,
                                                  ),
                                                  text(
                                                    title: ViLabels.taskStatus,
                                                    fontSize: width * 0.04,
                                                    fontWeight: AppFonts.medium,
                                                    color: AppColors.black,
                                                    align: TextAlign.center,
                                                  ),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        flex: 2,
                                                        child: text(
                                                          title: snap['status'] ?? ViLabels.taskStatusLabels[0],
                                                          fontSize: width * 0.04,
                                                          fontWeight: AppFonts.medium,
                                                          color: _getStatusColor(snap['status'] ?? ViLabels.taskStatusLabels[0]),
                                                          align: TextAlign.start,
                                                        ),
                                                      ),
                                                      Flexible(
                                                        flex: 1,
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: AppColors.workspaceGradientColor1[0],
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal: width * 0.02,
                                                              vertical: height * 0.01,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            _showStatusUpdateDialog(context, snap);
                                                          },
                                                          child: text(
                                                            title: ViLabels.updateStatus,
                                                            fontSize: width * 0.03,
                                                            fontWeight: AppFonts.medium,
                                                            color: AppColors.white,
                                                            align: TextAlign.center,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Container(
                                                    alignment: Alignment.center,
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                      vertical: height * 0.02,
                                                    ),
                                                    child: ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: AppColors
                                                            .workspaceGradientColor1[1],
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(context).pop();
                                                      },
                                                      child: text(
                                                        title: ViLabels.close,
                                                        fontSize: width * 0.04,
                                                        fontWeight:
                                                            AppFonts.bold,
                                                        color: AppColors.white,
                                                        align: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      onLongPress: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              backgroundColor: AppColors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  width * 0.02,
                                                ),
                                              ),
                                              elevation: 0.0,
                                              title: text(
                                                title: ViLabels.deleteTask,
                                                fontSize: width * 0.065,
                                                fontWeight: AppFonts.bold,
                                                color: AppColors.black,
                                                align: TextAlign.center,
                                              ),
                                              actions: List.generate(
                                                2,
                                                (index) => ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    elevation: 0.0,
                                                    backgroundColor: AppColors
                                                        .workspaceGradientColor1[
                                                            index]
                                                        .withOpacity(0.3),
                                                  ),
                                                  onPressed: () async {
                                                    if (index == 0) {
                                                      Navigator.of(context).pop();
                                                    } else {
                                                      Navigator.of(context).pop();
                                                      
                                                      // Kiểm tra projectId trước khi xóa
                                                      if (projectController.projectId.value.toString().isEmpty) {
                                                        Utils.showtoast('Không thể xóa: ID dự án không hợp lệ');
                                                        return;
                                                      }
                                                      
                                                      try {
                                                        Utils.showtoast(
                                                            ViLabels.taskHasBeenDeleted);
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection("Tasks")
                                                            .doc(projectController
                                                                .projectId.value
                                                                .toString())
                                                            .collection(
                                                                "projectTasks")
                                                            .doc(snap.id)
                                                            .delete();
                                                      } catch (e) {
                                                        print('Lỗi khi xóa nhiệm vụ: $e');
                                                        Utils.showtoast('Không thể xóa nhiệm vụ: $e');
                                                      }
                                                    }
                                                  },
                                                  child: text(
                                                    title: [
                                                      ViLabels.cancel,
                                                      ViLabels.delete
                                                    ][index],
                                                    fontSize: width * 0.04,
                                                    fontWeight:
                                                        AppFonts.semiBold,
                                                    color: AppColors.black,
                                                    align: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              content: Container(
                                                decoration: const BoxDecoration(
                                                  color: AppColors.white,
                                                ),
                                                child: text(
                                                  title: ViLabels.deleteConfirm,
                                                  fontSize: width * 0.04,
                                                  fontWeight: AppFonts.regular,
                                                  color: AppColors.grey,
                                                  align: TextAlign.start,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: ListTile(
                                        title: text(
                                          title: snap['taskName'],
                                          fontSize: width * 0.04,
                                          fontWeight: AppFonts.bold,
                                          color: AppColors.black,
                                          align: TextAlign.start,
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            text(
                                              title:
                                                  "${snap['deadlineDate']}. ${snap['deadlineTime']}. ${projectController.projectName.value}",
                                              fontSize: width * 0.03,
                                              fontWeight: AppFonts.normal,
                                              color: Colors.grey,
                                              align: TextAlign.start,
                                            ),
                                            SizedBox(height: 4),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(snap['status'] ?? ViLabels.taskStatusLabels[0]).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: _getStatusColor(snap['status'] ?? ViLabels.taskStatusLabels[0]),
                                                  width: 1,
                                                ),
                                              ),
                                              child: text(
                                                title: snap['status'] ?? ViLabels.taskStatusLabels[0],
                                                fontSize: width * 0.03,
                                                fontWeight: AppFonts.medium,
                                                color: _getStatusColor(snap['status'] ?? ViLabels.taskStatusLabels[0]),
                                                align: TextAlign.start,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: text(
                                    title: ViLabels.noTask,
                                    fontSize: width * 0.04,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.black,
                                    align: TextAlign.center),
                              );
                      }
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.primaryColor,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(task: task),
          ),
        );
      },
      child: TaskCard(task: task, showProject: false),
    );
  }

  Color _getStatusColor(String status) {
    // Xác định màu dựa trên trạng thái
    switch (status) {
      case 'Đang thực hiện':
        return Colors.orange;
      case 'Hoàn thành':
        return Colors.green;
      case 'Chưa bắt đầu':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showStatusUpdateDialog(BuildContext context, DocumentSnapshot snap) {
    String currentStatus = snap['status'] ?? ViLabels.taskStatusLabels[0];
    String selectedStatus = currentStatus;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: text(
            title: ViLabels.updateStatus,
            fontSize: width * 0.05,
            fontWeight: AppFonts.bold,
            color: AppColors.black,
            align: TextAlign.center,
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: ViLabels.taskStatusLabels.map((status) {
                  return RadioListTile<String>(
                    title: text(
                      title: status,
                      fontSize: width * 0.04,
                      fontWeight: AppFonts.medium,
                      color: _getStatusColor(status),
                      align: TextAlign.start,
                    ),
                    value: status,
                    groupValue: selectedStatus,
                    onChanged: (String? value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: text(
                title: ViLabels.cancel,
                fontSize: width * 0.04,
                fontWeight: AppFonts.medium,
                color: AppColors.black,
                align: TextAlign.center,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.workspaceGradientColor1[1],
              ),
              onPressed: () async {
                // Kiểm tra projectId trước khi cập nhật
                if (projectController.projectId.string.isEmpty) {
                  Navigator.of(context).pop();
                  Utils.showtoast('Không thể cập nhật: ID dự án không hợp lệ');
                  return;
                }
                
                try {
                  // Cập nhật trạng thái task trong Firestore
                  await FirebaseFirestore.instance
                      .collection("Tasks")
                      .doc(projectController.projectId.string)
                      .collection("projectTasks")
                      .doc(snap.id)
                      .update({'status': selectedStatus});
                  
                  // Đóng dialog
                  Navigator.of(context).pop();
                  
                  // Hiển thị thông báo
                  Utils.showtoast(ViLabels.statusUpdated);
                } catch (e) {
                  print('Lỗi khi cập nhật trạng thái: $e');
                  Navigator.of(context).pop();
                  Utils.showtoast('Không thể cập nhật trạng thái: $e');
                }
              },
              child: text(
                title: ViLabels.save,
                fontSize: width * 0.04,
                fontWeight: AppFonts.medium,
                color: AppColors.white,
                align: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}
