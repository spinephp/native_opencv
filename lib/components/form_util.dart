import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormUtil {
  static Widget textField(
    String formKey,
    String? value, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    TextEditingController? controller,
    Function? onChanged,
    String? hintText,
    IconData? prefixIcon,
    Function? onClear,
    bool obscureText = false,
    height = 50.0,
    margin = 10.0,
  }) {
    return Container(
      height: height,
      margin: EdgeInsets.all(margin),
      child: Column(
        children: [
          TextField(
              keyboardType: keyboardType,
              focusNode: focusNode,
              obscureText: obscureText,
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                icon: Icon(
                  prefixIcon,
                  size: 20.0,
                ),
                border: InputBorder.none,
                suffixIcon: GestureDetector(
                  child: Offstage(
                    child: const Icon(Icons.clear),
                    offstage: value == null || value == '',
                  ),
                  onTap: () {
                    if (onClear != null) {
                      onClear(formKey);
                    }
                  },
                ),
              ),
              onChanged: (value) {
                if (onChanged != null) {
                  onChanged(formKey, value);
                }
              }),
          Divider(
            height: 1.0,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
