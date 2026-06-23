import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/buddy_service.dart';

class PinEntryDialog extends StatefulWidget {
  final String title;
  final String description;

  const PinEntryDialog({
    super.key,
    this.title = 'Enter Security PIN',
    this.description = 'Please enter your 4-6 digit accountability PIN to proceed.',
  });

  static Future<bool?> show(BuildContext context, {String? title, String? description}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => PinEntryDialog(
        title: title ?? 'Enter Security PIN',
        description: description ?? 'Please enter your 4-6 digit accountability PIN to proceed.',
      ),
    );
  }

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> with SingleTickerProviderStateMixin {
  final List<int> _enteredDigits = [];
  bool _isLoading = false;
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  void _startLockout() {
    setState(() {
      _isLocked = true;
      _lockoutSecondsLeft = 60;
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSecondsLeft == 1) {
        timer.cancel();
        setState(() {
          _isLocked = false;
          _failedAttempts = 0;
        });
      } else {
        setState(() {
          _lockoutSecondsLeft--;
        });
      }
    });
  }

  void _onKeyPress(int value) {
    if (_isLoading || _isLocked) return;
    if (_enteredDigits.length < 6) {
      setState(() {
        _enteredDigits.add(value);
      });
    }
  }

  void _onDelete() {
    if (_isLoading || _isLocked) return;
    if (_enteredDigits.isNotEmpty) {
      setState(() {
        _enteredDigits.removeLast();
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_isLoading || _isLocked || _enteredDigits.length < 4) return;

    setState(() => _isLoading = true);
    final pin = _enteredDigits.join();

    try {
      final isValid = await BuddyService.verifyPIN(pin);
      if (isValid) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _handleFailure();
      }
    } catch (e) {
      _handleFailure();
    }
  }

  void _handleFailure() {
    _triggerShake();
    setState(() {
      _isLoading = false;
      _enteredDigits.clear();
      _failedAttempts++;
    });

    if (_failedAttempts >= 3) {
      _startLockout();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid PIN. ${3 - _failedAttempts} attempts remaining.'),
          backgroundColor: Colors.red.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDot(int index) {
    final hasDigit = index < _enteredDigits.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasDigit ? Theme.of(context).primaryColor : Colors.white24,
        border: Border.all(
          color: hasDigit ? Theme.of(context).primaryColor : Colors.white38,
          width: 2,
        ),
        boxShadow: hasDigit
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
    );
  }

  Widget _buildKey(dynamic val) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (val is int) {
            _onKeyPress(val);
          } else if (val == 'delete') {
            _onDelete();
          } else if (val == 'submit') {
            _onSubmit();
          }
        },
        child: Container(
          margin: const EdgeInsets.all(6),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Center(
            child: val is int
                ? Text(
                    val.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : (val == 'delete'
                    ? const Icon(Icons.backspace_rounded, color: Colors.white70)
                    : const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isLocked
                  ? 'Locked due to multiple failed attempts. Try again in $_lockoutSecondsLeft seconds.'
                  : widget.description,
              style: TextStyle(
                fontSize: 14,
                color: _isLocked ? Colors.redAccent : Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final double offset = sin(_shakeAnimation.value * pi * 2) * 10;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) => _buildDot(index)),
              ),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Row(
                children: [
                  _buildKey(1),
                  _buildKey(2),
                  _buildKey(3),
                ],
              ),
              Row(
                children: [
                  _buildKey(4),
                  _buildKey(5),
                  _buildKey(6),
                ],
              ),
              Row(
                children: [
                  _buildKey(7),
                  _buildKey(8),
                  _buildKey(9),
                ],
              ),
              Row(
                children: [
                  _buildKey('delete'),
                  _buildKey(0),
                  _buildKey(_enteredDigits.length >= 4 ? 'submit' : ''),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
