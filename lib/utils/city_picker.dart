import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:native_opencv/utils/physisal_type.dart';
import 'package:native_opencv/utils/size_input.dart';
// import 'package:zhengda_health/app/custom_widgets/custom_text.dart';
// import 'package:zhengda_health/app/http_util/http_api.dart';
// import 'package:zhengda_health/app/http_util/http_util.dart';
// import 'package:zhengda_health/app/support/app_color.dart';

//省市区类型
enum CityType { province, city, area }

class CityAlertView extends StatefulWidget {
  final CityAlertViewDelegate? delegate;
  const CityAlertView({Key? key, required this.delegate}) : super(key: key);

  @override
  _CityAlertViewState createState() => _CityAlertViewState();
}

class _CityAlertViewState extends State<CityAlertView> {
  List<String?> _provinceList = [];

  List<String?> _cityList = [];

  List<Object> _areaList = [];
  final List<String> _listThree = [];

  GlobalKey _provinceGlobalKey = GlobalKey();

  GlobalKey _cityGlobalKey = GlobalKey();

  GlobalKey _areaGlobalKey = GlobalKey();

  int _provinceIndex = 0;

  int _cityIndex = 0;

  int _areaIndex = 0;

  @override
  void initState() {
    super.initState();
    Reclassify.getClassOne((listOnes) {
      _provinceGlobalKey = GlobalKey();
      _provinceList = listOnes;
      Reclassify.getClassTwo(0, (listTwos) {
        _cityGlobalKey = GlobalKey();
        _cityList = listTwos;
        Reclassify.getClassThree(0, 0, (listThrees) {
          _areaGlobalKey = GlobalKey();
          _areaList = listThrees;
          _listThree.clear();
          for (var element in _areaList) {
            _listThree.add((element as List)[0]);
          }
          setState(() {});
        });
      });
    });
    //   _getAreaData(
    //       cityType: CityType.province,
    //       pid: '0',
    //       onSuccess: () {
    //         _getAreaData(
    //             cityType: CityType.city,
    //             pid: _provinceList.first.adcode,
    //             onSuccess: () {
    //               _getAreaData(
    //                   cityType: CityType.area,
    //                   pid: _cityList.first.adcode,
    //                   onSuccess: () {});
    //             });
    //       });
    // }

    // void _getAreaData({CityType cityType, String pid, Function onSuccess}) {
    //   HttpUtil.getHttp('${HttpApi.areaInfo}?pid=$pid', onSuccess: (res) {
    //     List<CityAlertModel> list = List<CityAlertModel>.from(
    //         res['areaLists'].map((it) => CityAlertModel.fromJson(it)));

    //     if (cityType == CityType.province) {
    //       _provinceGlobalKey = GlobalKey();
    //       _provinceList = list;
    //     } else if (cityType == CityType.city) {
    //       _cityGlobalKey = GlobalKey();
    //       _cityList = list;
    //     } else {
    //       _areaGlobalKey = GlobalKey();
    //       _areaList = list;
    //     }
    //     setState(() {});
    //     onSuccess();
    //   });
  }

  //确定生成回调
  void _confirmClick(BuildContext context) async {
    List<num?> models = [null, null, null];
    // num _width, _height, _unit;
    if (widget.delegate != null) {
      if (_provinceIndex == _provinceList.length - 1) {
        // custom
        var value = await inputSizeDialog(context);
        if (value == null) return;
        models[0] = double.parse(value['width'] ?? '0');
        models[1] = double.parse(value['height'] ?? '0');
        models[2] = int.parse(value['unit'] ?? '0');
      } else if (_provinceIndex == _provinceList.length - 2) {
        // original sample

      } else {
        final _threeList = _areaList[_areaIndex] as List;
        models[0] = (_areaList[_areaIndex] as List)[1];
        models[1] = _threeList[2];
        models[2] = _threeList.length == 4 ? _threeList[3] : 0;
      }
      widget.delegate?.confirmClick(models);
    }
    Navigator.of(context).pop();
  }

  //取消
  void _canlClick(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 8,
        ),
        _headerWidget(context),
        Row(
          children: [
            _pickerViewWidget(
                models: _provinceList,
                key: _provinceGlobalKey,
                onSelectedItemChanged: (v) {
                  _provinceIndex = v;
                  Reclassify.getClassTwo(v, (listTwos) {
                    _cityGlobalKey = GlobalKey();
                    _cityList = listTwos;
                    Reclassify.getClassThree(v, 0, (listThrees) {
                      _areaGlobalKey = GlobalKey();
                      _areaList = listThrees;
                      _listThree.clear();
                      for (var element in _areaList) {
                        _listThree.add((element as List)[0] ?? '');
                      }
                      setState(() {});
                    });
                  });
                }),
            _pickerViewWidget(
                models: _cityList,
                key: _cityGlobalKey,
                onSelectedItemChanged: (v) {
                  _cityIndex = v;
                  Reclassify.getClassThree(_provinceIndex, _cityIndex,
                      ((listThrees) {
                    _areaGlobalKey = GlobalKey();
                    _areaList = listThrees;
                    _listThree.clear();
                    for (var element in _areaList) {
                      _listThree.add((element as List)[0]);
                    }
                    setState(() {});
                  }));
                  // _getAreaData(
                  //     cityType: CityType.area,
                  //     pid: _cityList[v].adcode,
                  //     onSuccess: () {});
                }),
            _pickerViewWidget(
                models: _listThree,
                key: _areaGlobalKey,
                onSelectedItemChanged: (v) {
                  _areaIndex = v;
                }),
          ],
        )
      ],
    ));
  }

  Widget _headerWidget(BuildContext context) {
    return Row(
      children: [
        _buttonWidget(
            title: 'Cancel',
            textColor: Colors.black,
            callback: () {
              _canlClick(context);
            }),
        Expanded(
            child: Container(
          alignment: Alignment.center,
          child: customText("Select entity target"),
        )),
        _buttonWidget(
            title: 'Ok',
            textColor: Colors.black,
            callback: () {
              _confirmClick(context);
            }),
      ],
    );
  }

  //piceerView
  Widget _pickerViewWidget({
    required List<String?> models,
    required Key key,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Expanded(
        child: SizedBox(
            height: 200,
            child: NotificationListener(
              onNotification: (Notification scrollNotification) {
                if (scrollNotification is ScrollEndNotification &&
                    scrollNotification.metrics is FixedExtentMetrics) {
                  debugPrint((scrollNotification.metrics as FixedExtentMetrics)
                      .itemIndex
                      .toString()); // Index of the list
                  onSelectedItemChanged(
                      (scrollNotification.metrics as FixedExtentMetrics)
                          .itemIndex);

                  return true;
                } else {
                  return false;
                }
              },
              child: CupertinoPicker(
                  key: key,
                  useMagnifier: true,
                  magnification: 1.2,
                  selectionOverlay: _selectionOverlayWidget(),
                  itemExtent: 34,
                  onSelectedItemChanged: (v) {},
                  children: models.map((e) => _itemsWidget(e)).toList()),
            )));
  }

  // 中间分割线
  Widget _selectionOverlayWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0),
      child: Column(
        children: [
          Divider(
            height: 1,
            color: Colors.green[100],
          ),
          Expanded(child: Container()),
          Divider(
            height: 1,
            color: Colors.green[100],
          ),
        ],
      ),
    );
  }

  // cellItems
  Widget _itemsWidget(e, {Alignment alignment = Alignment.center}) {
    return Container(
      alignment: alignment,
      child: customText(
        e,
        fontSize: 14,
      ),
    );
  }

  //公共button
  Widget _buttonWidget(
      {String? title, Color? textColor, VoidCallback? callback}) {
    return InkWell(
      onTap: callback,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(left: 16, right: 16),
        height: 40,
        child: customText(
          title ?? '',
          color: textColor,
        ),
      ),
    );
  }
}

Widget customText(String title, {Color? color, double? fontSize}) {
  return Text(title, style: TextStyle(color: color, fontSize: fontSize));
}

abstract class CityAlertViewDelegate {
  void confirmClick(List<num?> models) {}
}

// class CityAlertModel {
//   int id;
//   String pAdcode;
//   String adcode;
//   String name;
//   String level;
//   String pinyin;
//   String first;
//   String lng;
//   String lat;

//   CityAlertModel(
//       {this.id,
//       this.pAdcode,
//       this.adcode,
//       this.name,
//       this.level,
//       this.pinyin,
//       this.first,
//       this.lng,
//       this.lat});

//   CityAlertModel.fromJson(Map<String, dynamic> json) {
//     id = json['id'];
//     pAdcode = json['p_adcode'];
//     adcode = json['adcode'];
//     name = json['name'];
//     level = json['level'];
//     pinyin = json['pinyin'];
//     first = json['first'];
//     lng = json['lng'];
//     lat = json['lat'];
//   }

//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = new Map<String, dynamic>();
//     data['id'] = this.id;
//     data['p_adcode'] = this.pAdcode;
//     data['adcode'] = this.adcode;
//     data['name'] = this.name;
//     data['level'] = this.level;
//     data['pinyin'] = this.pinyin;
//     data['first'] = this.first;
//     data['lng'] = this.lng;
//     data['lat'] = this.lat;
//     return data;
//   }
// }
