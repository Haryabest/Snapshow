import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// Глобальная переменная для хранения доступных камер
List<CameraDescription> cameras = [];

// Цветовая схема приложения
class AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF42A5F5);
  static const Color accent = Color(0xFF64B5F6);
  static const Color background = Color(0xFFF5F5F7);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color error = Color(0xFFE53935);
}

void main() async {
  // Убедимся, что Flutter инициализирован
  WidgetsFlutterBinding.ensureInitialized();
  
  // Устанавливаем ориентацию приложения
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Настраиваем системную UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Получаем список доступных камер
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Ошибка получения списка камер: ${e.description}');
  }
  
  runApp(const SnapshowApp());
}

class SnapshowApp extends StatelessWidget {
  const SnapshowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snapshow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          background: AppColors.background,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Загрузочный экран
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Переход на главный экран через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              FontAwesomeIcons.camera,
              size: 80,
              color: Colors.white,
            )
            .animate()
            .scale(duration: 600.ms, curve: Curves.easeOut)
            .then()
            .shake(duration: 400.ms),
            
            const SizedBox(height: 24),
            
            Text(
              'Snapshow',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 300.ms)
            .slide(begin: const Offset(0, 0.2), curve: Curves.easeOut),
            
            const SizedBox(height: 8),
            
            Text(
              'Быстрый сбор и показ фотографий',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

// Главный экран приложения
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Список путей к изображениям
  final List<String> _imagePaths = [];
  
  // Индекс выбранного изображения
  int? _selectedImageIndex;
  
  // Список индексов выбранных изображений для множественного выбора
  final Set<int> _selectedImageIndices = {};
  
  // Режим множественного выбора
  bool _isMultiSelectMode = false;
  
  // Длительность показа каждого изображения в секундах
  int _displayDuration = 2;
  
  // Запрашиваем разрешения при инициализации
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }
  
  // Метод для запроса необходимых разрешений
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
    ].request();
    
    if (statuses[Permission.camera] != PermissionStatus.granted) {
      debugPrint('Разрешение на использование камеры не получено');
    }
    
    if (statuses[Permission.storage] != PermissionStatus.granted) {
      debugPrint('Разрешение на доступ к хранилищу не получено');
    }
  }
  
  // Метод для съемки фото
  Future<void> _takePhoto() async {
    if (cameras.isEmpty) {
      _showSnackBar('Камера недоступна');
      return;
    }
    
    final CameraController controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );
    
    try {
      await controller.initialize();
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CameraPage(
            controller: controller,
            onPhotoTaken: (String imagePath) {
              setState(() {
                _imagePaths.add(imagePath);
                _selectedImageIndex = null; // Снимаем выделение при добавлении нового фото
              });
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Ошибка инициализации камеры: $e');
      _showSnackBar('Не удалось инициализировать камеру');
    }
  }
  
  // Метод для удаления выбранного изображения
  void _deleteSelectedImage() {
    if (_isMultiSelectMode && _selectedImageIndices.isNotEmpty) {
      // Удаление нескольких выбранных изображений
      final List<String> pathsToDelete = [];
      
      // Собираем пути к файлам и сортируем индексы в обратном порядке
      final sortedIndices = _selectedImageIndices.toList()..sort((a, b) => b.compareTo(a));
      
      for (final index in sortedIndices) {
        pathsToDelete.add(_imagePaths[index]);
      }
      
      // Удаляем элементы из списка начиная с конца
      for (final index in sortedIndices) {
        _imagePaths.removeAt(index);
      }
      
      // Удаляем файлы с устройства
      for (final imagePath in pathsToDelete) {
        try {
          File(imagePath).delete();
        } catch (e) {
          debugPrint('Ошибка при удалении файла: $e');
        }
      }
      
      setState(() {
        _selectedImageIndices.clear();
        _isMultiSelectMode = false;
      });
    } else if (_selectedImageIndex != null) {
      // Удаление одного выбранного изображения (старая логика)
      final imagePath = _imagePaths[_selectedImageIndex!];
      setState(() {
        _imagePaths.removeAt(_selectedImageIndex!);
        _selectedImageIndex = null; // Снимаем выделение
      });
      
      // Удаляем файл с устройства
      try {
        File(imagePath).delete();
      } catch (e) {
        debugPrint('Ошибка при удалении файла: $e');
      }
    }
  }
  
  // Метод для удаления изображения по индексу
  void _deleteImage(int index) {
    final imagePath = _imagePaths[index];
    setState(() {
      _imagePaths.removeAt(index);
      _selectedImageIndex = null; // Снимаем выделение
    });
    
    // Удаляем файл с устройства
    try {
      File(imagePath).delete();
    } catch (e) {
      debugPrint('Ошибка при удалении файла: $e');
    }
  }
  
  // Метод для отображения настроек
  void _showSettingsDialog() {
    // Создаем временную переменную для хранения выбранного значения
    int tempDisplayDuration = _displayDuration;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'settings',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: tempDisplayDuration > 1 
                          ? () {
                              setDialogState(() {
                                tempDisplayDuration = tempDisplayDuration - 1;
                              });
                            } 
                          : null,
                      icon: const Icon(FontAwesomeIcons.minus),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent.withOpacity(0.2),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$tempDisplayDuration',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: tempDisplayDuration < 10 
                          ? () {
                              setDialogState(() {
                                tempDisplayDuration = tempDisplayDuration + 1;
                              });
                            } 
                          : null,
                      icon: const Icon(FontAwesomeIcons.plus),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent.withOpacity(0.2),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'сек',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.arrowLeft,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _displayDuration = tempDisplayDuration;
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.arrowRight,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Метод для запуска демонстрации изображений
  void _startPresentation() {
    if (_imagePaths.isEmpty) {
      _showSnackBar('Нет изображений для показа');
      return;
    }
    
    // Определяем начальный индекс для показа
    int initialPage = 0;
    if (_selectedImageIndex != null) {
      initialPage = _selectedImageIndex!;
    } else if (_selectedImageIndices.isNotEmpty) {
      // Если выбрано несколько изображений, берем первое из них
      initialPage = _selectedImageIndices.first;
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PresentationPage(
          imagePaths: _imagePaths,
          displayDuration: _displayDuration,
          initialPage: initialPage,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
  
  // Метод для отображения SnackBar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.sliders, size: 20),
                    onPressed: _showSettingsDialog,
                    tooltip: 'settings',
                  ),
                  const Icon(
                    FontAwesomeIcons.shoppingCart,
                    size: 22,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 40), // Для баланса с левой кнопкой
                ],
              ),
            ),
            
            // Область для отображения иконок изображений
            Expanded(
              child: _imagePaths.isEmpty
                  ? _buildEmptyState()
                  : _buildImageGrid(),
            ),
            
            // Панель с кнопками управления
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }
  
  // Виджет для отображения пустого состояния
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.images,
            size: 70,
            color: AppColors.secondary,
          ),

        ],
      ),
    )
    .animate()
    .fadeIn(duration: 600.ms)
    .scale(delay: 200.ms, duration: 400.ms);
  }
  
  // Виджет для отображения сетки изображений
  Widget _buildImageGrid() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: MasonryGridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: _imagePaths.length,
        itemBuilder: (context, index) {
          return _buildImageItem(index);
        },
      ),
    );
  }
  
  // Виджет для отображения элемента изображения
  Widget _buildImageItem(int index) {
    final bool isSelected = _isMultiSelectMode 
        ? _selectedImageIndices.contains(index)
        : _selectedImageIndex == index;
        
    return Dismissible(
      key: Key(_imagePaths[index]),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(FontAwesomeIcons.trash, color: Colors.white, size: 20),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(FontAwesomeIcons.trash, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => _deleteImage(index),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Подтверждение',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Удалить это фото?',
                style: GoogleFonts.poppins(),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Отмена',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: Text(
                    'Удалить',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_isMultiSelectMode) {
              // В режиме множественного выбора добавляем/удаляем из набора
              if (_selectedImageIndices.contains(index)) {
                _selectedImageIndices.remove(index);
                // Если больше нет выбранных элементов, выходим из режима множественного выбора
                if (_selectedImageIndices.isEmpty) {
                  _isMultiSelectMode = false;
                }
              } else {
                _selectedImageIndices.add(index);
              }
            } else {
              // В обычном режиме выбираем/снимаем выбор с одного элемента
              _selectedImageIndex = _selectedImageIndex == index ? null : index;
            }
          });
        },
        onLongPress: () {
          setState(() {
            // Включаем режим множественного выбора при долгом нажатии
            if (!_isMultiSelectMode) {
              _isMultiSelectMode = true;
              _selectedImageIndices.clear();
              _selectedImageIndices.add(index);
              _selectedImageIndex = null; // Сбрасываем одиночный выбор
            }
          });
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_imagePaths[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (isSelected && _isMultiSelectMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
  
  // Виджет для отображения нижней панели с кнопками
  Widget _buildBottomPanel() {
    final bool hasSelection = _selectedImageIndex != null || _selectedImageIndices.isNotEmpty;
    final int selectedCount = _isMultiSelectMode ? _selectedImageIndices.length : (_selectedImageIndex != null ? 1 : 0);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMultiSelectMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Выбрано: $selectedCount',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isMultiSelectMode = false;
                        _selectedImageIndices.clear();
                      });
                    },
                    child: Text(
                      'Отменить',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              _buildBottomButton(
                icon: FontAwesomeIcons.camera,
                label: '',
                onPressed: _takePhoto,
                color: AppColors.primary,
                isEnabled: true,
              ),
              _buildBottomButton(
                icon: FontAwesomeIcons.trash,
                label: '',
                onPressed: hasSelection ? _deleteSelectedImage : null,
                color: AppColors.error,
                isEnabled: hasSelection,
                badge: _isMultiSelectMode && selectedCount > 0 ? selectedCount.toString() : null,
              ),
              _buildBottomButton(
                icon: FontAwesomeIcons.play,
                label: '',
                onPressed: _imagePaths.isNotEmpty ? _startPresentation : null,
                color: AppColors.secondary,
                isEnabled: _imagePaths.isNotEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Виджет для создания кнопки нижней панели
  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required bool isEnabled,
    String? badge,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? color : Colors.grey.shade300,
            foregroundColor: isEnabled ? Colors.white : Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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

// Экран для съемки фото
class CameraPage extends StatefulWidget {
  final CameraController controller;
  final Function(String) onPhotoTaken;

  const CameraPage({
    super.key,
    required this.controller,
    required this.onPhotoTaken,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _isTakingPicture = false;

  Future<void> _takePicture() async {
    if (_isTakingPicture) return;

    setState(() {
      _isTakingPicture = true;
    });

    try {
      // Создаем уникальное имя файла
      final Directory extDir = await getApplicationDocumentsDirectory();
      final String dirPath = '${extDir.path}/Pictures/snapshow';
      await Directory(dirPath).create(recursive: true);
      final String filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Делаем снимок
      final XFile imageFile = await widget.controller.takePicture();
      
      // Копируем файл в наше хранилище
      await File(imageFile.path).copy(filePath);
      
      widget.onPhotoTaken(filePath);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Ошибка при съемке фото: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сделать фото'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } finally {
      setState(() {
        _isTakingPicture = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Превью камеры на весь экран
          Positioned.fill(
            child: CameraPreview(widget.controller),
          ),
          
          // Верхняя панель с кнопкой закрытия
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          
          // Нижняя панель с кнопкой съемки
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Экран для презентации изображений
class PresentationPage extends StatefulWidget {
  final List<String> imagePaths;
  final int displayDuration;
  final int initialPage;

  const PresentationPage({
    super.key,
    required this.imagePaths,
    required this.displayDuration,
    required this.initialPage,
  });

  @override
  State<PresentationPage> createState() => _PresentationPageState();
}

class _PresentationPageState extends State<PresentationPage> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(
      Duration(seconds: widget.displayDuration),
      (timer) {
        if (_currentPage < widget.imagePaths.length - 1) {
          _currentPage++;
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Достигли конца галереи, останавливаем таймер
          _timer.cancel();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Основной просмотрщик изображений
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) {
              return Center(
                child: Hero(
                  tag: 'image_$index',
                  child: Image.file(
                    File(widget.imagePaths[index]),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // Индикатор прогресса
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imagePaths.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
