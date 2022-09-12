// AlertDialog
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:native_opencv/components/form_util.dart';

Future<Map<String, String>?> inputSizeDialog(BuildContext context) {
  const List<String> _units = ["mm", "cm", "m", "km"];
  String curUint = _units[0];
  double _enterWidth = 0;
  double _enterHeight = 0;
  Map<String, Map<String, Object>> _formData = {
    'width': {
      'value': '',
      'controller': TextEditingController(),
      'obsecure': false,
    },
    'height': {
      'value': '',
      'controller': TextEditingController(),
      'obsecure': false,
    },
  };

  _handleTextFieldChanged(String formKey, String value) {
    // setState(() {
    var _value = double.tryParse(value);
    if (_value != null && !_value.isNaN && !_value.isInfinite) {
      if (formKey == _formData.keys.first) {
        _enterWidth = _value;
      } else if (formKey == _formData.keys.last) {
        _enterHeight = _value;
      }
    } else {
      if (formKey == _formData.keys.first) {
        _enterWidth = 0;
      } else if (formKey == _formData.keys.last) {
        _enterHeight = 0;
      }
    }
    _formData[formKey]?['value'] = value;
    // });
  }

  _handleClear(String formKey) {
    // setState(() {
    _formData[formKey]?['value'] = '';
    (_formData[formKey]?['controller'] as TextEditingController)?.clear();
    // });
  }

  return showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          // 嵌套一个StatefulBuilder 部件
          builder: (context, setState) => AlertDialog(
                title: Text('Input entity size'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: [
                      FormUtil.textField(
                        'width',
                        _formData['width']?['value'] as String,
                        controller: _formData['width']?['controller']
                            as TextEditingController,
                        hintText: 'Enter width',
                        prefixIcon: Icons.width_normal,
                        inputFormatters: [
                          FilteringTextInputFormatter(RegExp("[0-9.]"),
                              allow: true),
                        ],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (formKey, value) {
                          setState(() {
                            _handleTextFieldChanged(formKey, value);
                          });
                        },
                        onClear: _handleClear,
                      ),
                      FormUtil.textField(
                        'height',
                        _formData['height']?['value'] as String?,
                        controller: _formData['height']?['controller']
                            as TextEditingController,
                        hintText: 'Enter height',
                        prefixIcon: Icons.height,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (formKey, value) {
                          setState(() {
                            _handleTextFieldChanged(formKey, value);
                          });
                        },
                        onClear: _handleClear,
                      ),

                      // 单位组合框
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Unit",
                              // style: TextStyle(fontSize: 15),
                              // textScaleFactor: _leadingFactor,
                            ),
                            DropdownButton<String>(
                              iconSize: 40,
                              iconEnabledColor: Colors.blue,
                              hint: Text(
                                "Unit",
                                // style: TextStyle(fontSize: 15),
                                // textScaleFactor: _leadingFactor,
                              ),
                              // isExpanded: true,
                              underline: Container(height: 0),
                              items: _units.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    // style: TextStyle(fontSize: 15),
                                    // textScaleFactor: _leadingFactor,
                                  ),
                                  // child: new Text(value),
                                );
                              }).toList(),
                              value: curUint,
                              onChanged: (type) {
                                // print("=======$type");
                                curUint = type ?? _units[0];
                                setState(() {
                                  // typeChange(type ?? "Accelerometer");
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: (_enterWidth > 0 && _enterHeight > 0)
                          ? () {
                              Navigator.of(context).pop<Map<String, String>>({
                                "width": _formData['width']?['value'] as String,
                                'height':
                                    _formData['height']?['value'] as String,
                                "unit": _units.indexOf(curUint).toString()
                              });
                            }
                          : null,
                      child: Text('Ok')),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel')),
                ],
              )));
}
