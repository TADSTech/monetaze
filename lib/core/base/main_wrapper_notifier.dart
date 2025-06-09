import 'package:flutter/material.dart';

class MainWrapperNotifier extends ChangeNotifier {
  int _currentIndex = 0;
  int _previousIndex = 0;

  int get currentIndex => _currentIndex;
  int get previousIndex => _previousIndex;

  set currentIndex(int index) {
    // Clamp the index to valid range (0-4)
    final clampedIndex = index.clamp(0, 4);
    _previousIndex = _currentIndex;
    _currentIndex = clampedIndex;
    notifyListeners();
  }

  bool get isComingFromGoals => _previousIndex == 1 && _currentIndex == 2;
}
