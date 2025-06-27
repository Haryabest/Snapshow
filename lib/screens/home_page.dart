import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart' as app_theme;
import '../main.dart' show cameras; // Импортируем только cameras из main.dart
import 'camera_page.dart' hide AppColors; // Скрываем AppColors из camera_page.dart
import 'presentation_page.dart' hide AppColors; // Скрываем AppColors из presentation_page.dart

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Список путей к изображениям
  final List<String> _imagePaths = [];
  
  // Множество выбранных изображений (для множественного выбора)
  final Set<int> _selectedImageIndices = {};
  
  // Режим выбора (одиночный или множественный)
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
    // Запрашиваем разрешения с русскими пояснениями
    await Permission.camera.request().then((status) {
      if (status != PermissionStatus.granted) {
        debugPrint('Разрешение на использование камеры не получено');
        if (status == PermissionStatus.permanentlyDenied) {
          _showPermissionDialog(
            'Требуется доступ к камере',
            'Для съемки фотографий необходим доступ к камере. Пожалуйста, предоставьте разрешение в настройках.',
          );
        }
      }
    });
    
    await Permission.storage.request().then((status) {
      if (status != PermissionStatus.granted) {
        debugPrint('Разрешение на доступ к хранилищу не получено');
        if (status == PermissionStatus.permanentlyDenied) {
          _showPermissionDialog(
            'Требуется доступ к хранилищу',
            'Для сохранения фотографий необходим доступ к хранилищу. Пожалуйста, предоставьте разрешение в настройках.',
          );
        }
      }
    });
    
    await Permission.microphone.request().then((status) {
      if (status != PermissionStatus.granted) {
        debugPrint('Разрешение на использование микрофона не получено');
        if (status == PermissionStatus.permanentlyDenied) {
          _showPermissionDialog(
            'Требуется доступ к микрофону',
            'Для записи звука необходим доступ к микрофону. Пожалуйста, предоставьте разрешение в настройках.',
          );
        }
      }
    });
  }
  
  // Диалог для объяснения необходимости разрешений
  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Отмена',
              style: GoogleFonts.poppins(
                color: app_theme.AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: app_theme.AppColors.primary,
            ),
            child: Text(
              'settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
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
      
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CameraPage(
            controller: controller,
            onPhotoTaken: (String imagePath) {
              setState(() {
                _imagePaths.add(imagePath);
                // Очищаем выбор при добавлении нового фото
                _selectedImageIndices.clear();
                _isMultiSelectMode = false;
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
  
  // Метод для удаления выбранных изображений
  void _deleteSelectedImages() {
    if (_selectedImageIndices.isEmpty) return;
    
    // Сортируем индексы в обратном порядке, чтобы удаление не влияло на индексы
    final sortedIndices = _selectedImageIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    
    for (final index in sortedIndices) {
      if (index < _imagePaths.length) {
        final imagePath = _imagePaths[index];
        
        // Удаляем файл с устройства
        try {
          File(imagePath).delete();
        } catch (e) {
          debugPrint('Ошибка при удалении файла: $e');
        }
        
        // Удаляем путь из списка
        _imagePaths.removeAt(index);
      }
    }
    
    setState(() {
      _selectedImageIndices.clear();
      _isMultiSelectMode = false;
    });
  }
  
  // Метод для удаления изображения по индексу
  void _deleteImage(int index) {
    final imagePath = _imagePaths[index];
    setState(() {
      _imagePaths.removeAt(index);
      _selectedImageIndices.clear();
      _isMultiSelectMode = false;
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
    int tempDuration = _displayDuration;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'settings',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Время показа изображения (сек):',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(10, (index) {
                        final value = index + 1;
                        final isSelected = tempDuration == value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: () {
                              setStateInDialog(() {
                                tempDuration = value;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? app_theme.AppColors.primary
                                  : Colors.grey.shade200,
                              foregroundColor: isSelected
                                  ? Colors.white
                                  : app_theme.AppColors.textSecondary,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              minimumSize: const Size(50, 50),
                            ),
                            child: Text(
                              value.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: app_theme.AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Выбрано: $tempDuration секунд',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: app_theme.AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Отмена',
                      style: GoogleFonts.poppins(
                          color: app_theme.AppColors.textSecondary),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _displayDuration = tempDuration;
                      });
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: app_theme.AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Сохранить',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            );
          },
        );
      },
    );
  }
  
  // Метод для запуска демонстрации изображений
  void _startPresentation() {
    if (_imagePaths.isEmpty) {
      _showSnackBar('Нет изображений для показа');
      return;
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PresentationPage(
          imagePaths: _imagePaths,
          displayDuration: _displayDuration,
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
        backgroundColor: app_theme.AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }
  
  // Метод для переключения режима множественного выбора
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedImageIndices.clear();
      }
    });
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
                  Text(
                    _isMultiSelectMode 
                        ? 'Выбрано: ${_selectedImageIndices.length}' 
                        : 'Галерея',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isMultiSelectMode 
                          ? FontAwesomeIcons.xmark 
                          : FontAwesomeIcons.checkSquare,
                      size: 20
                    ),
                    onPressed: _imagePaths.isNotEmpty ? _toggleMultiSelectMode : null,
                    tooltip: _isMultiSelectMode ? 'Отменить выбор' : 'Выбрать несколько',
                  ),
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
          Icon(
            FontAwesomeIcons.images,
            size: 70,
            color: app_theme.AppColors.secondary,
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
    final isSelected = _selectedImageIndices.contains(index);
    
    return Dismissible(
      key: Key(_imagePaths[index]),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: app_theme.AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(FontAwesomeIcons.trash, color: Colors.white, size: 20),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: app_theme.AppColors.error,
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
                      color: app_theme.AppColors.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_theme.AppColors.error,
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
          // В режиме множественного выбора, нажатие переключает выбор
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedImageIndices.remove(index);
                // Если отменили выбор последнего элемента, выходим из режима
                if (_selectedImageIndices.isEmpty) {
                  _isMultiSelectMode = false;
                }
              } else {
                _selectedImageIndices.add(index);
              }
            });
          } else {
            // В обычном режиме просто выделяем одно изображение для возможного удаления
            setState(() {
              if (isSelected) {
                _selectedImageIndices.clear();
              } else {
                _selectedImageIndices.clear();
                _selectedImageIndices.add(index);
              }
            });
          }
        },
        onLongPress: () {
          // Включаем режим множественного выбора по долгому нажатию
          if (!_isMultiSelectMode) {
            setState(() {
              _isMultiSelectMode = true;
              _selectedImageIndices.add(index);
            });
          }
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? app_theme.AppColors.primary
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
            if (isSelected)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: app_theme.AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 18,
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
    final bool hasSelectedImages = _selectedImageIndices.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _takePhoto,
              child: const Icon(FontAwesomeIcons.camera, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: hasSelectedImages ? _deleteSelectedImages : null,
              child: const Icon(FontAwesomeIcons.trash, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedImages ? app_theme.AppColors.error : Colors.grey.shade300,
                foregroundColor: hasSelectedImages ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _imagePaths.isNotEmpty ? _startPresentation : null,
              child: const Icon(FontAwesomeIcons.play, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: _imagePaths.isNotEmpty ? app_theme.AppColors.secondary : Colors.grey.shade300,
                foregroundColor: _imagePaths.isNotEmpty ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 