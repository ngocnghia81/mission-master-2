import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:mission_master/data/models/resource_model.dart';
import 'package:mission_master/data/repositories/resource_repository.dart';
import 'package:mission_master/routes/routes.dart';

class ResourceManagementScreen extends StatefulWidget {
  final String projectId;
  
  const ResourceManagementScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  _ResourceManagementScreenState createState() => _ResourceManagementScreenState();
}

class _ResourceManagementScreenState extends State<ResourceManagementScreen> {
  final ResourceRepository _resourceRepository = ResourceRepository();
  List<Resource> _resources = [];
  List<ResourceAllocation> _allocations = [];
  Budget? _budget;
  bool _isLoading = true;
  
  // Controllers cho form tài nguyên
  final _resourceFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costPerUnitController = TextEditingController();
  final TextEditingController _costUnitController = TextEditingController();
  final TextEditingController _availableUnitsController = TextEditingController();
  String _selectedResourceType = 'human';
  Resource? _selectedResource;
  
  // Controllers cho form ngân sách
  final _budgetFormKey = GlobalKey<FormState>();
  final TextEditingController _totalBudgetController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final Map<String, TextEditingController> _categoryBudgetControllers = {
    'human': TextEditingController(),
    'equipment': TextEditingController(),
    'material': TextEditingController(),
    'other': TextEditingController(),
  };
  
  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }
  
  Future<void> _initializeAndLoadData() async {
    await _loadData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPerUnitController.dispose();
    _costUnitController.dispose();
    _availableUnitsController.dispose();
    _totalBudgetController.dispose();
    _currencyController.dispose();
    
    for (var controller in _categoryBudgetControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final resources = await _resourceRepository.getProjectResources(widget.projectId);
      final allocations = await _resourceRepository.getResourceAllocations(widget.projectId);
      
      // Đồng bộ ngân sách trước khi lấy dữ liệu
      await _resourceRepository.syncBudgetWithItems(widget.projectId);
      final budget = await _resourceRepository.getProjectBudget(widget.projectId);
      
      setState(() {
        _resources = resources;
        _allocations = allocations;
        _budget = budget;
        _isLoading = false;
        
        // Cập nhật các controller ngân sách
        if (budget != null) {
          _totalBudgetController.text = budget.totalBudget.toString();
          _currencyController.text = budget.currency;
          
          for (var entry in budget.categoryAllocation.entries) {
            if (_categoryBudgetControllers.containsKey(entry.key)) {
              _categoryBudgetControllers[entry.key]!.text = entry.value.toString();
            }
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể tải dữ liệu: $e');
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
  
  void _selectResource(Resource resource) {
    setState(() {
      _selectedResource = resource;
      _nameController.text = resource.name;
      _descriptionController.text = resource.description;
      _costPerUnitController.text = resource.costPerUnit.toString();
      _costUnitController.text = resource.costUnit;
      _availableUnitsController.text = resource.availableUnits.toString();
      _selectedResourceType = resource.type;
    });
  }
  
  void _clearResourceForm() {
    setState(() {
      _selectedResource = null;
      _nameController.clear();
      _descriptionController.clear();
      _costPerUnitController.clear();
      _costUnitController.clear();
      _availableUnitsController.clear();
      _selectedResourceType = 'human';
    });
  }
  
  Future<void> _saveResource() async {
    if (!_resourceFormKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final name = _nameController.text;
      final description = _descriptionController.text;
      final costPerUnit = double.parse(_costPerUnitController.text);
      final costUnit = _costUnitController.text;
      final availableUnits = int.parse(_availableUnitsController.text);
      
      if (_selectedResource == null) {
        // Tạo tài nguyên mới
        final newResource = Resource(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          description: description,
          type: _selectedResourceType,
          costPerUnit: costPerUnit,
          costUnit: costUnit,
          availableUnits: availableUnits,
          allocatedUnits: 0,
          projectId: widget.projectId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _resourceRepository.createResource(newResource);
        _showSuccessSnackBar('Tạo tài nguyên mới thành công');
      } else {
        // Cập nhật tài nguyên hiện có
        final updatedResource = _selectedResource!.copyWith(
          name: name,
          description: description,
          type: _selectedResourceType,
          costPerUnit: costPerUnit,
          costUnit: costUnit,
          availableUnits: availableUnits,
          updatedAt: DateTime.now(),
        );
        
        await _resourceRepository.updateResource(updatedResource);
        _showSuccessSnackBar('Cập nhật tài nguyên thành công');
      }
      
      _clearResourceForm();
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể lưu tài nguyên: $e');
    }
  }
  
  Future<void> _deleteResource(Resource resource) async {
    // Hiển thị hộp thoại xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa tài nguyên "${resource.name}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _resourceRepository.deleteResource(resource.id);
      
      if (success) {
        if (_selectedResource?.id == resource.id) {
          _clearResourceForm();
        }
        
        await _loadData();
        _showSuccessSnackBar('Xóa tài nguyên thành công');
      } else {
        _showErrorSnackBar('Không thể xóa tài nguyên: Tài nguyên đang được sử dụng');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể xóa tài nguyên: $e');
    }
  }
  
  Future<void> _updateBudget() async {
    if (!_budgetFormKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_budget == null) {
        _showErrorSnackBar('Không tìm thấy ngân sách dự án');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final totalBudget = double.parse(_totalBudgetController.text);
      final currency = _currencyController.text;
      
      // Tạo map phân bổ ngân sách theo danh mục
      final Map<String, double> categoryAllocation = {};
      for (var entry in _categoryBudgetControllers.entries) {
        if (entry.value.text.isNotEmpty) {
          categoryAllocation[entry.key] = double.parse(entry.value.text);
        } else {
          categoryAllocation[entry.key] = 0.0;
        }
      }
      
      // Tính tổng ngân sách đã phân bổ
      final allocatedBudget = categoryAllocation.values.fold(0.0, (sum, value) => sum + value);
      
      // Cập nhật ngân sách
      final updatedBudget = _budget!.copyWith(
        totalBudget: totalBudget,
        allocatedBudget: allocatedBudget,
        currency: currency,
        categoryAllocation: categoryAllocation,
        updatedAt: DateTime.now(),
      );
      
      await _resourceRepository.updateBudget(updatedBudget);
      _showSuccessSnackBar('Cập nhật ngân sách thành công');
      
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Không thể cập nhật ngân sách: $e');
    }
  }
  
  Widget _buildResourceList() {
    if (_resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có tài nguyên nào',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút + để thêm tài nguyên mới',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _resources.length,
      itemBuilder: (context, index) {
        final resource = _resources[index];
        final isSelected = _selectedResource?.id == resource.id;
        
        // Tính tổng chi phí của tài nguyên
        final totalCost = resource.getTotalCost();
        
        // Tính tỷ lệ sử dụng
        final utilizationRate = resource.availableUnits > 0
            ? (resource.allocatedUnits / resource.availableUnits) * 100
            : 0.0;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          color: isSelected ? AppColors.primaryLight : null,
          child: ListTile(
            title: Text(
              resource.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getResourceTypeLabel(resource.type)} • ${resource.costPerUnit} VND/${resource.costUnit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                LinearProgressIndicator(
                  value: resource.availableUnits > 0 
                      ? resource.allocatedUnits / resource.availableUnits 
                      : 0,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    utilizationRate > 90 
                        ? Colors.red 
                        : utilizationRate > 70 
                            ? Colors.orange 
                            : Colors.green,
                  ),
                ),
                Text(
                  'Sử dụng: ${resource.allocatedUnits}/${resource.availableUnits} • Chi phí: ${NumberFormat.compact().format(totalCost)} VND',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteResource(resource),
            ),
            onTap: () => _selectResource(resource),
          ),
        );
      },
    );
  }
  
  String _getResourceTypeLabel(String type) {
    switch (type) {
      case 'human': return 'Nhân lực';
      case 'equipment': return 'Thiết bị';
      case 'material': return 'Vật liệu';
      default: return 'Khác';
    }
  }
  
  Widget _buildResourceForm() {
    return Form(
      key: _resourceFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedResource == null ? 'Thêm tài nguyên mới' : 'Chỉnh sửa tài nguyên',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tên tài nguyên',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nhập tên tài nguyên';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nhập mô tả';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedResourceType,
            decoration: const InputDecoration(
              labelText: 'Loại tài nguyên',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: 'human', child: Text(_getResourceTypeLabel('human'))),
              DropdownMenuItem(value: 'equipment', child: Text(_getResourceTypeLabel('equipment'))),
              DropdownMenuItem(value: 'material', child: Text(_getResourceTypeLabel('material'))),
              DropdownMenuItem(value: 'other', child: Text(_getResourceTypeLabel('other'))),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedResourceType = value;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _costPerUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Chi phí/đơn vị',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nhập chi phí';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Số không hợp lệ';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _costUnitController,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    border: OutlineInputBorder(),
                    hintText: 'giờ, ngày...',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nhập đơn vị';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _availableUnitsController,
            decoration: const InputDecoration(
              labelText: 'Số lượng có sẵn',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nhập số lượng';
              }
              if (int.tryParse(value) == null) {
                return 'Nhập số nguyên';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: _clearResourceForm,
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ElevatedButton(
                  onPressed: _saveResource,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _selectedResource == null ? 'Thêm tài nguyên' : 'Cập nhật',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildBudgetForm() {
    if (_budget == null) {
      return const Center(
        child: Text('Không tìm thấy ngân sách dự án'),
      );
    }
    
    // Tính tỷ lệ sử dụng ngân sách
    final usagePercentage = _budget!.totalBudget > 0
        ? (_budget!.spentBudget / _budget!.totalBudget) * 100
        : 0.0;
    
    return Form(
      key: _budgetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quản lý ngân sách',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Hiển thị tổng quan về ngân sách
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng quan ngân sách',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Đã chi: ${NumberFormat.compact().format(_budget!.spentBudget)} ${_budget!.currency}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Còn lại: ${NumberFormat.compact().format(_budget!.getRemainingBudget())} ${_budget!.currency}',
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _budget!.totalBudget > 0 
                        ? _budget!.spentBudget / _budget!.totalBudget 
                        : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usagePercentage > 90 
                          ? Colors.red 
                          : usagePercentage > 70 
                              ? Colors.orange 
                              : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đã sử dụng ${usagePercentage.toStringAsFixed(1)}% ngân sách',
                    style: TextStyle(
                      fontSize: 12,
                      color: usagePercentage > 90 
                          ? Colors.red 
                          : usagePercentage > 70 
                              ? Colors.orange 
                              : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _totalBudgetController,
                  decoration: const InputDecoration(
                    labelText: 'Tổng ngân sách',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập tổng ngân sách';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Vui lòng nhập số hợp lệ';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _currencyController,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị tiền tệ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập đơn vị tiền tệ';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Phân bổ ngân sách theo danh mục',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Phân bổ ngân sách theo danh mục
          ...['human', 'equipment', 'material', 'other'].map((category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextFormField(
                controller: _categoryBudgetControllers[category],
                decoration: InputDecoration(
                  labelText: '${_getResourceTypeLabel(category)} (${_budget!.currency})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),
            );
          }).toList(),
          
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _updateBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cập nhật ngân sách'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tài nguyên'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_ind),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.resourceAllocation,
                arguments: {
                  'projectId': widget.projectId,
                  'projectName': 'Dự án', // TODO: Get project name
                },
              );
            },
            tooltip: 'Phân bổ tài nguyên cho Tasks',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Kiểm tra nếu màn hình đủ rộng (tablet/desktop)
                if (constraints.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Danh sách tài nguyên
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Danh sách tài nguyên (${_resources.length})',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    color: AppColors.primary,
                                    onPressed: _clearResourceForm,
                                    tooltip: 'Thêm tài nguyên mới',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: _buildResourceList()),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      // Form chỉnh sửa tài nguyên
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildResourceForm(),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Layout dọc cho mobile
                  return Column(
                    children: [
                      // Header với button thêm
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Danh sách tài nguyên (${_resources.length})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: AppColors.primary,
                              onPressed: _clearResourceForm,
                              tooltip: 'Thêm tài nguyên mới',
                            ),
                          ],
                        ),
                      ),
                      // Danh sách tài nguyên
                      Expanded(
                        flex: 1,
                        child: _buildResourceList(),
                      ),
                      // Form (có thể collapse/expand)
                      if (_selectedResource != null || _resources.isEmpty)
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildResourceForm(),
                          ),
                        ),
                    ],
                  );
                }
              },
            ),
      floatingActionButton: MediaQuery.of(context).size.width <= 600 
          ? FloatingActionButton(
              onPressed: _clearResourceForm,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Thêm tài nguyên mới',
            )
          : null,
    );
  }
} 