// 📄 ไฟล์นี้ทำหน้าที่: widget ช่องกรอกข้อมูล (TextFormField) มาตรฐาน
// ใช้ร่วมกันทุกฟอร์มในแอป รองรับโหมดรหัสผ่าน (แสดง/ซ่อน) ในตัว
import 'package:flutter/material.dart';

/// ช่องกรอกข้อมูล Material 3 มาตรฐานที่ใช้ร่วมกันทุกฟอร์มในแอป
/// (ขอบโค้งมน, fill สีอ่อนจากธีม, ไอคอนนำหน้าสีเดียวกับธีม)
/// รองรับโหมดรหัสผ่าน (toggle แสดง/ซ่อน) ผ่าน isPassword
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool autofocus;
  final Color? accentColor;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.accentColor,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? colorScheme.primary;

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        counterText: widget.maxLength != null ? '' : null,
        alignLabelWithHint: (widget.maxLines ?? 1) > 1,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: accent)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
    );
  }
}
