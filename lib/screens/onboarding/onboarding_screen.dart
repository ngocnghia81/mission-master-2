import 'package:flutter/material.dart';
import 'package:mission_master/constants/colors.dart';
import 'package:mission_master/constants/fonts.dart';
import 'package:mission_master/routes/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;
  
  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Chào mừng đến với Mission Master',
      'description': 'Giải pháp quản lý công việc toàn diện giúp bạn và đội nhóm hoàn thành công việc hiệu quả hơn.',
      'image': 'assets/images/onboarding1.png',
      'color': AppColors.primaryColor,
    },
    {
      'title': 'Quản lý dự án dễ dàng',
      'description': 'Tạo dự án, thêm thành viên và phân công nhiệm vụ chỉ với vài thao tác đơn giản.',
      'image': 'assets/images/onboarding2.png',
      'color': AppColors.accentColor,
    },
    {
      'title': 'Theo dõi tiến độ mọi lúc mọi nơi',
      'description': 'Nhận thông báo, cập nhật trạng thái và theo dõi tiến độ dự án ngay trên thiết bị di động của bạn.',
      'image': 'assets/images/onboarding3.png',
      'color': AppColors.workspaceGradientColor1[1],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Lưu trạng thái đã xem onboarding
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // Nội dung chính
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              return _buildOnboardingPage(
                _onboardingData[index]['title'],
                _onboardingData[index]['description'],
                _onboardingData[index]['image'],
                _onboardingData[index]['color'],
                size,
              );
            },
          ),
          
          // Chỉ báo trang và nút điều hướng
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Chỉ báo trang
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _totalPages,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 10,
                      width: _currentPage == index ? 30 : 10,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.primaryColor
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Nút điều hướng
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nút bỏ qua
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Bỏ qua',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      // Nút tiếp theo hoặc bắt đầu
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          if (_currentPage == _totalPages - 1) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Text(
                          _currentPage == _totalPages - 1 ? 'Bắt đầu' : 'Tiếp theo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(
    String title,
    String description,
    String imagePath,
    Color color,
    Size size,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.5),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hình ảnh
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_not_supported,
                    size: 100,
                    color: Colors.grey.shade400,
                  );
                },
              ),
            ),
          ),
          
          // Nội dung văn bản
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: AppFonts.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Khoảng trống cho nút điều hướng
          const Expanded(
            flex: 1,
            child: SizedBox(),
          ),
        ],
      ),
    );
  }
} 