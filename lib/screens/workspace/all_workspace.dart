import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/Authentications/google_signin.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace_container.dart';
import 'package:flutter/foundation.dart';

class AllWorkspace extends StatefulWidget {
  const AllWorkspace({super.key});

  @override
  State<AllWorkspace> createState() => _AllWorkspaceState();
}

class _AllWorkspaceState extends State<AllWorkspace> {
  final project = locator<Database>();
  final projectController = ProjectController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allProjects = [];
  
  @override
  void initState() {
    super.initState();
    _loadAllProjects();
  }
  
  Future<void> _loadAllProjects() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Lấy email của người dùng hiện tại
      final currentUserEmail = Auth.auth.currentUser!.email;
      print('DEBUG: Đang tải dự án cho người dùng: $currentUserEmail');
      
      // Lấy dự án thường
      final regularProjectsSnapshot = await FirebaseFirestore.instance
          .collection('Project')
          .where(
            Filter.or(
              Filter("email", arrayContains: currentUserEmail),
              Filter('projectCreatedBy', isEqualTo: currentUserEmail),
            ),
          )
          .get();
      
      print('DEBUG: Tìm thấy ${regularProjectsSnapshot.docs.length} dự án thường');
      
      // Lấy dự án enterprise
      final enterpriseProjectsSnapshot = await FirebaseFirestore.instance
          .collection('EnterpriseProjects')
          .where('memberEmails', arrayContains: currentUserEmail)
          .get();
      
      print('DEBUG: Tìm thấy ${enterpriseProjectsSnapshot.docs.length} dự án enterprise');
      
      // Chuyển đổi dự án thường thành định dạng chung
      final regularProjects = regularProjectsSnapshot.docs.map((doc) {
        final data = doc.data();
        print('DEBUG: Dự án thường - ID: ${doc.id}, Tên: ${data['projectName']}');
        return {
          'id': doc.id,
          'name': data['projectName'],
          'description': data['projectDescription'] ?? '',
          'members': data['email'] ?? [],
          'createdOn': data['createdOn'],
          'createdBy': data['projectCreatedBy'],
          'isEnterprise': false,
        };
      }).toList();
      
      // Chuyển đổi dự án enterprise thành định dạng chung
      final enterpriseProjects = enterpriseProjectsSnapshot.docs.map((doc) {
        final data = doc.data();
        print('DEBUG: Dự án enterprise - ID: ${doc.id}, Tên: ${data['name']}');
        
        // Xử lý createdAt có thể là Timestamp hoặc String
        String formattedDate = 'N/A';
        try {
          if (data['createdAt'] != null) {
            if (data['createdAt'] is Timestamp) {
              // Nếu là Timestamp
              final date = (data['createdAt'] as Timestamp).toDate();
              formattedDate = '${date.day}/${date.month}/${date.year}';
            } else if (data['createdAt'] is String) {
              // Nếu là String
              final date = DateTime.parse(data['createdAt'] as String);
              formattedDate = '${date.day}/${date.month}/${date.year}';
            }
          }
        } catch (e) {
          print('Lỗi khi xử lý ngày tạo: $e');
          formattedDate = 'N/A';
        }
        
        return {
          'id': doc.id,
          'name': data['name'],
          'description': data['description'] ?? '',
          'members': data['memberEmails'] ?? [],
          'createdOn': formattedDate,
          'createdBy': data['createdBy'],
          'isEnterprise': true,
        };
      }).toList();
      
      // Kết hợp cả hai loại dự án
      setState(() {
        _allProjects = [...regularProjects, ...enterpriseProjects];
        _isLoading = false;
      });
      
      print('DEBUG: Tổng số dự án đã tải: ${_allProjects.length}');
      if (_allProjects.isEmpty) {
        print('DEBUG: Không tìm thấy dự án nào cho người dùng: $currentUserEmail');
      }
    } catch (e) {
      print('Lỗi khi tải dự án: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    int colorIndex1 = 0;
    int colorIndex2 = 0;
    
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _loadAllProjects();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đang làm mới danh sách dự án...'))
          );
        },
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.refresh, color: Colors.white),
      ),
      body: Container(
        margin: EdgeInsets.only(
          right: size.width * 0.03,
          left: size.width * 0.03,
        ),
        child: RefreshIndicator(
          onRefresh: _loadAllProjects,
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _allProjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          text(
                            title: 'Không có không gian làm việc nào',
                            align: TextAlign.center,
                            color: AppColors.grey,
                            fontSize: size.width * 0.045,
                            fontWeight: AppFonts.semiBold,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadAllProjects,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Làm mới'),
                          ),
                          if (kDebugMode) ...[
                            SizedBox(height: 20),
                            Text(
                              'Debug: Đã tải ${_allProjects.length} dự án',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (kDebugMode)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Debug: Đã tải ${_allProjects.length} dự án',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        Expanded(
                          child: GridView.builder(
                            itemCount: _allProjects.length,
                            padding: EdgeInsets.only(
                              top: size.height * 0.01,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemBuilder: (context, index) {
                              final project = _allProjects[index];
                              final isEnterprise = project['isEnterprise'] == true;
                              
                              if (colorIndex1 == 3 || colorIndex2 == 3) {
                                colorIndex1 = 0;
                                colorIndex2 = 0;
                              }

                              return InkWell(
                                onTap: () {
                                  if (isEnterprise) {
                                    // Chuyển đến trang chi tiết dự án enterprise
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.enterpriseDashboard,
                                      arguments: project['id'],
                                    );
                                  } else {
                                    // Chuyển đến trang chi tiết dự án thường
                                    projectController.members.clear();
                                    Navigator.of(context).pushNamed(AppRoutes.workSpaceDetail);
                                    projectController.projectId.value = project['id'];
                                    projectController.projectCreationDate.value = project['createdOn'];
                                    projectController.projectCreatedBy.value = project['createdBy'];
                                    projectController.projectName.value = project['name'];
                                    projectController.projectDescription.value = project['description'];
                                    projectController.members.addAll(project['members']);
                                  }
                                },
                                child: Stack(
                                  children: [
                                    WorkSpaceContainer(
                                      projectId: project['id'].toString(),
                                      projectCreationDate: project['createdOn'],
                                      membersLength: project['members'].length,
                                      projectName: project['name'],
                                      all: true,
                                      color1: isEnterprise 
                                          ? AppColors.enterpriseGradient1 
                                          : AppColors.workspaceGradientColor1[colorIndex1++],
                                      color2: isEnterprise 
                                          ? AppColors.enterpriseGradient2 
                                          : AppColors.workspaceGradientColor2[colorIndex2++],
                                    ),
                                    if (isEnterprise)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.business, size: 14, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                'Enterprise',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
