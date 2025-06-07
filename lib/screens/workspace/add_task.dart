import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:mission_master/Utils/utils.dart';
import 'package:mission_master/bloc/TaskBloc/task_bloc.dart';
import 'package:mission_master/bloc/TaskBloc/task_states.dart';
import 'package:mission_master/bloc/TaskBloc/task_events.dart';
import 'package:mission_master/bloc/memberBloc/member_bloc.dart';
import 'package:mission_master/bloc/memberBloc/member_events.dart';
import 'package:mission_master/bloc/memberBloc/member_states.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/constants/vi_labels.dart';
import 'package:mission_master/controllers/project_controller.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'package:mission_master/data/services/user_validation_service.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/screens/workspace/chips.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace/header.dart';
import 'package:mission_master/widgets/workspace/task_field.dart';

class AddTask extends StatefulWidget {
  const AddTask({super.key});

  @override
  State<AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends State<AddTask> with SingleTickerProviderStateMixin {
  var project = locator<Database>;
  String selectedPriority = 'normal';
  bool isRecurring = false;
  String selectedRecurringInterval = 'daily';
  
  // Giữ danh sách thành viên trong state của widget
  final List<String> _selectedMembers = [];
  
  // Đưa các controller vào state để tránh bị reset khi rebuild
  final TextEditingController taskController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController assignedToController = TextEditingController();
  
  // Thêm FocusNode để quản lý focus
  final FocusNode taskFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();
  final FocusNode dateFocus = FocusNode();
  final FocusNode timeFocus = FocusNode();
  final FocusNode assignedToFocus = FocusNode();

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    // Giải phóng controller khi widget bị hủy
    taskController.dispose();
    descriptionController.dispose();
    dateController.dispose();
    timeController.dispose();
    assignedToController.dispose();
    
    // Giải phóng FocusNode
    taskFocus.dispose();
    descriptionFocus.dispose();
    dateFocus.dispose();
    timeFocus.dispose();
    assignedToFocus.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectController = ProjectController();
    final Size size = MediaQuery.of(context).size;

    // Tạo các widget con bên ngoài để tránh rebuild không cần thiết
    final taskField = TaskField(
      controller: taskController,
      focusNode: taskFocus,
      isMember: false,
      onPressed: () {},
      deadline: false,
      title: 'VD: Thiết kế, Phát triển, Kiểm thử, v.v.',
      NoOfLine: 1
    );
    
    final descriptionField = TaskField(
      controller: descriptionController,
      focusNode: descriptionFocus,
      isMember: false,
      onPressed: () {},
      deadline: false,
      title: 'VD: Chi tiết về công việc được giao',
      NoOfLine: 8
    );
    
    final dateFieldContainer = Container(
      margin: EdgeInsets.only(
        right: MediaQuery.of(context).size.width * 0.01,
      ),
      child: TaskField(
        controller: dateController,
        focusNode: dateFocus,
        isMember: false,
        onPressed: () async {
          DateTime? picked = await Utils.showDate(context);
          if (picked != null) {
            setState(() {
              dateController.text = "${picked.day}/${picked.month}/${picked.year}";
            });
          }
        },
        deadline: true,
        title: ViLabels.date,
        NoOfLine: 1,
      ),
    );
    
    final timeFieldContainer = Container(
      margin: EdgeInsets.only(
        left: MediaQuery.of(context).size.width * 0.01,
      ),
      child: TaskField(
        controller: timeController,
        focusNode: timeFocus,
        isMember: false,
        onPressed: () async {
          TimeOfDay? selectedTime = await showTimePicker(
              context: context, initialTime: TimeOfDay.now());
          if (selectedTime != null) {
            setState(() {
              timeController.text = "${selectedTime.hour}:${selectedTime.minute} ${selectedTime.period.name}";
            });
          }
        },
        deadline: true,
        title: ViLabels.time,
        NoOfLine: 1,
      ),
    );
    
    // Xử lý lưu form
    void handleSave() async {
      // Kiểm tra xem đã chọn người được giao chưa
      if (_selectedMembers.isEmpty) {
        Utils.showtoast("Vui lòng chọn ít nhất một người để giao việc");
        return;
      }
      
      // Kiểm tra các trường bắt buộc khác
      if (taskController.text.isEmpty) {
        Utils.showtoast("Vui lòng nhập tên công việc");
        return;
      }
      
      if (dateController.text.isEmpty || timeController.text.isEmpty) {
        Utils.showtoast("Vui lòng chọn thời hạn cho công việc");
        return;
      }
      
      // Kiểm tra tất cả thành viên được giao có trong dự án không
      final String projectId = projectController.projectId.string;
      for (String memberEmail in _selectedMembers) {
        final bool isInProject = await UserValidationService.isUserInProject(memberEmail, projectId);
        if (!isInProject) {
          Utils.showtoast("Thành viên $memberEmail không thuộc dự án này.\nChỉ có thể giao việc cho thành viên trong dự án.");
          return;
        }
      }
      
      // In ra danh sách thành viên để debug
      print("Thành viên được giao: $_selectedMembers");
      
      // Nếu tất cả điều kiện đã được đáp ứng, thêm task
      BlocProvider.of<TaskBloc>(context).add(AddTasks(
          taskName: taskController.text,
          taskDescription: descriptionController.text,
          deadlineDate: dateController.text,
          deadlineTime: timeController.text,
          member: List.from(_selectedMembers), // Tạo bản sao để tránh tham chiếu
          priority: selectedPriority,
          isRecurring: isRecurring,
          recurringInterval: isRecurring ? selectedRecurringInterval : ''));

      project().sendDeadlineReminder();
    }

    return header(
      child: MultiBlocListener(
        listeners: [
          BlocListener<MemberBloc, MembersStates>(
            listener: (context, state) {
              // Cập nhật danh sách thành viên khi state thay đổi
              if (state is MemberAdded) {
                setState(() {
                  _selectedMembers.clear();
                  _selectedMembers.addAll(state.members);
                });
              } else if (state is MemberRemoved) {
                setState(() {
                  _selectedMembers.clear();
                  _selectedMembers.addAll(state.members);
                });
              } else if (state is AllMembersAdded) {
                setState(() {
                  _selectedMembers.clear();
                });
              }
            },
          ),
          BlocListener<TaskBloc, TaskStates>(
            listener: (context, state) {
              if (state is TaskAdded) {
                BlocProvider.of<MemberBloc>(context).add(AddAllMember());
                taskController.clear();
                descriptionController.clear();
                dateController.clear();
                timeController.clear();
                Navigator.of(context).pop();
                Utils.showSnackBar("Công việc đã được thêm vào dự án");
              } else if (state is ErrorState) {
                Utils.showSnackBar("Lỗi: ${state.message}");
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.arrow_back_ios)),
                  Container(
                    alignment: Alignment.topLeft,
                    child: text(
                      title: ViLabels.addTask,
                      align: TextAlign.start,
                      color: AppColors.black,
                      fontSize: MediaQuery.of(context).size.width * 0.06,
                      fontWeight: AppFonts.semiBold,
                    ),
                  ),
                ],
              ),
              Container(
                alignment: Alignment.topLeft,
                padding: EdgeInsets.symmetric(
                  vertical: MediaQuery.of(context).size.height * 0.01,
                ),
                child: Row(
                  children: [
                    text(
                      title: ViLabels.tasks,
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      fontWeight: AppFonts.semiBold,
                      color: AppColors.black,
                      align: TextAlign.start,
                    ),
                    Text(" *", style: TextStyle(color: Colors.red, fontSize: MediaQuery.of(context).size.width * 0.05)),
                  ],
                ),
              ),
              taskField,
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.02,
                  bottom: MediaQuery.of(context).size.height * 0.01,
                ),
                alignment: Alignment.topLeft,
                child: text(
                  title: ViLabels.description,
                  fontSize: MediaQuery.of(context).size.width * 0.05,
                  fontWeight: AppFonts.semiBold,
                  color: AppColors.black,
                  align: TextAlign.start,
                ),
              ),
              descriptionField,
              Container(
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.02,
                  bottom: MediaQuery.of(context).size.height * 0.01,
                ),
                child: text(
                  title: 'Mức độ ưu tiên',
                  fontSize: MediaQuery.of(context).size.width * 0.05,
                  fontWeight: AppFonts.semiBold,
                  color: AppColors.black,
                  align: TextAlign.start,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedPriority,
                    items: [
                      DropdownMenuItem(
                        value: 'low',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text('Thấp'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'normal',
                        child: Row(
                          children: [
                            Icon(Icons.remove, color: Colors.grey, size: 20),
                            SizedBox(width: 8),
                            Text('Bình thường'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text('Cao'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'urgent',
                        child: Row(
                          children: [
                            Icon(Icons.priority_high, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Khẩn cấp'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          selectedPriority = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              Container(
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.02,
                  bottom: MediaQuery.of(context).size.height * 0.01,
                ),
                child: Row(
                  children: [
                    text(
                      title: ViLabels.deadline,
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      fontWeight: AppFonts.semiBold,
                      color: AppColors.black,
                      align: TextAlign.start,
                    ),
                    Text(" *", style: TextStyle(color: Colors.red, fontSize: MediaQuery.of(context).size.width * 0.05)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: dateFieldContainer,
                  ),
                  Expanded(
                    child: timeFieldContainer,
                  ),
                ],
              ),
              SwitchListTile(
                title: Text('Lặp lại công việc'),
                subtitle: Text('Tự động tạo công việc lặp lại sau khi hoàn thành'),
                value: isRecurring,
                activeColor: AppColors.primaryColor,
                contentPadding: EdgeInsets.symmetric(horizontal: 0),
                onChanged: (bool value) {
                  setState(() {
                    isRecurring = value;
                  });
                },
              ),
              if (isRecurring) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  margin: EdgeInsets.only(bottom: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedRecurringInterval,
                      items: [
                        DropdownMenuItem(value: 'daily', child: Text('Hàng ngày')),
                        DropdownMenuItem(value: 'weekly', child: Text('Hàng tuần')),
                        DropdownMenuItem(value: 'monthly', child: Text('Hàng tháng')),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            selectedRecurringInterval = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
              Container(
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.02,
                  bottom: MediaQuery.of(context).size.height * 0.01,
                ),
                child: Row(
                  children: [
                    text(
                      title: ViLabels.assignedTo,
                      align: TextAlign.start,
                      color: AppColors.black,
                      fontSize: MediaQuery.of(context).size.width * 0.05,
                      fontWeight: AppFonts.semiBold,
                    ),
                    Text(" *", style: TextStyle(color: Colors.red, fontSize: MediaQuery.of(context).size.width * 0.05)),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 8),
                child: text(
                  title: "Nhập email và chọn từ gợi ý để thêm thành viên",
                  fontSize: MediaQuery.of(context).size.width * 0.035,
                  fontWeight: AppFonts.normal,
                  color: AppColors.grey,
                  align: TextAlign.start,
                ),
              ),
              TypeAheadField(
                builder: (context, assignedToController, focusNode) {
                  return TextField(
                    controller: assignedToController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                        borderSide: BorderSide(
                          color: AppColors.grey,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                        borderSide: const BorderSide(
                          color: AppColors.grey,
                        ),
                      ),
                      hintText: ViLabels.members_lowercase,
                    ),
                  );
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    tileColor: AppColors.white,
                    title: Text(suggestion),
                  );
                },
                onSelected: (value) {
                  print("Thêm thành viên: $value");
                  // Thêm vào MemberBloc để cập nhật UI
                  BlocProvider.of<MemberBloc>(context).add(AddMember(value));
                  // Thêm trực tiếp vào danh sách _selectedMembers
                  setState(() {
                    if (!_selectedMembers.contains(value)) {
                      _selectedMembers.add(value);
                    }
                  });
                  assignedToController.clear();
                },
                suggestionsCallback: (pattern) {
                  return projectController.members
                      .where((member) =>
                          member.toLowerCase().contains(pattern.toLowerCase()))
                      .toList();
                },
              ),
              BlocBuilder<MemberBloc, MembersStates>(builder: (context, state) {
                if (state is MemberAdded) {
                  print(state.members.length);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.members.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 8, bottom: 8),
                          child: text(
                            title: "Thành viên đã chọn:",
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                            fontWeight: AppFonts.medium,
                            color: AppColors.black,
                            align: TextAlign.start,
                          ),
                        ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: state.members.isNotEmpty ? Border.all(color: AppColors.grey.withOpacity(0.3)) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            state.members.length,
                            (index) => MemberChips(
                              memberEmail: state.members[index],
                              onDelete: () {
                                BlocProvider.of<MemberBloc>(context)
                                    .add(RemoveMember(index));
                              }
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (state is MemberRemoved) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.members.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 8, bottom: 8),
                          child: text(
                            title: "Thành viên đã chọn:",
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                            fontWeight: AppFonts.medium,
                            color: AppColors.black,
                            align: TextAlign.start,
                          ),
                        ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: state.members.isNotEmpty ? Border.all(color: AppColors.grey.withOpacity(0.3)) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            state.members.length,
                            (index) => MemberChips(
                              memberEmail: state.members[index],
                              onDelete: () {
                                BlocProvider.of<MemberBloc>(context)
                                    .add(RemoveMember(index));
                              }
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Container();
                }
              }),
              Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.01,
                ),
                width: MediaQuery.of(context).size.width,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.workspaceGradientColor1[1],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: handleSave,
                  child: text(
                    title: ViLabels.save,
                    fontSize: MediaQuery.of(context).size.width * 0.04,
                    fontWeight: AppFonts.bold,
                    color: AppColors.black,
                    align: TextAlign.start,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
