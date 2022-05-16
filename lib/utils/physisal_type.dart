typedef ListStringCallback = void Function(List<String?> strData);
typedef ListObjectCallback = void Function(List<Object> strData);

class Reclassify {
  static const physisalTypes = [
    [
      "Paper",
      [
        [
          "A Series",
          [
            ["4A0", 1682, 2378],
            ["2A0", 1189, 1682],
            ["A0", 841, 1189],
            ["A1", 594, 841],
            ["A2", 420, 594],
            ["A3", 297, 420],
            ["A4", 210, 297],
            ["A5", 148, 210],
            ["A6", 105, 148],
            ["A7", 74, 105],
            ["A8", 52, 74],
            ["A9", 37, 52],
            ["A10", 26, 37],
          ]
        ],
        [
          "B Series",
          [
            ["B0", 1000, 1414],
            ["B1", 707, 1000],
            ["B2", 500, 707],
            ["B3", 353, 500],
            ["B4", 250, 353],
            ["B5", 176, 250],
            ["B6", 125, 176],
            ["B7", 88, 125],
            ["B8", 62, 99],
            ["B9", 44, 62],
            ["B10", 31, 44],
          ]
        ],
        [
          "C Series",
          [
            ["C0", 917, 1297],
            ["C1", 648, 917],
            ["C2", 458, 648],
            ["C3", 324, 458],
            ["C4", 229, 324],
            ["C5", 162, 229],
            ["C6", 114, 162],
            ["C7", 81, 114],
            ["C8", 57, 81],
            ["C9", 40, 57],
            ["C10", 28, 40],
            ["DL", 110, 224],
            ["C7/6", 81, 162]
          ]
        ]
      ]
    ],
    [
      "Ceramic tile",
      [
        [
          "Wall tile",
          [
            ["100X100", 100, 100],
            ["150X150", 150, 150],
            ["50X100", 50, 100],
            ["50X150", 50, 150],
            ["200X200", 200, 200],
            ["200X300", 200, 300],
            ["100X200", 100, 200],
            ["100X250", 100, 250],
            ["150X250", 150, 250],
            ["250X300", 250, 300],
            ["250X400", 250, 400],
            ["300X450", 300, 450],
          ]
        ],
        [
          "Floor tile",
          [
            ["300X300", 300, 300],
            ["300X600", 300, 600],
            ["330X330", 330, 330],
            ["333X333", 333, 333],
            ["400X400", 400, 400],
            ["400X800", 400, 800],
            ["450X450", 450, 450],
            ["450X900", 450, 900],
            ["500X500", 500, 500],
            ["600X600", 600, 600],
            ["600X900", 600, 900],
            ["800X800", 800, 800],
            ["1000X1000", 1000, 1000],
            ["1200X1200", 1200, 1200],
          ]
        ]
      ]
    ],
    [
      "Custom",
      [
        [
          null,
          [
            [null]
          ]
        ]
      ]
    ]
  ];
  static void getClassOne(ListStringCallback onSuccess) {
    List<String> one = [];
    for (int i = 0; i < physisalTypes.length; i++) {
      one.add(physisalTypes[i][0] as String);
    }
    onSuccess(one);
  }

  static void getClassTwo(int oneIndex, ListStringCallback onSuccess) {
    List<String?> two = [];
    for (int i = 0; i < (physisalTypes[oneIndex][1] as List).length; i++) {
      String? _title = (physisalTypes[oneIndex][1] as List)[i][0];
      two.add(_title ?? '');
    }
    onSuccess(two);
  }

  static void getClassThree(
      int oneIndex, int twoIndex, ListObjectCallback onSuccess) {
    onSuccess((physisalTypes[oneIndex][1] as List)[twoIndex][1]);
  }
}
