import 'package:flutter/material.dart';

import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/widgets/members_container.dart';
import 'package:mission_master/widgets/text.dart';
// import 'package:mission_master/widgets/progress_status.dart';

class WorkSpaceContainer extends StatelessWidget {
  final Color color1;
  final Color color2;
  final bool all;
  final String projectName;
  final int membersLength;
  final String projectId;
  final String projectCreationDate;

  const WorkSpaceContainer(
      {super.key,
      required this.color1,
      required this.color2,
      required this.all,
      required this.projectName,
      required this.membersLength,
      required this.projectId,
      required this.projectCreationDate});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var project = locator<Database>;
    return Container(
      width: size.width * 0.5,
      margin: EdgeInsets.only(
        top: size.height * 0.02,
        left: size.width * 0.04,
      ),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 0.5,
            blurRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
        borderRadius: BorderRadius.circular(
          size.width * 0.04,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              // alignment: Alignment.center,
              margin: EdgeInsets.only(
                top: size.height * 0.02,
              ),
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
              child: Text(
                projectName,
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: size.width * 0.05,
                  fontWeight: AppFonts.bold,
                  color: AppColors.white,
                ),
              )),
          Container(
            margin: EdgeInsets.only(
              top: size.height * 0.01,
              left: size.width * 0.04,
              right: size.width * 0.04,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.white,
                  size: size.width * 0.04,
                ),
                SizedBox(width: size.width * 0.01),
                Flexible(
                  child: Text(
                    projectCreationDate,
                    style: TextStyle(
                      fontSize: size.width * 0.03,
                      fontWeight: AppFonts.bold,
                      color: AppColors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          WorkSpaceMembers(
            membersLength: membersLength,
          ),
          all == false
              ? Container(
                  alignment: Alignment.topLeft,
                  padding: EdgeInsets.only(
                    left: size.width * 0.04,
                    bottom: size.height * 0.01,
                  ),
                  margin: EdgeInsets.only(
                    top: size.height * 0.012,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      text(
                        title: "Progress",
                        fontSize: size.width * 0.04,
                        align: TextAlign.start,
                        fontWeight: AppFonts.semiBold,
                        color: AppColors.white,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.03,
                        ),
                        child: FutureBuilder(
                          future: project().getProgress(id: projectId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else {
                              return Text(
                                '${(snapshot.data! * 100).toInt()}%',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: size.width * 0.024,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(),
          all
              ? FutureBuilder(
                  future: project().getProgress(id: projectId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      print("Lỗi khi lấy tiến độ: ${snapshot.error}");
                      return Container(
                        width: size.width * 0.3,
                        alignment: Alignment.center,
                        margin: EdgeInsets.only(
                          left: size.width * 0.04,
                          top: size.height * 0.013,
                        ),
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              size.width * 0.03,
                            ),
                          ),
                          color: Colors.white,
                        ),
                        child: text(
                          title: "Không xác định",
                          fontSize: size.width * 0.04,
                          align: TextAlign.start,
                          fontWeight: AppFonts.semiBold,
                          color: AppColors.black,
                        ),
                      );
                    }
                    
                    final progress = snapshot.data ?? 0.0;
                    return Container(
                      width: size.width * 0.3,
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(
                        left: size.width * 0.04,
                        top: size.height * 0.013,
                      ),
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            size.width * 0.03,
                          ),
                        ),
                        color: Colors.white,
                      ),
                      child: text(
                        title: progress * 100 == 100
                            ? "Completed"
                            : "In Progress",
                        fontSize: size.width * 0.04,
                        align: TextAlign.start,
                        fontWeight: AppFonts.semiBold,
                        color: AppColors.black,
                      ),
                    );
                  })
              : SizedBox(),
        ],
      ),
    );
  }
}
