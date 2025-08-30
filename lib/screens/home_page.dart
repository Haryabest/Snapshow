import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart' as app_theme;
import '../main.dart' show cameras; // Импортируем только cameras из main.dart
import '../services/session_service.dart';
import '../models/photo_item.dart';
import 'camera_page.dart';
import 'presentation_page.dart';
import 'session_dialog.dart';
import 'barcode_scanner_page.dart';
import 'barcode_display_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Список элементов фотографий с штрихкодами
  final List<PhotoItem> _photoItems = [];
  
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
    _checkForExistingSession();
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
    debugPrint('Попытка сделать фото. Количество доступных камер: ${cameras.length}');
    
    if (cameras.isEmpty) {
      debugPrint('Камеры недоступны. Попытка получить список камер...');
      try {
        cameras = await availableCameras();
        debugPrint('Получено камер: ${cameras.length}');
        if (cameras.isEmpty) {
          _showSnackBar('Камера недоступна на этом устройстве');
          return;
        }
      } catch (e) {
        debugPrint('Ошибка получения камер: $e');
        _showSnackBar('Ошибка доступа к камере: $e');
        return;
      }
    }
    
    debugPrint('Инициализация контроллера камеры...');
    
    final CameraController controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );
    
    try {
      await controller.initialize();
      debugPrint('Контроллер камеры успешно инициализирован');
      
      if (!mounted) return;
      
      debugPrint('Открытие страницы камеры...');
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CameraPage(
            controller: controller,
            onPhotoTaken: (String imagePath) {
              debugPrint('onPhotoTaken callback получен с путем: $imagePath');
              debugPrint('Текущее количество фото: ${_photoItems.length}');
              
              setState(() {
                _photoItems.add(PhotoItem(imagePath: imagePath));
                debugPrint('Фото добавлено. Новое количество: ${_photoItems.length}');
                // Очищаем выбор при добавлении нового фото
                _selectedImageIndices.clear();
                _isMultiSelectMode = false;
              });
              // Автосохранение сессии
              _autoSaveSession();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Ошибка инициализации камеры: $e');
      _showSnackBar('Не удалось инициализировать камеру: $e');
      // Освобождаем ресурсы контроллера
      try {
        await controller.dispose();
      } catch (disposeError) {
        debugPrint('Ошибка при освобождении контроллера: $disposeError');
      }
    }
  }
  
  // Метод для удаления выбранных изображений
  void _deleteSelectedImages() {
    if (_selectedImageIndices.isEmpty) return;
    
    // Сортируем индексы в обратном порядке, чтобы удаление не влияло на индексы
    final sortedIndices = _selectedImageIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    
    for (final index in sortedIndices) {
      if (index < _photoItems.length) {
        final photoItem = _photoItems[index];
        
        // Удаляем файл с устройства
        try {
          File(photoItem.imagePath).delete();
        } catch (e) {
          debugPrint('Ошибка при удалении файла: $e');
        }
        
        // Удаляем элемент из списка
        _photoItems.removeAt(index);
      }
    }
    
    setState(() {
      _selectedImageIndices.clear();
      _isMultiSelectMode = false;
    });
    
    // Автосохранение сессии после удаления
    _autoSaveSession();
  }
  
  // Метод для удаления изображения по индексу
  void _deleteImage(int index) {
    final photoItem = _photoItems[index];
    setState(() {
      _photoItems.removeAt(index);
      _selectedImageIndices.clear();
      _isMultiSelectMode = false;
    });
    
    // Удаляем файл с устройства
    try {
      File(photoItem.imagePath).delete();
    } catch (e) {
      debugPrint('Ошибка при удалении файла: $e');
    }
    
    // Автосохранение сессии после удаления
    _autoSaveSession();
  }
  
  // Метод для сканирования штрихкода
  void _scanBarcode(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(
          imagePath: _photoItems[index].imagePath,
          onBarcodeScanned: (String barcode) {
            setState(() {
              _photoItems[index] = _photoItems[index].copyWith(barcode: barcode);
            });
            _autoSaveSession();
            _showSnackBar('Штрихкод привязан к фотографии');
          },
        ),
      ),
    );
  }
  
  // Метод для увеличения количества штрихкодов
  void _increaseBarcodeCount(int index) {
    if (_photoItems[index].barcode != null) {
      setState(() {
        _photoItems[index] = _photoItems[index].copyWith(
          barcodeCount: _photoItems[index].barcodeCount + 1,
        );
      });
      _autoSaveSession();
    }
  }
  
  // Метод для уменьшения количества штрихкодов
  void _decreaseBarcodeCount(int index) {
    if (_photoItems[index].barcode != null && _photoItems[index].barcodeCount > 1) {
      setState(() {
        _photoItems[index] = _photoItems[index].copyWith(
          barcodeCount: _photoItems[index].barcodeCount - 1,
        );
      });
      _autoSaveSession();
    }
  }
  
  // Метод для отображения только штрихкодов (выбранных фото)
  void _showBarcodesOnly() {
    // Получаем только выбранные фото со штрихкодами
    final selectedItemsWithBarcodes = _selectedImageIndices
        .map((index) => _photoItems[index])
        .where((item) => item.barcode != null)
        .toList();
    
    if (selectedItemsWithBarcodes.isEmpty) {
      if (_selectedImageIndices.isEmpty) {
        _showSnackBar('Не выбрано ни одной фотографии');
      } else {
        _showSnackBar('У выбранных фотографий нет штрихкодов');
      }
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BarcodeDisplayPage(
          photoItems: selectedItemsWithBarcodes,
          displayDuration: _displayDuration,
        ),
      ),
    );
  }
  
  // Метод для отображения штрихкодов с повторениями (тележка)
  void _showBarcodesWithRepeats() {
    // Получаем все фото со штрихкодами
    final itemsWithBarcodes = _photoItems.where((item) => item.barcode != null).toList();
    
    if (itemsWithBarcodes.isEmpty) {
      _showSnackBar('Нет фотографий со штрихкодами');
      return;
    }
    
    // Создаем список штрихкодов с учетом повторений
    List<PhotoItem> expandedBarcodes = [];
    for (final item in itemsWithBarcodes) {
      for (int i = 0; i < item.barcodeCount; i++) {
        expandedBarcodes.add(item);
      }
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BarcodeDisplayPage(
          photoItems: expandedBarcodes,
          displayDuration: _displayDuration,
          isCartMode: true, // Флаг для режима тележки
        ),
      ),
    );
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
                'Настройки',
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
  
  // Метод для запуска демонстрации изображений (только выбранные фото)
  void _startPresentation() {
    if (_selectedImageIndices.isEmpty) {
      _showSnackBar('Не выбрано ни одной фотографии');
      return;
    }
    
    // Получаем пути только выбранных фотографий
    final selectedImagePaths = _selectedImageIndices
        .map((index) => _photoItems[index].imagePath)
        .toList();
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PresentationPage(
          imagePaths: selectedImagePaths,
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
      if (_isMultiSelectMode) {
        // Если все фото выбраны, отменяем выбор
        if (_selectedImageIndices.length == _photoItems.length) {
          _selectedImageIndices.clear();
          _isMultiSelectMode = false;
        } else {
          // Иначе выбираем все
          _selectedImageIndices.clear();
          for (int i = 0; i < _photoItems.length; i++) {
            _selectedImageIndices.add(i);
          }
        }
      } else {
        // Включаем режим множественного выбора и выбираем все
        _isMultiSelectMode = true;
        _selectedImageIndices.clear();
        for (int i = 0; i < _photoItems.length; i++) {
          _selectedImageIndices.add(i);
        }
      }
    });
  }
  
  // Проверка существующей сессии при запуске
  Future<void> _checkForExistingSession() async {
    final hasSession = await SessionService.hasSession();
    
    if (hasSession && mounted) {
      // Показываем диалог выбора сессии
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SessionDialog(
          onContinueSession: _continueSession,
          onNewSession: _startNewSession,
        ),
      );
    }
  }
  
  // Продолжить существующую сессию
  Future<void> _continueSession() async {
    final photoItems = await SessionService.getCurrentPhotoItems();
    setState(() {
      _photoItems.clear();
      _photoItems.addAll(photoItems);
      _selectedImageIndices.clear();
      _isMultiSelectMode = false;
    });
  }
  
  // Начать новую сессию
  void _startNewSession() {
    setState(() {
      _photoItems.clear();
      _selectedImageIndices.clear();
      _isMultiSelectMode = false;
    });
  }
  
  // Автосохранение сессии
  Future<void> _autoSaveSession() async {
    final isAutoSaveEnabled = await SessionService.isAutoSaveEnabled();
    if (isAutoSaveEnabled && _photoItems.isNotEmpty) {
      await SessionService.savePhotoItems(_photoItems);
    }
  }
  
  // Обработка выхода из приложения
  Future<bool> _onWillPop() async {
    if (_photoItems.isEmpty) {
      return true; // Разрешаем выход, если нет фотографий
    }
    
    // Показываем диалог выхода
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExitDialog(
        imagePaths: _photoItems.map((item) => item.imagePath).toList(),
        onSave: () {
          SystemNavigator.pop(); // Выходим из приложения
        },
        onDelete: () {
          SystemNavigator.pop(); // Выходим из приложения
        },
        onCancel: () {
          // Ничего не делаем, диалог уже закрыт
        },
      ),
    );
    
    return false; // Не разрешаем автоматический выход
  }
  
  // Построение навигационного меню
  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  app_theme.AppColors.primary,
                  app_theme.AppColors.secondary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  FontAwesomeIcons.camera,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Snapshow',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Фото с штрихкодами',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Настройки времени показа
          ListTile(
            leading: const Icon(FontAwesomeIcons.clock, color: app_theme.AppColors.primary),
            title: Text(
              'Время показа',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '$_displayDuration секунд',
              style: GoogleFonts.poppins(color: app_theme.AppColors.textSecondary),
            ),
            trailing: const Icon(FontAwesomeIcons.chevronRight, size: 16),
            onTap: () {
              Navigator.of(context).pop();
              _showSettingsDialog();
            },
          ),
          
          const Divider(),
          
          // Статистика сессии
          ListTile(
            leading: const Icon(FontAwesomeIcons.chartSimple, color: app_theme.AppColors.secondary),
            title: Text(
              'Статистика сессии',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Фото: ${_photoItems.length}, Штрихкоды: ${_photoItems.where((item) => item.barcode != null).fold<int>(0, (sum, item) => sum + item.barcodeCount)}',
              style: GoogleFonts.poppins(color: app_theme.AppColors.textSecondary),
            ),
          ),
          
          // Автосохранение
          FutureBuilder<bool>(
            future: SessionService.isAutoSaveEnabled(),
            builder: (context, snapshot) {
              final isAutoSaveEnabled = snapshot.data ?? true;
              return SwitchListTile(
                secondary: const Icon(FontAwesomeIcons.floppyDisk, color: app_theme.AppColors.primary),
                title: Text(
                  'Автосохранение',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  isAutoSaveEnabled ? 'Включено' : 'Отключено',
                  style: GoogleFonts.poppins(color: app_theme.AppColors.textSecondary),
                ),
                value: isAutoSaveEnabled,
                activeColor: app_theme.AppColors.primary,
                onChanged: (value) async {
                  await SessionService.setAutoSave(value);
                  setState(() {}); // Обновляем UI
                },
              );
            },
          ),
          
          const Divider(),
          
          // Очистить сессию
          ListTile(
            leading: const Icon(FontAwesomeIcons.broom, color: app_theme.AppColors.error),
            title: Text(
              'Очистить сессию',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Удалить все фото и штрихкоды',
              style: GoogleFonts.poppins(color: app_theme.AppColors.textSecondary),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _showClearSessionDialog();
            },
          ),
        ],
      ),
    );
  }
  
  // Диалог очистки сессии
  void _showClearSessionDialog() {
    if (_photoItems.isEmpty) {
      _showSnackBar('Сессия уже пуста');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Очистить сессию',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Все фотографии и штрихкоды из текущей сессии будут удалены. Это действие нельзя отменить.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
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
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Удаляем все файлы
              for (final item in _photoItems) {
                try {
                  await File(item.imagePath).delete();
                } catch (e) {
                  debugPrint('Ошибка при удалении файла: $e');
                }
              }
              
              // Очищаем сессию
              await SessionService.clearSession();
              
              // Обновляем UI
              setState(() {
                _photoItems.clear();
                _selectedImageIndices.clear();
                _isMultiSelectMode = false;
              });
              
              _showSnackBar('Сессия очищена');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: app_theme.AppColors.error,
            ),
            child: Text(
              'Очистить',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
      drawer: _buildNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(FontAwesomeIcons.bars, size: 20),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'Меню',
                    ),
                  ),
                  Text(
                    _isMultiSelectMode 
                        ? 'Выбрано: ${_selectedImageIndices.length} из ${_photoItems.length}' 
                        : 'Галерея (${_photoItems.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _isMultiSelectMode 
                          ? app_theme.AppColors.primary
                          : app_theme.AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isMultiSelectMode 
                          ? FontAwesomeIcons.xmark 
                          : FontAwesomeIcons.squareCheck,
                      size: 20
                    ),
                    onPressed: _photoItems.isNotEmpty ? _toggleMultiSelectMode : null,
                    tooltip: _isMultiSelectMode 
                        ? (_selectedImageIndices.length == _photoItems.length 
                            ? 'Отменить все' 
                            : 'Выбрать все') 
                        : 'Выбрать несколько',
                  ),
                ],
              ),
            ),
            
            // Область для отображения иконок изображений
            Expanded(
              child: _photoItems.isEmpty
                  ? _buildEmptyState()
                  : _buildImageGrid(),
            ),
            
            // Панель с кнопками управления
            _buildBottomPanel(),
          ],
        ),
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
          const SizedBox(height: 16),
          Text(
            'Нет фотографий',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: app_theme.AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите кнопку камеры для съёмки',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: app_theme.AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Фото в списке: ${_photoItems.length}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: app_theme.AppColors.textSecondary,
            ),
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
        itemCount: _photoItems.length,
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
      key: Key(_photoItems[index].imagePath),
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
          setState(() {
            if (_isMultiSelectMode) {
              // В режиме множественного выбора переключаем выбор
              if (isSelected) {
                _selectedImageIndices.remove(index);
                // Если отменили выбор последнего элемента, выходим из режима
                if (_selectedImageIndices.isEmpty) {
                  _isMultiSelectMode = false;
                }
              } else {
                _selectedImageIndices.add(index);
              }
            } else {
              // В обычном режиме включаем множественный выбор и выбираем это фото
              _isMultiSelectMode = true;
              _selectedImageIndices.clear();
              _selectedImageIndices.add(index);
            }
          });
        },
        onLongPress: () {
          // Длинное нажатие также включает режим множественного выбора
          if (!_isMultiSelectMode) {
            setState(() {
              _isMultiSelectMode = true;
              _selectedImageIndices.clear();
              _selectedImageIndices.add(index);
            });
          }
        },
        child: Column(
          children: [
            // Изображение
            AspectRatio(
              aspectRatio: 1.0, // Квадратные изображения
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
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
                        File(_photoItems[index].imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  
                  // Индикатор штрихкода
                  if (_photoItems[index].barcode != null)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              FontAwesomeIcons.barcode,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${_photoItems[index].barcodeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
            
            // Панель управления штрихкодами
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  // Кнопка сканирования штрихкода
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _scanBarcode(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _photoItems[index].barcode != null 
                              ? Colors.green.withOpacity(0.2)
                              : app_theme.AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          FontAwesomeIcons.barcode,
                          size: 14,
                          color: _photoItems[index].barcode != null 
                              ? Colors.green
                              : app_theme.AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  
                  if (_photoItems[index].barcode != null) ...[
                    const SizedBox(width: 4),
                    
                    // Кнопка уменьшения количества
                    GestureDetector(
                      onTap: () => _decreaseBarcodeCount(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _photoItems[index].barcodeCount > 1
                              ? app_theme.AppColors.error.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          FontAwesomeIcons.minus,
                          size: 10,
                          color: _photoItems[index].barcodeCount > 1
                              ? app_theme.AppColors.error
                              : Colors.grey,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 4),
                    
                    // Кнопка увеличения количества
                    GestureDetector(
                      onTap: () => _increaseBarcodeCount(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.plus,
                          size: 10,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ],
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
    
    // Проверяем, есть ли у выбранных фото штрихкоды (для зеленой кнопки)
    final bool hasSelectedBarcodes = hasSelectedImages && _selectedImageIndices
        .any((index) => _photoItems[index].barcode != null);
    
    // Проверяем, есть ли штрихкоды у всех фото (для оранжевой кнопки корзины)
    final bool hasAnyBarcodes = _photoItems.any((item) => item.barcode != null);
    
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
              onPressed: hasSelectedImages ? _startPresentation : null,
              child: const Icon(FontAwesomeIcons.play, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedImages ? app_theme.AppColors.secondary : Colors.grey.shade300,
                foregroundColor: hasSelectedImages ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Кнопка отображения штрихкодов (только выбранные)
          Expanded(
            child: ElevatedButton(
              onPressed: hasSelectedBarcodes ? _showBarcodesOnly : null,
              child: const Icon(FontAwesomeIcons.barcode, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedBarcodes 
                    ? Colors.green 
                    : Colors.grey.shade300,
                foregroundColor: hasSelectedBarcodes 
                    ? Colors.white 
                    : Colors.grey.shade600,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Кнопка тележки (штрихкоды с повторениями, все фото)
          Expanded(
            child: ElevatedButton(
              onPressed: hasAnyBarcodes ? _showBarcodesWithRepeats : null,
              child: const Icon(FontAwesomeIcons.cartShopping, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasAnyBarcodes 
                    ? Colors.orange 
                    : Colors.grey.shade300,
                foregroundColor: hasAnyBarcodes 
                    ? Colors.white 
                    : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}