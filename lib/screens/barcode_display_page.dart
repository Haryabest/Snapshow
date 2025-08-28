import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_colors.dart';
import '../models/photo_item.dart';

class BarcodeDisplayPage extends StatefulWidget {
  final List<PhotoItem> photoItems;
  final int displayDuration;
  final bool isCartMode;
  
  const BarcodeDisplayPage({
    super.key,
    required this.photoItems,
    required this.displayDuration,
    this.isCartMode = false,
  });

  @override
  State<BarcodeDisplayPage> createState() => _BarcodeDisplayPageState();
}

class _BarcodeDisplayPageState extends State<BarcodeDisplayPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isPaused = false;
  
  // Создаем список всех штрихкодов с учетом количества
  final List<String> _barcodes = [];
  
  @override
  void initState() {
    super.initState();
    _prepareBarcodes();
  }
  
  void _prepareBarcodes() {
    _barcodes.clear();
    if (widget.isCartMode) {
      // В режиме тележки список уже расширен в home_page.dart
      for (final item in widget.photoItems) {
        if (item.barcode != null) {
          _barcodes.add(item.barcode!);
        }
      }
    } else {
      // В обычном режиме создаем повторения здесь
      for (final item in widget.photoItems) {
        if (item.barcode != null) {
          for (int i = 0; i < item.barcodeCount; i++) {
            _barcodes.add(item.barcode!);
          }
        }
      }
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _startPresentation() {
    if (_barcodes.isEmpty) return;
    
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
    
    _showNextBarcode();
  }
  
  void _showNextBarcode() {
    if (!_isPlaying || _isPaused) return;
    
    Future.delayed(Duration(seconds: widget.displayDuration), () {
      if (!mounted || !_isPlaying || _isPaused) return;
      
      if (_currentIndex < _barcodes.length - 1) {
        setState(() {
          _currentIndex++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _showNextBarcode();
      } else {
        // Презентация завершена
        setState(() {
          _isPlaying = false;
        });
        _showCompletionDialog();
      }
    });
  }
  
  void _pausePresentation() {
    setState(() {
      _isPaused = true;
    });
  }
  
  void _resumePresentation() {
    setState(() {
      _isPaused = false;
    });
    _showNextBarcode();
  }
  
  void _stopPresentation() {
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentIndex = 0;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Презентация завершена',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Все штрихкоды были показаны',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopPresentation();
            },
            child: Text(
              'В начало',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(
              'Закрыть',
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
    if (_barcodes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              FontAwesomeIcons.arrowLeft,
              color: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.isCartMode ? 'Тележка' : 'Штрихкоды',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                FontAwesomeIcons.barcode,
                size: 80,
                color: Colors.white54,
              ),
              const SizedBox(height: 24),
              Text(
                'Нет штрихкодов для отображения',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Отсканируйте штрихкоды для фотографий',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            FontAwesomeIcons.arrowLeft,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${widget.isCartMode ? 'Тележка' : 'Штрихкоды'} (${_currentIndex + 1}/${_barcodes.length})',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Прогресс бар
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(
              value: _barcodes.isNotEmpty ? (_currentIndex + 1) / _barcodes.length : 0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          
          // Область отображения штрихкодов
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: _barcodes.length,
              itemBuilder: (context, index) {
                return _buildBarcodeDisplay(_barcodes[index]);
              },
            ),
          ),
          
          // Панель управления
          _buildControlPanel(),
        ],
      ),
    );
  }
  
  Widget _buildBarcodeDisplay(String barcode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Штрихкод
          Expanded(
            flex: 3,
            child: Center(
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: barcode,
                width: double.infinity,
                height: 200,
                drawText: false,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Текст штрихкода
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              barcode,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Предыдущий
          IconButton(
            onPressed: _currentIndex > 0 ? () {
              setState(() {
                _currentIndex--;
              });
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } : null,
            icon: const Icon(
              FontAwesomeIcons.backward,
              color: Colors.white,
            ),
            iconSize: 24,
          ),
          
          // Воспроизведение/Пауза
          IconButton(
            onPressed: () {
              if (!_isPlaying) {
                _startPresentation();
              } else if (_isPaused) {
                _resumePresentation();
              } else {
                _pausePresentation();
              }
            },
            icon: Icon(
              !_isPlaying 
                  ? FontAwesomeIcons.play
                  : _isPaused 
                      ? FontAwesomeIcons.play
                      : FontAwesomeIcons.pause,
              color: Colors.white,
            ),
            iconSize: 32,
          ),
          
          // Стоп
          IconButton(
            onPressed: _isPlaying ? _stopPresentation : null,
            icon: const Icon(
              FontAwesomeIcons.stop,
              color: Colors.white,
            ),
            iconSize: 24,
          ),
          
          // Следующий
          IconButton(
            onPressed: _currentIndex < _barcodes.length - 1 ? () {
              setState(() {
                _currentIndex++;
              });
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } : null,
            icon: const Icon(
              FontAwesomeIcons.forward,
              color: Colors.white,
            ),
            iconSize: 24,
          ),
        ],
      ),
    );
  }
}