import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/models/enterprise_project_model.dart';
import 'package:mission_master/data/repositories/enterprise_project_repository.dart';
import 'package:mission_master/data/services/user_validation_service.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnterpriseProjectScreen extends StatefulWidget {
  final EnterpriseProject? project; // null for create, not null for edit

  const EnterpriseProjectScreen({Key? key, this.project}) : super(key: key);

  @override
  _EnterpriseProjectScreenState createState() => _EnterpriseProjectScreenState();
}

class _EnterpriseProjectScreenState extends State<EnterpriseProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _memberEmailController = TextEditingController();
  
  late EnterpriseProjectRepository _repository;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  List<String> _memberEmails = [];
  String _selectedProjectType = 'standard';
  String _selectedStatus = 'planning';
  bool _isEnterprise = true;
  bool _isLoading = false;
  bool _isEditMode = false;
  
  final List<String> _projectTypes = [
    'standard',
    'agile',
    'waterfall',
    'kanban',
    'scrum',
  ];

  final List<String> _projectStatuses = [
    'planning',
    'active',
    'on_hold',
    'completed',
    'cancelled',
  ];
  
  @override
  void initState() {
    super.initState();
    _isEditMode = widget.project != null;
    _initializeRepository();
    if (_isEditMode) {
      _populateFieldsForEdit();
    }
  }

  Future<void> _initializeRepository() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = EnterpriseProjectRepository(prefs);
  }



  void _populateFieldsForEdit() {
    final project = widget.project!;
    _nameController.text = project.name;
    _descriptionController.text = project.description;
    _budgetController.text = project.budget.toString();
    _startDate = project.startDate;
    _endDate = project.endDate;
    _memberEmails = List.from(project.memberEmails);
    _selectedProjectType = project.type;
    _selectedStatus = project.status;
    _isEnterprise = project.isEnterprise;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _memberEmailController.dispose();
    super.dispose();
  }
  
  void _addMember() async {
    final email = _memberEmailController.text.trim();
    
    if (email.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập email');
      return;
    }
    
    // Kiểm tra format email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showErrorSnackBar('Email không hợp lệ');
      return;
    }
    
    // Kiểm tra email có trong hệ thống
    final bool isEmailRegistered = await UserValidationService.isEmailRegistered(email);
    if (!isEmailRegistered) {
      _showErrorSnackBar('Email "$email" chưa đăng ký trong hệ thống.\nChỉ có thể thêm những email đã có tài khoản.');
      return;
    }
    
    // Kiểm tra trùng lặp
    if (_memberEmails.contains(email)) {
      _showErrorSnackBar('Email đã tồn tại trong danh sách');
      return;
    }
    
    setState(() {
      _memberEmails.add(email);
      _memberEmailController.clear();
    });
    
    _showSuccessSnackBar('Đã thêm thành viên: $email');
  }
  
  void _removeMember(int index) {
    setState(() {
      _memberEmails.removeAt(index);
    });
  }
  
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Đảm bảo ngày kết thúc luôn sau ngày bắt đầu
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }
  
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365 * 5)),
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_memberEmails.isEmpty) {
      _showErrorSnackBar('Vui lòng thêm ít nhất một thành viên');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final projectId = _isEditMode ? widget.project!.id : DateTime.now().millisecondsSinceEpoch.toString();
      final budget = double.tryParse(_budgetController.text) ?? 0.0;
      
      final project = EnterpriseProject(
        id: projectId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedProjectType,
        startDate: _startDate,
        endDate: _endDate,
        budget: budget,
        memberEmails: _memberEmails,
        status: _selectedStatus,
        createdBy: 'current_user@example.com', // TODO: Get from auth
        createdAt: _isEditMode ? widget.project!.createdAt : DateTime.now(),
        isEnterprise: _isEnterprise,
      );
      
      if (_isEditMode) {
        await _repository.updateProject(project);
        _showSuccessSnackBar('Dự án đã được cập nhật thành công!');
      } else {
        await _repository.createProject(project);
        _showSuccessSnackBar('Dự án đã được tạo thành công!');
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Return success result
      Navigator.of(context).pop(true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Lỗi: Không thể lưu dự án - $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Chỉnh sửa dự án Enterprise' : 'Tạo dự án Enterprise'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin cơ bản
                    const Text(
                      'Thông tin cơ bản',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên dự án',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tên dự án';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả dự án',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mô tả dự án';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Loại dự án
                    DropdownButtonFormField<String>(
                      value: _selectedProjectType,
                      decoration: const InputDecoration(
                        labelText: 'Loại dự án',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _projectTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_getProjectTypeLabel(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Trạng thái (chỉ hiển thị khi edit)
                    if (_isEditMode) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái dự án',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: _projectStatuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(_getProjectStatusLabel(status)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Cài đặt Enterprise
                    Row(
                      children: [
                        const Text(
                          'Tính năng Enterprise',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isEnterprise,
                          onChanged: (value) {
                            setState(() {
                              _isEnterprise = value;
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_isEnterprise) ...[
                      // Ngân sách
                      TextFormField(
                        controller: _budgetController,
                        decoration: const InputDecoration(
                          labelText: 'Ngân sách (VND)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      
                      // Thời gian dự án
                      const Text(
                        'Thời gian dự án',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectStartDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Ngày bắt đầu',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_startDate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _selectEndDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Ngày kết thúc',
                                  prefixIcon: Icon(Icons.event),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_endDate),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Thành viên dự án
                    const Text(
                      'Thành viên dự án',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _memberEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Email thành viên',
                              border: OutlineInputBorder(),
                              hintText: 'Nhập email thành viên',
                              prefixIcon: Icon(Icons.person_add),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Thêm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Danh sách thành viên
                    if (_memberEmails.isNotEmpty) ...[
                      const Text(
                        'Danh sách thành viên:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: List.generate(_memberEmails.length, (index) {
                          return Chip(
                            label: Text(_memberEmails[index]),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeMember(index),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Nút lưu dự án
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon: Icon(_isEditMode ? Icons.save : Icons.add),
                        label: Text(_isEditMode ? 'Cập nhật dự án' : 'Tạo dự án'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  String _getProjectTypeLabel(String type) {
    switch (type) {
      case 'standard': return 'Tiêu chuẩn';
      case 'agile': return 'Agile';
      case 'waterfall': return 'Waterfall';
      case 'kanban': return 'Kanban';
      case 'scrum': return 'Scrum';
      default: return type;
    }
  }

  String _getProjectStatusLabel(String status) {
    switch (status) {
      case 'planning': return 'Lập kế hoạch';
      case 'active': return 'Đang thực hiện';
      case 'on_hold': return 'Tạm dừng';
      case 'completed': return 'Hoàn thành';
      case 'cancelled': return 'Đã hủy';
      default: return status;
    }
  }
}
