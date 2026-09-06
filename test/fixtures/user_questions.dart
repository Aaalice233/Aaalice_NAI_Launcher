import 'package:nai_launcher/data/models/interaction/user_question.dart';

Map<String, dynamic> questionJson(String id) => {
  'id': id,
  'title': '你希望采用哪种角色呈现方向？',
  'recommended_option_id': 'classic',
  'options': [
    {'id': 'classic', 'label': '经典造型', 'description': '保留原作服装与角色辨识特征。'},
    {'id': 'daily', 'label': '日常服装', 'description': '保留外观特征，换成轻松的日常服装。'},
    {'id': 'formal', 'label': '正式礼服', 'description': '保留角色身份，采用正式场合的礼服设计。'},
  ],
};

List<UserQuestion> testQuestions() => [
  UserQuestion.fromJson(questionJson('appearance')),
  UserQuestion.fromJson({...questionJson('scene'), 'title': '第二个角色采用哪种方向？'}),
];
