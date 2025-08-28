import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_item.dart';

class SessionService {
  static const String _sessionKey = 'current_session';
  static const String _photoItemsKey = 'photo_items_session';
  static const String _autoSaveKey = 'auto_save_enabled';
  
  // Получить текущую сессию (старый метод для совместимости)
  static Future<List<String>> getCurrentSession() async {
    final photoItems = await getCurrentPhotoItems();
    return photoItems.map((item) => item.imagePath).toList();
  }
  
  // Получить текущую сессию с PhotoItem
  static Future<List<PhotoItem>> getCurrentPhotoItems() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString(_photoItemsKey);
    
    if (sessionData != null) {
      try {
        final List<dynamic> itemsJson = jsonDecode(sessionData);
        final photoItems = <PhotoItem>[];
        
        for (final itemJson in itemsJson) {
          final photoItem = PhotoItem.fromJson(itemJson as Map<String, dynamic>);
          // Проверяем, существует ли файл
          if (await File(photoItem.imagePath).exists()) {
            photoItems.add(photoItem);
          }
        }
        
        // Обновляем сессию, удаляя несуществующие файлы
        if (photoItems.length != itemsJson.length) {
          await savePhotoItems(photoItems);
        }
        
        return photoItems;
      } catch (e) {
        debugPrint('Ошибка при загрузке сессии: $e');
        return [];
      }
    }
    
    return [];
  }
  
  // Сохранить сессию (старый метод для совместимости)
  static Future<void> saveSession(List<String> imagePaths) async {
    final photoItems = imagePaths.map((path) => PhotoItem(imagePath: path)).toList();
    await savePhotoItems(photoItems);
  }
  
  // Сохранить сессию с PhotoItem
  static Future<void> savePhotoItems(List<PhotoItem> photoItems) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = photoItems.map((item) => item.toJson()).toList();
    await prefs.setString(_photoItemsKey, jsonEncode(itemsJson));
  }
  
  // Очистить сессию
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_photoItemsKey);
  }
  
  // Проверить, есть ли сохраненная сессия
  static Future<bool> hasSession() async {
    final session = await getCurrentSession();
    return session.isNotEmpty;
  }
  
  // Получить настройку автосохранения
  static Future<bool> isAutoSaveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSaveKey) ?? true; // По умолчанию включено
  }
  
  // Установить настройку автосохранения
  static Future<void> setAutoSave(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveKey, enabled);
  }
  
  // Удалить все фотографии из сессии
  static Future<void> deleteSessionPhotos() async {
    final photoItems = await getCurrentPhotoItems();
    
    for (final item in photoItems) {
      try {
        final file = File(item.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Ошибка при удалении файла ${item.imagePath}: $e');
      }
    }
    
    await clearSession();
  }
  
  // Переместить фотографии в постоянное хранилище
  static Future<List<String>> savePhotosToGallery(List<String> imagePaths) async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String savedDirPath = '${extDir.path}/Pictures/snapshow/saved';
    await Directory(savedDirPath).create(recursive: true);
    
    final List<String> savedPaths = [];
    
    for (final imagePath in imagePaths) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final fileName = imagePath.split('/').last;
          final newPath = '$savedDirPath/$fileName';
          
          // Копируем файл в папку сохраненных
          await file.copy(newPath);
          savedPaths.add(newPath);
          
          // Удаляем оригинальный файл из временной папки
          await file.delete();
        }
      } catch (e) {
        debugPrint('Ошибка при сохранении файла $imagePath: $e');
      }
    }
    
    return savedPaths;
  }
  
  // Получить все сохраненные фотографии
  static Future<List<String>> getSavedPhotos() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String savedDirPath = '${extDir.path}/Pictures/snapshow/saved';
    final savedDir = Directory(savedDirPath);
    
    if (!await savedDir.exists()) {
      return [];
    }
    
    final files = await savedDir.list().toList();
    final imagePaths = <String>[];
    
    for (final file in files) {
      if (file is File && _isImageFile(file.path)) {
        imagePaths.add(file.path);
      }
    }
    
    // Сортируем по дате создания (новые сначала)
    imagePaths.sort((a, b) {
      final fileA = File(a);
      final fileB = File(b);
      return fileB.lastModifiedSync().compareTo(fileA.lastModifiedSync());
    });
    
    return imagePaths;
  }
  
  // Проверить, является ли файл изображением
  static bool _isImageFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }
}