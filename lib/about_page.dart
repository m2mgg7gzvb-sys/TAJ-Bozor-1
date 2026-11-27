import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'lang_store.dart';
import 'theme.dart';

/// Экран «О приложении»: авторство открытых данных, на которых построены списки марок, моделей и поколений.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static final _repo = Uri.parse('https://github.com/gor3a/vehicle-makes-models');
  static final _license = Uri.parse('https://opendatacommons.org/licenses/odbl/1-0/');

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('О приложении', 'Дар бораи барнома'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            tr(
              'TAJ Bozor — торговая площадка для Таджикистана.',
              'TAJ Bozor — майдони савдо барои Тоҷикистон.',
            ),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              '*WhatsApp принадлежит компании Meta, которая признана экстремистской и запрещена на территории РФ.',
              '*WhatsApp ба ширкати Meta тааллуқ дорад, ки экстремистӣ эътироф шуда ва дар қаламрави Федератсияи Русия манъ аст.',
            ),
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 22),
          Text(
            tr('Источники данных', 'Манбаъҳои маълумот'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Списки марок, моделей и поколений автомобилей взяты из открытого набора данных '
                  '«vehicle-makes-models» (проект gor3a). Исходные данные — autoevolution.com. '
                  'Набор распространяется по лицензии Open Database License (ODbL) 1.0. '
                  'Из него взяты только марки, модели и поколения с годами выпуска, которые есть в приложении; '
                  'данные при этом изменены (сокращены и приведены к каталогу приложения).',
              'Рӯйхати маркаҳо, моделҳо ва наслҳои автомобилҳо аз маҷмӯаи кушодаи маълумоти '
                  '«vehicle-makes-models» (лоиҳаи gor3a) гирифта шудааст. Манбаи аслӣ — autoevolution.com. '
                  'Маҷмӯа бо литсензияи Open Database License (ODbL) 1.0 паҳн мешавад. '
                  'Аз он танҳо маркаҳо, моделҳо ва наслҳо бо солҳои истеҳсол, ки дар барнома мавҷуданд, гирифта шудаанд; '
                  'маълумот тағйир дода шудааст (кӯтоҳ ва ба каталоги барнома мувофиқ карда шудааст).',
            ),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _open(_repo),
            child: const Text('github.com/gor3a/vehicle-makes-models'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _open(_license),
            child: const Text('ODbL 1.0'),
          ),
          const SizedBox(height: 18),
          Text(
            tr(
              'Производное данных из ODbL-набора распространяется по той же лицензии ODbL 1.0.',
              'Ҳосилаи маълумоти маҷмӯаи ODbL низ бо ҳамон литсензияи ODbL 1.0 паҳн мешавад.',
            ),
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}
