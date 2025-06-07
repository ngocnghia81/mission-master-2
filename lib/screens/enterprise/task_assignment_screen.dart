import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/data/models/task_model.dart';
import 'package:mission_master/data/models/resource_model.dart';
import 'package:mission_master/data/repositories/task_repository.dart';
import 'package:mission_master/data/repositories/resource_repository.dart';
import 'package:mission_master/data/providers/task_data_provider.dart';
import 'package:mission_master/data/services/user_validation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TaskAssignmentScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  
  const TaskAssignmentScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _TaskAssignmentScreenState createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  late final TaskRepository _taskRepository;
  late final ResourceRepository _resourceRepository;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  List<Task> _tasks = [];
  List<String> _projectMembers = [];
  List<String> _selectedMembers = [];
  String _selectedPriority = 'normal';
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay(hour: 12, minute: 0);
  
  // Resource allocation
  List<Resource> _availableResources = [];
  List<Map<String, dynamic>> _selectedResources = [];
  
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }
  
  Future<void> _initializeRepository() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _taskRepository = TaskRepository(
        taskDataProvider: TaskDataProvider(prefs),
      );
      _resourceRepository = ResourceRepository();
    });
    
    await _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('TaskAssignment: Loading data for project: ${widget.projectId}');
      
      final tasks = await _taskRepository.getTasksByProjectId(widget.projectId);
      final members = await _taskRepository.getProjectMembers(widget.projectId);
      final resources = await _resourceRepository.getProjectResources(widget.projectId);
      
      print('TaskAssignment: Loaded ${members.length} members: $members');
      
      setState(() {
        _tasks = tasks;
        _projectMembers = members;
        _availableResources = resources;
        _isLoading = false;
      });
    } catch (e) {
      print('TaskAssignment: Error loading data: $e');
      _showErrorSnackBar('Không thể tải dữ liệu: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _memberController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
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
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
    }
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _selectedTime.format(context);
      });
    }
  }
  
  void _addMember(String email) async {
    if (!_selectedMembers.contains(email)) {
      // Kiểm tra email có trong dự án không
      bool isProjectMember = false;
      try {
        isProjectMember = await UserValidationService.isUserInProject(email, widget.projectId) ||
                         await UserValidationService.isUserInEnterpriseProject(email, widget.projectId);
      } catch (e) {
        print('Lỗi khi kiểm tra thành viên: $e');
      }
      
      if (!isProjectMember) {
        _showErrorSnackBar('Email "$email" không phải thành viên của dự án này.\nChỉ có thể giao việc cho thành viên trong dự án.');
        return;
      }
      
      setState(() {
        _selectedMembers.add(email);
      });
      _memberController.clear();
    } else {
      _showErrorSnackBar('Thành viên này đã được chọn');
    }
  }
  
  void _removeMember(int index) {
    setState(() {
      _selectedMembers.removeAt(index);
    });
  }
  
  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedMembers.isEmpty) {
      _showErrorSnackBar('Vui lòng chọn ít nhất một thành viên');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final newTask = Task(
        id: taskId,
        title: _titleController.text,
        description: _descriptionController.text,
        deadlineDate: _dateController.text,
        deadlineTime: _timeController.text,
        members: _selectedMembers,
        status: 'pending',
        projectName: widget.projectName,
        projectId: widget.projectId,
        priority: _selectedPriority,
        isRecurring: false,
        recurringInterval: '',
        createdAt: DateTime.now(),
        assignedTo: _selectedMembers,
        dueDate: _selectedDate,
        estimatedCost: _getTotalResourceCost(),
      );
      
      // 1. Tạo task trước
      await _taskRepository.createTask(newTask);
      
      // 2. Phân bổ tài nguyên và cập nhật ngân sách
      if (_selectedResources.isNotEmpty) {
        for (final resourceItem in _selectedResources) {
          final resource = resourceItem['resource'] as Resource;
          final quantity = resourceItem['quantity'] as int;
          
          print('Allocating resource: ${resource.name}, quantity: $quantity');
          
          // Tự động phân bổ vào budget item đầu tiên có đủ tiền
          final success = await _resourceRepository.allocateResourceAndUpdateBudget(
            projectId: widget.projectId,
            resourceId: resource.id,
            taskId: taskId,
            allocatedUnits: quantity,
            allocatedBy: _selectedMembers.first, // Use first assigned member
            startDate: _selectedDate,
            endDate: _selectedDate.add(Duration(days: 7)), // Default to 1 week duration
            budgetCategory: 'development', // Sử dụng category "development" mà user đã tạo
          );
          
          if (success) {
            print('Successfully allocated ${resource.name} and updated budget');
          } else {
            print('Failed to allocate ${resource.name}');
          }
        }
      }
      
      _showSuccessSnackBar('Nhiệm vụ và tài nguyên đã được phân bổ thành công');
      _resetForm();
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Không thể tạo nhiệm vụ: $e');
      print('Error creating task: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _mapResourceTypeToBudgetCategory(String resourceType) {
    switch (resourceType) {
      case 'human':
        return 'development'; // Nhân lực -> Phát triển
      case 'equipment':
        return 'development'; // Thiết bị -> Phát triển (vì user tạo budget "Phát triển")
      case 'material':
        return 'development'; // Vật liệu -> Phát triển
      default:
        return 'development'; // Mặc định cũng về Phát triển
    }
  }
  
  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _dateController.clear();
    _timeController.clear();
    setState(() {
      _selectedMembers = [];
      _selectedPriority = 'normal';
      _selectedResources = [];
    });
  }

  void _addResource(Resource resource, int quantity) {
    if (quantity <= 0) return;
    
    final existingIndex = _selectedResources.indexWhere(
      (selected) => selected['resource'].id == resource.id
    );
    
    if (existingIndex != -1) {
      setState(() {
        _selectedResources[existingIndex]['quantity'] = quantity;
      });
    } else {
      setState(() {
        _selectedResources.add({
          'resource': resource,
          'quantity': quantity,
          'cost': resource.costPerUnit * quantity,
        });
      });
    }
  }

  void _removeResource(int index) {
    setState(() {
      _selectedResources.removeAt(index);
    });
  }

  double _getTotalResourceCost() {
    return _selectedResources.fold(0.0, (sum, item) => sum + item['cost']);
  }

  void _showResourceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Phân bổ tài nguyên'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _availableResources.length,
            itemBuilder: (context, index) {
              final resource = _availableResources[index];
              final TextEditingController quantityController = TextEditingController();
              
              return Card(
                child: ListTile(
                  title: Text(resource.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${resource.costPerUnit} VND/${resource.costUnit}'),
                      Text('Còn lại: ${resource.availableUnits - resource.allocatedUnits}'),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'SL',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, size: 20),
                          onPressed: () {
                            final quantity = int.tryParse(quantityController.text) ?? 0;
                            if (quantity > 0) {
                              _addResource(resource, quantity);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTask(Task task) async {
    // Pre-fill form với dữ liệu của task hiện tại
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _dateController.text = task.deadlineDate;
    _timeController.text = task.deadlineTime;
    
    setState(() {
      _selectedMembers = List.from(task.members);
      _selectedPriority = task.priority;
      _selectedDate = task.dueDate ?? DateTime.now().add(const Duration(days: 1));
    });

    // Scroll đến form
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chỉnh sửa nhiệm vụ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tên nhiệm vụ',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô tả nhiệm vụ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateTask(task);
              Navigator.pop(context);
            },
            child: Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTask(Task originalTask) async {
    if (_titleController.text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập tên nhiệm vụ');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTask = Task(
        id: originalTask.id,
        title: _titleController.text,
        description: _descriptionController.text,
        deadlineDate: _dateController.text,
        deadlineTime: _timeController.text,
        members: _selectedMembers,
        status: originalTask.status,
        projectName: widget.projectName,
        projectId: widget.projectId,
        priority: _selectedPriority,
        isRecurring: originalTask.isRecurring,
        recurringInterval: originalTask.recurringInterval,
        createdAt: originalTask.createdAt,
        assignedTo: _selectedMembers,
        dueDate: _selectedDate,
      );

      await _taskRepository.updateTask(updatedTask);
      
      _showSuccessSnackBar('Nhiệm vụ đã được cập nhật thành công');
      _resetForm();
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Không thể cập nhật nhiệm vụ: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa nhiệm vụ "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _taskRepository.deleteTask(task.id);
        _showSuccessSnackBar('Nhiệm vụ đã được xóa thành công');
        await _loadData();
      } catch (e) {
        _showErrorSnackBar('Không thể xóa nhiệm vụ: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phân công nhiệm vụ - ${widget.projectName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Danh sách nhiệm vụ hiện tại
                  Text(
                    'Nhiệm vụ hiện tại',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  _tasks.isEmpty
                      ? Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'Chưa có nhiệm vụ nào được tạo',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  task.title,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hạn: ${task.deadlineDate} ${task.deadlineTime}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Trạng thái: ${_getStatusLabel(task.status)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Người thực hiện: ${task.members.join(", ")}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                                leading: _getPriorityIcon(task.priority),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editTask(task);
                                    } else if (value == 'delete') {
                                      _deleteTask(task);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Chỉnh sửa'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Xóa'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  
                  const SizedBox(height: 24),
                  
                  // Form tạo nhiệm vụ mới
                  Text(
                    'Tạo nhiệm vụ mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Tên nhiệm vụ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập tên nhiệm vụ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Mô tả nhiệm vụ',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          'Mức độ ưu tiên',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedPriority,
                          items: [
                            DropdownMenuItem(
                              value: 'low',
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_downward, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Thấp'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'normal',
                              child: Row(
                                children: [
                                  Icon(Icons.remove, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Bình thường'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_upward, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Cao'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Row(
                                children: [
                                  Icon(Icons.priority_high, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Khẩn cấp'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedPriority = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          'Thời hạn',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                onTap: _selectDate,
                                decoration: InputDecoration(
                                  labelText: 'Ngày',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng chọn ngày';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _timeController,
                                readOnly: true,
                                onTap: _selectTime,
                                decoration: InputDecoration(
                                  labelText: 'Giờ',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng chọn giờ';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Phân công cho',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh, size: 20),
                              onPressed: _loadData,
                              tooltip: 'Làm mới danh sách',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Dropdown để chọn thành viên
                        if (_projectMembers.isEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.orange[50],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange[600]),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Không tìm thấy thành viên nào trong dự án này. Vui lòng thêm thành viên vào dự án trước.',
                                    style: TextStyle(color: Colors.orange[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Chọn thành viên (${_projectMembers.length} thành viên)',
                              border: OutlineInputBorder(),
                            ),
                            hint: Text('Chọn thành viên từ danh sách'),
                            value: null,
                            items: _projectMembers.map((member) {
                              return DropdownMenuItem<String>(
                                value: member,
                                child: Text(member),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _addMember(value);
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        
                        if (_selectedMembers.isNotEmpty) ...[
                          Text(
                            'Thành viên đã chọn:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: List.generate(_selectedMembers.length, (index) {
                              return Chip(
                                label: Text(_selectedMembers[index]),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeMember(index),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Resource allocation section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Phân bổ tài nguyên',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showResourceSelectionDialog,
                              icon: Icon(Icons.add, size: 18),
                              label: Text('Thêm tài nguyên'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        if (_selectedResources.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.all(12),
                            child: Column(
                              children: [
                                ...List.generate(_selectedResources.length, (index) {
                                  final item = _selectedResources[index];
                                  final resource = item['resource'] as Resource;
                                  final quantity = item['quantity'] as int;
                                  final cost = item['cost'] as double;
                                  
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                resource.name,
                                                style: TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              Text(
                                                '$quantity ${resource.costUnit} × ${resource.costPerUnit} = ${cost.toStringAsFixed(0)} VND',
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete, size: 18, color: Colors.red),
                                          onPressed: () => _removeResource(index),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tổng chi phí:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${_getTotalResourceCost().toStringAsFixed(0)} VND',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _createTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Tạo nhiệm vụ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _getPriorityIcon(String priority) {
    switch (priority) {
      case 'low':
        return Icon(Icons.arrow_downward, color: Colors.blue);
      case 'high':
        return Icon(Icons.arrow_upward, color: Colors.orange);
      case 'urgent':
        return Icon(Icons.priority_high, color: Colors.red);
      default:
        return Icon(Icons.remove, color: Colors.grey);
    }
  }
  
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'in_progress':
        return 'Đang thực hiện';
      case 'completed':
        return 'Hoàn thành';
      default:
        return status;
    }
  }
}
