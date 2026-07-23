import 'package:flutter/material.dart';

class ReaderController extends ChangeNotifier {
  double _scrollPosition = 0.0;
  int _positionIndex = 0;

  double get scrollPosition => _scrollPosition;
  int get positionIndex => _positionIndex;

  void updateScrollPosition(double newPosition) {
    _scrollPosition = newPosition;
    notifyListeners();
  }

  void updatePositionIndex(int newIndex) {
    _positionIndex = newIndex;
    notifyListeners();
  }
}
