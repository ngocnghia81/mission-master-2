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
import 'package:mission_master/data/services/user_validation_service.dart';
import 'package:mission_master/injection/database.dart';
import 'package:mission_master/widgets/text.dart';
import 'package:mission_master/widgets/workspace/header.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController emailController = TextEditingController();
  var project = locator<Database>();
  List<String> _suggestedEmails = [];
  bool _isLoadingSuggestions = false;
  bool _isValidEmail = false;
  String? _emailValidationMessage;

  @override
  void initState() {
    super.initState();
    _loadRegisteredEmails();
    emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    emailController.removeListener(_onEmailChanged);
    emailController.dispose();
    super.dispose();
  }

  void _loadRegisteredEmails() async {
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      final emails = await UserValidationService.getRegisteredEmails();
      setState(() {
        _suggestedEmails = emails;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  void _onEmailChanged() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _isValidEmail = false;
        _emailValidationMessage = null;
      });
      return;
    }

    // Kiểm tra format email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _isValidEmail = false;
        _emailValidationMessage = 'Email không hợp lệ';
      });
      return;
    }

    // Kiểm tra email có trong hệ thống
    final isRegistered = await UserValidationService.isEmailRegistered(email);
    setState(() {
      _isValidEmail = isRegistered;
      _emailValidationMessage = isRegistered 
          ? 'Email hợp lệ ✓' 
          : 'Email chưa đăng ký trong hệ thống';
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
          // Email input with autocomplete
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _suggestedEmails.take(5);
              }
              return _suggestedEmails.where((email) =>
                  email.toLowerCase().contains(textEditingValue.text.toLowerCase())).take(5);
            },
            onSelected: (String selection) {
              emailController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              // Đồng bộ controller
              if (controller.text != emailController.text) {
                controller.text = emailController.text;
              }
              controller.addListener(() {
                if (emailController.text != controller.text) {
                  emailController.text = controller.text;
                }
              });
              
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                autofillHints: [AutofillHints.email],
                decoration: InputDecoration(
                  suffixIcon: _isLoadingSuggestions 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isValidEmail ? Icons.check_circle : Icons.person_add_alt_1_outlined,
                          color: _isValidEmail ? Colors.green : AppColors.grey,
                        ),
                  hintText: "Chọn email từ danh sách hoặc nhập email",
                  helperText: _emailValidationMessage,
                  helperStyle: TextStyle(
                    color: _isValidEmail ? Colors.green : Colors.red,
                    fontSize: size.width * 0.03,
                  ),
                  hintStyle: TextStyle(
                    color: AppColors.grey,
                    fontSize: size.width * 0.04,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                    borderSide: BorderSide(
                      color: _isValidEmail ? Colors.green : AppColors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(size.width * 0.03),
                    borderSide: BorderSide(
                      color: _isValidEmail ? Colors.green : AppColors.primaryColor,
                    ),
                  ),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: Container(
                    width: size.width * 0.9,
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.person, size: 20),
                          title: Text(option),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
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
                stream: project.getMembersOfProject(),
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
                onPressed: _isValidEmail ? () {
                  BlocProvider.of<AddMemberToProjectBloc>(context).add(
                      AddMemberToProject(memberEmail: emailController.text));
                  emailController.clear();
                  setState(() {
                    _isValidEmail = false;
                    _emailValidationMessage = null;
                  });
                } : null,
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
