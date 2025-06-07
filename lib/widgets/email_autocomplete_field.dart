import 'package:flutter/material.dart';
import 'package:mission_master/data/services/user_validation_service.dart';
import 'package:mission_master/constants/colors.dart';

class EmailAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final Function(String)? onEmailSelected;
  final Function(bool)? onValidationChanged;
  final bool showValidationIndicator;
  final String? projectId; // Để validate thành viên trong dự án

  const EmailAutocompleteField({
    Key? key,
    required this.controller,
    this.hintText,
    this.onEmailSelected,
    this.onValidationChanged,
    this.showValidationIndicator = true,
    this.projectId,
  }) : super(key: key);

  @override
  State<EmailAutocompleteField> createState() => _EmailAutocompleteFieldState();
}

class _EmailAutocompleteFieldState extends State<EmailAutocompleteField> {
  List<String> _suggestedEmails = [];
  bool _isLoadingSuggestions = false;
  bool _isValidEmail = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _loadRegisteredEmails();
    widget.controller.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onEmailChanged);
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
    final email = widget.controller.text.trim();
    if (email.isEmpty) {
      setState(() {
        _isValidEmail = false;
        _validationMessage = null;
      });
      if (widget.onValidationChanged != null) {
        widget.onValidationChanged!(false);
      }
      return;
    }

    // Kiểm tra format email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _isValidEmail = false;
        _validationMessage = 'Email không hợp lệ';
      });
      if (widget.onValidationChanged != null) {
        widget.onValidationChanged!(false);
      }
      return;
    }

    // Kiểm tra email có trong hệ thống
    final isRegistered = await UserValidationService.isEmailRegistered(email);
    if (!isRegistered) {
      setState(() {
        _isValidEmail = false;
        _validationMessage = 'Email chưa đăng ký trong hệ thống';
      });
      if (widget.onValidationChanged != null) {
        widget.onValidationChanged!(false);
      }
      return;
    }

    // Kiểm tra thêm nếu có projectId (email có trong dự án không)
    if (widget.projectId != null) {
      final isInProject = await UserValidationService.isUserInProject(email, widget.projectId!) ||
                         await UserValidationService.isUserInEnterpriseProject(email, widget.projectId!);
      if (!isInProject) {
        setState(() {
          _isValidEmail = false;
          _validationMessage = 'Email không thuộc dự án này';
        });
        if (widget.onValidationChanged != null) {
          widget.onValidationChanged!(false);
        }
        return;
      }
    }

    setState(() {
      _isValidEmail = true;
      _validationMessage = 'Email hợp lệ ✓';
    });
    if (widget.onValidationChanged != null) {
      widget.onValidationChanged!(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _suggestedEmails.take(5);
        }
        return _suggestedEmails.where((email) =>
            email.toLowerCase().contains(textEditingValue.text.toLowerCase())).take(5);
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        if (widget.onEmailSelected != null) {
          widget.onEmailSelected!(selection);
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        // Đồng bộ controller
        if (controller.text != widget.controller.text) {
          controller.text = widget.controller.text;
        }
        controller.addListener(() {
          if (widget.controller.text != controller.text) {
            widget.controller.text = controller.text;
          }
        });
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          autofillHints: [AutofillHints.email],
          decoration: InputDecoration(
            suffixIcon: widget.showValidationIndicator
                ? (_isLoadingSuggestions 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isValidEmail ? Icons.check_circle : Icons.email,
                        color: _isValidEmail ? Colors.green : Colors.grey,
                      ))
                : null,
            hintText: widget.hintText ?? "Chọn email từ danh sách hoặc nhập email",
            helperText: widget.showValidationIndicator ? _validationMessage : null,
            helperStyle: TextStyle(
              color: _isValidEmail ? Colors.green : Colors.red,
              fontSize: size.width * 0.03,
            ),
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: size.width * 0.04,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isValidEmail ? Colors.green : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isValidEmail ? Colors.green : AppColors.primaryColor,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red),
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
                    title: Text(
                      option,
                      style: TextStyle(fontSize: 14),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
} 