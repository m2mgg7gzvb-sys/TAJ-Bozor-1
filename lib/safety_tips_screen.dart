import 'package:flutter/material.dart';

import 'theme.dart';

/// Памятка «Как безопасно купить и продать».
class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const _tips = [
    (Icons.place_outlined, 'Встречайтесь в людном месте', 'Выбирайте магазин, офис или отделение банка, а не пустынные места и чужие квартиры.'),
    (Icons.payments_outlined, 'Осмотрите товар до оплаты', 'Не переводите деньги и не вносите предоплату за товар, который не видели.'),
    (Icons.account_balance_wallet_outlined, 'Не сообщайте коды из SMS', 'Ни один сотрудник TAJ Bozor не просит код подтверждения, пароль или данные карты.'),
    (Icons.chat_outlined, 'Общайтесь в приложении', 'Переписка в чате TAJ Bozor сохраняется и помогает разобрать спорную ситуацию.'),
    (Icons.price_check_outlined, 'Сравнивайте цены', 'Если цена сильно ниже похожих объявлений, будьте внимательнее: возможен обман.'),
    (Icons.description_outlined, 'Проверяйте документы', 'Для авто и недвижимости попросите оригиналы документов и проверьте их перед сделкой.'),
    (Icons.flag_outlined, 'Сообщайте о подозрительном', 'Кнопка «Пожаловаться» в объявлении или в профиле продавца отправит жалобу модераторам.'),
    (Icons.block_rounded, 'Блокируйте назойливых', 'В профиле пользователя можно заблокировать продавца или покупателя: его объявления перестанут показываться.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Безопасная сделка')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _tips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, title, text) = _tips[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(text, style: const TextStyle(color: AppColors.muted, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
