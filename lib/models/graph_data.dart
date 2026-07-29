// ============================================================
// FULL GRAPH DATA + A* INTEGRATION
// ============================================================

// 1. Định nghĩa tất cả nodes với ID
import 'dart:math';

import 'package:botanica_ar/models/a_star_algorithm.dart';

final List<PathNode> graphPathNodes = [
  PathNode(id: '1', x: -135.2031, y: 8.9552),
  PathNode(id: '2', x: -134.6223, y: 7.8975),
  PathNode(id: '3', x: -134.9737, y: 9.3857),
  PathNode(id: '4', x: -135.3179, y: 10.0360),
  PathNode(id: '5', x: -135.3179, y: 10.6382),
  PathNode(id: '6', x: -134.8403, y: 11.1427),
  PathNode(id: '7', x: -134.1530, y: 11.1427),
  PathNode(id: '8', x: -133.2754, y: 11.3314),
  PathNode(id: '9', x: -132.6586, y: 11.7190),
  PathNode(id: '10', x: -131.9554, y: 12.1610),
  PathNode(id: '11', x: -131.5648, y: 12.7740),
  PathNode(id: '12', x: -130.8462, y: 13.3206),
  PathNode(id: '13', x: -130.5426, y: 13.7822),
  PathNode(id: '14', x: -130.1991, y: 14.3632),
  PathNode(id: '15', x: -129.8222, y: 15.0008),
  PathNode(id: '16', x: -128.7644, y: 15.0008),
  PathNode(id: '17', x: -127.5994, y: 14.9126),
  PathNode(id: '18', x: -129.1322, y: 15.0008),
  PathNode(id: '19', x: -130.3548, y: 15.0008),
  PathNode(id: '20', x: -130.8444, y: 15.0008),
  PathNode(id: '21', x: -131.3107, y: 15.0008),
  PathNode(id: '22', x: -131.8921, y: 15.0008),
  PathNode(id: '23', x: -132.4351, y: 15.0008),
  PathNode(id: '24', x: -130.4866, y: 13.7822),
  PathNode(id: '25', x: -134.9295, y: 11.6840),
  PathNode(id: '26', x: -135.0242, y: 12.2592),
  PathNode(id: '27', x: -135.0242, y: 12.8884),
  PathNode(id: '28', x: -135.1896, y: 13.4985),
  PathNode(id: '29', x: -135.1896, y: 13.9879),
  PathNode(id: '30', x: -135.4137, y: 11.1564),
  PathNode(id: '31', x: -136.4625, y: 10.7244),
  PathNode(id: '32', x: -136.7658, y: 10.3243),
  PathNode(id: '33', x: -137.5081, y: 10.2747),
  PathNode(id: '34', x: -138.0620, y: 10.0672),
  PathNode(id: '35', x: -138.7172, y: 9.9832),
  PathNode(id: '36', x: -139.3304, y: 9.9832),
  PathNode(id: '37', x: -140.0859, y: 9.3577),
  PathNode(id: '38', x: -140.0937, y: 8.2654),
  PathNode(id: '39', x: -140.0937, y: 7.2185),
  PathNode(id: '40', x: -140.0937, y: 6.0266),
  PathNode(id: '41', x: -139.4643, y: 5.1106),
  PathNode(id: '42', x: -138.4508, y: 5.1106),
  PathNode(id: '43', x: -137.5812, y: 5.6391),
  PathNode(id: '44', x: -137.0252, y: 6.2966),
  PathNode(id: '45', x: -136.1210, y: 5.6551),
  PathNode(id: '46', x: -135.4414, y: 5.2939),
  PathNode(id: '47', x: -134.4675, y: 5.1033),
  PathNode(id: '48', x: -133.6744, y: 5.1033),
  PathNode(id: '49', x: -133.2025, y: 5.1033),
  PathNode(id: '50', x: -136.4245, y: 7.0070),
  PathNode(id: '51', x: -135.6235, y: 7.6674),
  PathNode(id: '52', x: -133.5866, y: 7.8975),
  PathNode(id: '53', x: -132.4497, y: 7.8975),
  PathNode(id: '54', x: -131.2683, y: 7.8975),
  PathNode(id: '55', x: -130.0969, y: 7.8975),
  PathNode(id: '56', x: -129.6964, y: 7.0170),
  PathNode(id: '57', x: -129.4060, y: 5.9164),
  PathNode(id: '58', x: -130.5474, y: 5.0959),
  PathNode(id: '59', x: -131.3684, y: 5.0959),
  PathNode(id: '60', x: -129.6563, y: 8.8281),
  PathNode(id: '61', x: -128.8454, y: 9.6185),
  PathNode(id: '62', x: -128.3247, y: 10.3490),
  PathNode(id: '63', x: -129.2458, y: 10.7692),
  PathNode(id: '64', x: -130.0885, y: 11.1536),
  PathNode(id: '65', x: -130.7176, y: 11.1536),
  PathNode(id: '66', x: -127.5994, y: 10.5353),
  PathNode(id: '67', x: -128.4649, y: 5.2973),
  PathNode(id: '68', x: -127.3913, y: 5.2973),
  PathNode(id: '69', x: -126.2411, y: 5.2973),
  PathNode(id: '70', x: -125.6452, y: 6.2188),
  PathNode(id: '71', x: -125.0599, y: 7.0969),
  PathNode(id: '72', x: -125.0599, y: 8.1888),
  PathNode(id: '73', x: -125.0599, y: 8.8959),
  PathNode(id: '74', x: -125.7902, y: 9.8018),
  PathNode(id: '75', x: -124.7639, y: 9.8018),
  PathNode(id: '76', x: -124.7639, y: 11.0139),
  PathNode(id: '77', x: -124.7639, y: 12.2026),
  PathNode(id: '78', x: -124.7639, y: 11.7267),
  PathNode(id: '79', x: -126.7667, y: 9.9759),
  PathNode(id: '80', x: -127.5994, y: 11.4757),
  PathNode(id: '81', x: -127.5994, y: 12.3817),
  PathNode(id: '82', x: -127.5994, y: 13.2158),
  PathNode(id: '83', x: -127.5994, y: 14.0871),
  PathNode(id: '84', x: -129.5883, y: 15.0008),
  PathNode(id: '85', x: -131.1365, y: 15.0008),
  PathNode(id: '86', x: -131.7305, y: 15.0008),
  PathNode(id: '87', x: -132.5314, y: 15.0008),
  PathNode(id: '88', x: -127.1004, y: 15.7241),
  PathNode(id: '89', x: -126.4147, y: 16.4475),
  PathNode(id: '90', x: -125.5749, y: 17.2185),
  PathNode(id: '91', x: -124.7915, y: 16.3401),
  PathNode(id: '92', x: -124.7915, y: 15.4601),
  PathNode(id: '93', x: -124.7915, y: 14.4041),
  PathNode(id: '94', x: -124.7915, y: 13.6219),
  PathNode(id: '95', x: -124.9889, y: 18.3018),
  PathNode(id: '96', x: -124.9889, y: 19.4242),
  PathNode(id: '97', x: -125.6042, y: 20.3806),
  PathNode(id: '98', x: -126.5962, y: 20.6638),
  PathNode(id: '99', x: -127.6587, y: 20.6638),
  PathNode(id: '100', x: -128.7504, y: 20.6638),
  PathNode(id: '101', x: -129.1695, y: 19.5922),
  PathNode(id: '102', x: -129.4806, y: 20.6638),
  PathNode(id: '103', x: -129.1900, y: 18.5399),
  PathNode(id: '104', x: -129.8240, y: 18.0510),
  PathNode(id: '105', x: -130.3268, y: 17.5724),
  PathNode(id: '106', x: -130.5887, y: 20.6638),
  PathNode(id: '107', x: -131.6385, y: 20.6638),
  PathNode(id: '108', x: -132.8536, y: 20.6638),
  PathNode(id: '109', x: -133.8675, y: 20.6638),
  PathNode(id: '110', x: -134.9251, y: 20.6638),
  PathNode(id: '111', x: -136.0312, y: 20.6638),
  PathNode(id: '112', x: -136.5435, y: 19.5584),
  PathNode(id: '113', x: -136.5435, y: 18.3200),
  PathNode(id: '114', x: -136.5435, y: 17.2870),
  PathNode(id: '115', x: -136.5435, y: 16.1084),
  PathNode(id: '116', x: -136.8948, y: 15.0472),
  PathNode(id: '117', x: -137.7953, y: 14.3836),
  PathNode(id: '118', x: -138.8259, y: 14.3836),
  PathNode(id: '119', x: -139.9870, y: 13.9059),
  PathNode(id: '120', x: -140.3313, y: 12.9068),
  PathNode(id: '121', x: -140.3313, y: 11.8499),
  PathNode(id: '122', x: -140.3313, y: 10.5967),
  PathNode(id: '123', x: -140.8526, y: 9.3577),
  PathNode(id: '124', x: -141.9412, y: 9.3577),
  PathNode(id: '125', x: -143.0741, y: 9.2639),
  PathNode(id: '126', x: -144.2515, y: 9.2639),
  PathNode(id: '127', x: -145.3524, y: 9.2639),
  PathNode(id: '128', x: -146.4991, y: 9.2639),
  PathNode(id: '129', x: -147.7988, y: 9.2639),
  PathNode(id: '130', x: -149.1443, y: 9.2639),
  PathNode(id: '131', x: -150.0617, y: 9.2639),
  PathNode(id: '132', x: -151.2390, y: 9.2639),
  PathNode(id: '133', x: -152.3552, y: 10.1349),
  PathNode(id: '134', x: -153.5172, y: 10.4405),
  PathNode(id: '135', x: -154.8169, y: 10.4405),
  PathNode(id: '136', x: -155.9636, y: 10.0891),
  PathNode(id: '137', x: -156.9031, y: 9.3709),
  PathNode(id: '138', x: -156.9031, y: 8.2400),
  PathNode(id: '139', x: -156.9031, y: 5.7726),
  PathNode(id: '140', x: -156.9031, y: 3.4640),
  PathNode(id: '141', x: -156.9031, y: 1.4283),
  PathNode(id: '142', x: -157.9182, y: 1.5991),
  PathNode(id: '143', x: -158.6778, y: 1.5991),
  PathNode(id: '144', x: -159.8234, y: 1.5991),
  PathNode(id: '145', x: -159.8234, y: 0.8400),
  PathNode(id: '146', x: -159.8234, y: -0.2993),
  PathNode(id: '147', x: -159.8234, y: -1.4781),
  PathNode(id: '148', x: -160.4360, y: -2.4118),
  PathNode(id: '149', x: -159.6195, y: -3.4443),
  PathNode(id: '150', x: -159.4421, y: -4.0095),
  PathNode(id: '151', x: -158.8241, y: -3.7426),
  PathNode(id: '152', x: -160.0409, y: -4.2681),
  PathNode(id: '153', x: -161.5193, y: -2.4118),
  PathNode(id: '154', x: -162.5922, y: -2.4118),
  PathNode(id: '155', x: -163.6557, y: -2.4118),
  PathNode(id: '156', x: -164.8322, y: -2.4118),
  PathNode(id: '157', x: -165.7864, y: -3.1078),
  PathNode(id: '158', x: -165.7864, y: -4.1967),
  PathNode(id: '159', x: -165.7864, y: -5.2517),
  PathNode(id: '160', x: -164.5958, y: -5.6774),
  PathNode(id: '161', x: -163.9014, y: -5.6774),
  PathNode(id: '162', x: -163.2010, y: -5.6774),
  PathNode(id: '163', x: -162.4534, y: -5.9714),
  PathNode(id: '164', x: -161.7934, y: -6.4364),
  PathNode(id: '165', x: -161.2584, y: -7.3901),
  PathNode(id: '166', x: -160.9934, y: -7.9133),
  PathNode(id: '167', x: -161.2065, y: -8.8991),
  PathNode(id: '168', x: -159.9725, y: -8.7493),
  PathNode(id: '169', x: -165.7451, y: -6.1544),
  PathNode(id: '170', x: -165.7451, y: -7.2985),
  PathNode(id: '171', x: -165.7451, y: -8.3255),
  PathNode(id: '172', x: -165.7451, y: -9.4806),
  PathNode(id: '173', x: -165.4555, y: -10.4879),
  PathNode(id: '174', x: -164.6213, y: -11.1595),
  PathNode(id: '175', x: -163.6133, y: -11.1595),
  PathNode(id: '176', x: -162.7151, y: -10.4110),
  PathNode(id: '177', x: -161.9356, y: -9.6298),
  PathNode(id: '178', x: -161.1512, y: -10.5748),
  PathNode(id: '179', x: -160.7634, y: -10.8314),
  PathNode(id: '180', x: -160.3884, y: -11.3164),
  PathNode(id: '181', x: -160.1585, y: -12.0061),
  PathNode(id: '182', x: -160.6084, y: -10.9464),
  PathNode(id: '183', x: -158.8596, y: -8.7493),
  PathNode(id: '184', x: -157.9130, y: -9.3514),
  PathNode(id: '185', x: -157.5920, y: -10.4605),
  PathNode(id: '186', x: -156.7666, y: -11.1845),
  PathNode(id: '187', x: -155.6935, y: -11.1845),
  PathNode(id: '188', x: -154.6755, y: -11.1845),
  PathNode(id: '189', x: -153.7125, y: -10.7904),
  PathNode(id: '190', x: -153.0807, y: -9.8647),
  PathNode(id: '191', x: -153.0807, y: -8.8393),
  PathNode(id: '192', x: -153.2036, y: -7.7970),
  PathNode(id: '193', x: -153.7755, y: -6.8140),
  PathNode(id: '194', x: -154.8198, y: -6.4770),
  PathNode(id: '195', x: -155.7224, y: -5.8381),
  PathNode(id: '196', x: -155.7224, y: -4.7228),
  PathNode(id: '197', x: -155.5456, y: -3.7046),
  PathNode(id: '198', x: -154.9779, y: -2.8678),
  PathNode(id: '199', x: -155.9545, y: -2.0948),
  PathNode(id: '200', x: -153.8701, y: -3.4843),
  PathNode(id: '201', x: -153.1231, y: -4.0577),
  PathNode(id: '202', x: -152.3373, y: -4.2876),
  PathNode(id: '203', x: -154.3981, y: -2.3533),
  PathNode(id: '204', x: -153.5159, y: -1.5704),
  PathNode(id: '205', x: -152.9914, y: -0.5457),
  PathNode(id: '206', x: -152.9914, y: 0.5041),
  PathNode(id: '207', x: -153.6289, y: 1.2758),
  PathNode(id: '208', x: -154.7872, y: 1.4283),
  PathNode(id: '209', x: -155.8556, y: 1.4283),
  PathNode(id: '210', x: -156.9031, y: 2.3346),
  PathNode(id: '211', x: -156.9031, y: 4.5478),
  PathNode(id: '212', x: -156.9031, y: 6.9526),
];

// 2. Hàm build edges từ graph data
void buildGraphEdges(List<PathNode> nodes) {
  // Map id -> node để lookup nhanh
  final map = {for (final n in nodes) n.id: n};

  double dist(PathNode a, PathNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  void connect(String idA, String idB) {
    final a = map[idA]!;
    final b = map[idB]!;
    final w = dist(a, b);
    a.edges.add(PathEdge(target: b, weight: w));
    b.edges.add(PathEdge(target: a, weight: w)); // 2 chiều
  }

  // Edges từ graph data
  connect('1', '2');
  connect('1', '3');
  connect('3', '4');
  connect('4', '5');
  connect('5', '6');
  connect('6', '7');
  connect('7', '8');
  connect('8', '9');
  connect('9', '10');
  connect('10', '11');
  connect('11', '12');
  connect('12', '13');
  connect('13', '14');
  connect('14', '15');
  connect('15', '16');
  connect('16', '17');
  connect('16', '18');
  connect('15', '18');
  connect('15', '19');
  connect('19', '20');
  connect('20', '21');
  connect('21', '22');
  connect('22', '23');
  connect('14', '19');
  connect('14', '24');
  connect('12', '24');
  connect('6', '25');
  connect('25', '26');
  connect('26', '27');
  connect('27', '28');
  connect('28', '29');
  connect('25', '30');
  connect('30', '31');
  connect('31', '32');
  connect('32', '33');
  connect('33', '34');
  connect('34', '35');
  connect('35', '36');
  connect('36', '37');
  connect('37', '38');
  connect('38', '39');
  connect('39', '40');
  connect('40', '41');
  connect('41', '42');
  connect('42', '43');
  connect('43', '44');
  connect('44', '45');
  connect('45', '46');
  connect('46', '47');
  connect('47', '48');
  connect('48', '49');
  connect('44', '50');
  connect('50', '51');
  connect('2', '51');
  connect('2', '52');
  connect('52', '53');
  connect('53', '54');
  connect('54', '55');
  connect('55', '56');
  connect('56', '57');
  connect('57', '58');
  connect('58', '59');
  connect('55', '60');
  connect('60', '61');
  connect('61', '62');
  connect('62', '63');
  connect('63', '64');
  connect('64', '65');
  connect('62', '66');
  connect('57', '67');
  connect('67', '68');
  connect('68', '69');
  connect('69', '70');
  connect('70', '71');
  connect('71', '72');
  connect('72', '73');
  connect('73', '74');
  connect('74', '75');
  connect('75', '76');
  connect('76', '77');
  connect('77', '78');
  connect('76', '78');
  connect('74', '79');
  connect('66', '79');
  connect('66', '80');
  connect('80', '81');
  connect('81', '82');
  connect('82', '83');
  connect('17', '83');
  connect('16', '84');
  connect('19', '84');
  connect('19', '85');
  connect('85', '86');
  connect('86', '87');
  connect('17', '88');
  connect('88', '89');
  connect('89', '90');
  connect('90', '91');
  connect('91', '92');
  connect('92', '93');
  connect('93', '94');
  connect('90', '95');
  connect('95', '96');
  connect('96', '97');
  connect('97', '98');
  connect('98', '99');
  connect('99', '100');
  connect('100', '101');
  connect('100', '102');
  connect('101', '102');
  connect('101', '103');
  connect('103', '104');
  connect('104', '105');
  connect('102', '106');
  connect('106', '107');
  connect('107', '108');
  connect('108', '109');
  connect('109', '110');
  connect('110', '111');
  connect('111', '112');
  connect('112', '113');
  connect('113', '114');
  connect('114', '115');
  connect('115', '116');
  connect('116', '117');
  connect('117', '118');
  connect('118', '119');
  connect('119', '120');
  connect('120', '121');
  connect('121', '122');
  connect('37', '122');
  connect('37', '123');
  connect('123', '124');
  connect('124', '125');
  connect('125', '126');
  connect('126', '127');
  connect('127', '128');
  connect('128', '129');
  connect('129', '130');
  connect('130', '131');
  connect('131', '132');
  connect('132', '133');
  connect('133', '134');
  connect('134', '135');
  connect('135', '136');
  connect('136', '137');
  connect('137', '138');
  connect('138', '139');
  connect('139', '140');
  connect('140', '141');
  connect('141', '142');
  connect('142', '143');
  connect('143', '144');
  connect('144', '145');
  connect('145', '146');
  connect('146', '147');
  connect('147', '148');
  connect('148', '149');
  connect('149', '150');
  connect('150', '151');
  connect('150', '152');
  connect('148', '153');
  connect('153', '154');
  connect('154', '155');
  connect('155', '156');
  connect('156', '157');
  connect('157', '158');
  connect('158', '159');
  connect('159', '160');
  connect('160', '161');
  connect('161', '162');
  connect('162', '163');
  connect('163', '164');
  connect('164', '165');
  connect('165', '166');
  connect('166', '167');
  connect('166', '168');
  connect('160', '169');
  connect('159', '169');
  connect('169', '170');
  connect('170', '171');
  connect('171', '172');
  connect('172', '173');
  connect('173', '174');
  connect('174', '175');
  connect('175', '176');
  connect('176', '177');
  connect('177', '178');
  connect('178', '179');
  connect('179', '180');
  connect('180', '181');
  connect('180', '182');
  connect('178', '182');
  connect('167', '177');
  connect('167', '168');
  connect('168', '183');
  connect('183', '184');
  connect('184', '185');
  connect('185', '186');
  connect('186', '187');
  connect('187', '188');
  connect('188', '189');
  connect('189', '190');
  connect('190', '191');
  connect('191', '192');
  connect('192', '193');
  connect('193', '194');
  connect('194', '195');
  connect('195', '196');
  connect('196', '197');
  connect('197', '198');
  connect('198', '199');
  connect('198', '200');
  connect('200', '201');
  connect('201', '202');
  connect('198', '203');
  connect('203', '204');
  connect('204', '205');
  connect('205', '206');
  connect('206', '207');
  connect('207', '208');
  connect('208', '209');
  connect('141', '209');
  connect('141', '210');
  connect('140', '210');
  connect('140', '211');
  connect('139', '211');
  connect('139', '212');
  connect('138', '212');
}
