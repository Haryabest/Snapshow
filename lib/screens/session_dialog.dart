import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_colors.dart';
import '../services/session_service.dart';

class SessionDialog extends StatefulWidget {
  final VoidCallback onContinueSession;
  final VoidCallback onNewSession;
  
  const SessionDialog({
    super.key,
    required this.onContinueSession,
    required this.onNewSession,
  });

  @override
  State<SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  bool _isLoading = false;
  int _sessionPhotoCount = 0;
  
  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }
  
  Future<void> _loadSessionInfo() async {
    final session = await SessionService.getCurrentSession();
    setState(() {
      _sessionPhotoCount = session.length;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FontAwesomeIcons.camera,
              size: 50,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Добро пожаловать!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Найдена предыдущая сессия с $_sessionPhotoCount фото',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Кнопка продолжить сессию
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () {
                  Navigator.of(context).pop();
                  widget.onContinueSession();
                },
                icon: const Icon(FontAwesomeIcons.play, size: 16),
                label: Text(
                  'Продолжить сессию',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Кнопка начать заново
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () async {
                  final shouldDelete = await _showDeleteConfirmation();
                  if (shouldDelete == true) {
                    setState(() {
                      _isLoading = true;
                    });
                    
                    await SessionService.deleteSessionPhotos();
                    
                    if (mounted) {
                      Navigator.of(context).pop();
                      widget.onNewSession();
                    }
                  }
                },
                icon: const Icon(FontAwesomeIcons.plus, size: 16),
                label: Text(
                  'Начать заново',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<bool?> _showDeleteConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Подтверждение',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Все фотографии из предыдущей сессии будут удалены. Продолжить?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
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
      ),
    );
  }
}

class ExitDialog extends StatefulWidget {
  final List<String> imagePaths;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  
  const ExitDialog({
    super.key,
    required this.imagePaths,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  State<ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<ExitDialog> {
  bool _isLoading = false;
  bool _autoSave = true;
  
  @override
  void initState() {
    super.initState();
    _loadAutoSaveSetting();
  }
  
  Future<void> _loadAutoSaveSetting() async {
    final autoSave = await SessionService.isAutoSaveEnabled();
    setState(() {
      _autoSave = autoSave;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FontAwesomeIcons.doorOpen,
              size: 50,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Выход из приложения',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'У вас есть ${widget.imagePaths.length} несохраненных фото',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Переключатель автосохранения
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.floppyDisk,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Автосохранение сессии',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _autoSave,
                    onChanged: (value) async {
                      setState(() {
                        _autoSave = value;
                      });
                      await SessionService.setAutoSave(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Кнопка сохранить
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () async {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  await SessionService.saveSession(widget.imagePaths);
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    widget.onSave();
                  }
                },
                icon: const Icon(FontAwesomeIcons.floppyDisk, size: 16),
                label: Text(
                  'Сохранить и выйти',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Кнопка удалить
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () async {
                  final shouldDelete = await _showDeleteConfirmation();
                  if (shouldDelete == true) {
                    setState(() {
                      _isLoading = true;
                    });
                    
                    await SessionService.deleteSessionPhotos();
                    
                    if (mounted) {
                      Navigator.of(context).pop();
                      widget.onDelete();
                    }
                  }
                },
                icon: const Icon(FontAwesomeIcons.trash, size: 16),
                label: Text(
                  'Удалить и выйти',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Кнопка отмена
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.of(context).pop();
                widget.onCancel();
              },
              child: Text(
                'Отмена',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<bool?> _showDeleteConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Подтверждение',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Все фотографии будут безвозвратно удалены. Продолжить?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
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
      ),
    );
  }
}