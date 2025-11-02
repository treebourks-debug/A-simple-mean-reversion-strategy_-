# Simple Trading Strategy EA - Ръководство за използване

## Описание

`Simple_Trading_Strategy.mq5` е пълнофункционален Expert Advisor (EA) за MetaTrader 5, който имплементира Mean Reversion стратегията с тренд филтър, описана в README.md.

## Индикатори

### 1. SMMA 200 (Smoothed Moving Average)
- **Роля**: Тренд филтър
- **Период**: 200 (конфигурируем)
- **Логика**: 
  - Над SMMA 200 → Само BUY позиции
  - Под SMMA 200 → Само SELL позиции

### 2. QQE Signals
- **Роля**: Тригери за влизане в позиция
- **Параметри**:
  - RSI Length: 14
  - RSI Smoothing: 5
  - QQE Factor: 4.238
  - Threshold: 10
- **Сигнали**:
  - QQExlong == 1 → BUY сигнал
  - QQExshort == 1 → SELL сигнал

### 3. Mean Reversion Channel (MRC)
- **Роля**: Зони за действие (динамична подкрепа/съпротива)
- **Параметри**:
  - Length: 200
  - Inner Channel Multiplier: 1.0
  - Outer Channel Multiplier: 2.415
  - Filter Type: SuperSmoother
- **Зони**:
  - Outer/Inner bands → Влизане в позиция
  - Mean line → Зона за изход

### 4. Heikin-Ashi Volume
- **Роля**: Потвърждение на обема
- **Параметри**:
  - Divider: 4.0
  - MA Length: 20
  - MA Type: SMA
- **Условие**: Volume >= Volume MA

## Условия за влизане

### BUY Позиция
1. Close > SMMA(200)
2. Цената достигна долната зона на MRC (Outer или Inner band)
3. QQE даде BUY сигнал (QQExlong == 1)
4. Heikin-Ashi Volume >= Volume MA
5. Брой отворени позиции < MaxPositions

### SELL Позиция
1. Close < SMMA(200)
2. Цената достигна горната зона на MRC (Outer или Inner band)
3. QQE даде SELL сигнал (QQExshort == 1)
4. Heikin-Ashi Volume >= Volume MA
5. Брой отворени позиции < MaxPositions

## Управление на риска

### Lot Size
Формула: `(AccountBalance * RiskPercent / 100) / (ATR * ATR_SL_Multiplier * PointValue)`

### Stop Loss
- Базиран на ATR: `ATR * ATR_SL_Multiplier`
- По подразбиране: 2.0 × ATR

### Take Profit
- Базиран на ATR: `ATR * ATR_TP_Multiplier`
- По подразбиране: 3.0 × ATR

## Входни параметри

### Основни параметри
- **MagicNumber**: 123456 - Уникален идентификатор за позициите
- **RiskPercent**: 2.0% - Процент от баланса за риск на сделка
- **MaxPositions**: 3 - Максимален брой едновременни позиции

### ATR параметри
- **ATR_Period**: 14 - Период за изчисление на ATR
- **ATR_SL_Multiplier**: 2.0 - Множител за Stop Loss
- **ATR_TP_Multiplier**: 3.0 - Множител за Take Profit

### SMMA 200 параметри
- **SMMA_Period**: 200 - Период на SMMA

### QQE параметри
- **RSI_Period**: 14 - RSI период
- **RSI_Smoothing**: 5 - RSI изглаждане
- **QQE_Factor**: 4.238 - QQE фактор
- **QQE_Threshold**: 10 - QQE праг

### Mean Reversion Channel параметри
- **MRC_Length**: 200 - Дължина на канала
- **MRC_InnerMult**: 1.0 - Вътрешен канал множител
- **MRC_OuterMult**: 2.415 - Външен канал множител

### Heikin-Ashi Volume параметри
- **HA_Divider**: 4.0 - Volume делител
- **HA_MA_Length**: 20 - Volume MA период

## Инсталация

1. Копирайте файла `Simple_Trading_Strategy.mq5` в папката:
   ```
   MetaTrader 5/MQL5/Experts/
   ```

2. Отворете MetaEditor и компилирайте файла (F7)

3. Рестартирайте MetaTrader 5 или натиснете Refresh в Navigator

## Използване

1. Отворете чарт на желания символ
2. Задайте timeframe на H1 (1 час)
3. Добавете EA от Navigator (Experts → Simple_Trading_Strategy)
4. Конфигурирайте параметрите според вашите предпочитания
5. Активирайте "Allow Algo Trading" в MT5
6. Натиснете OK

## Тестване

### Strategy Tester
1. Отворете Strategy Tester (View → Strategy Tester или Ctrl+R)
2. Изберете "Simple_Trading_Strategy" от списъка с експерти
3. Изберете символ и период за тестване
4. Задайте параметрите
5. Натиснете "Start"

### Препоръки за тестване
- Период: Минимум 6 месеца
- Timeframe: H1
- Символи: Основни валутни двойки (EUR/USD, GBP/USD и др.) или крипто
- Spread: Реалистичен за вашия брокер

## Логове и мониторинг

EA логва следните събития в таба "Experts":
- Инициализация/деинициализация
- Детектирани BUY/SELL сигнали
- Отворени позиции (с параметри)
- Грешки при отваряне на позиции

## Важни бележки

### Производителност
- EA работи само при отваряне на нова свещ (H1)
- Оптимизиран за бърза работа
- Не натоварва процесора излишно

### Рискове
- Винаги тествайте на демо акаунт първо
- Започнете с минимален риск процент (0.5-1%)
- Наблюдавайте поведението в различни пазарни условия
- Не използвайте на много корелирани символи едновременно

### Ограничения
- Работи само на H1 timeframe
- Не имплементира trailing stop
- Не имплементира частични изходи (TP1/TP2)
- Не филтрира по trading sessions

## Оптимизация

Препоръчителни параметри за оптимизация:
- **RiskPercent**: 0.5 - 3.0 (стъпка 0.5)
- **ATR_SL_Multiplier**: 1.5 - 3.0 (стъпка 0.5)
- **ATR_TP_Multiplier**: 2.0 - 4.0 (стъпка 0.5)
- **SMMA_Period**: 150 - 250 (стъпка 25)
- **MRC_Length**: 150 - 250 (стъпка 25)

## Поддръжка

За проблеми или въпроси:
1. Проверете логовете в таба "Experts"
2. Уверете се, че са изпълнени минималните изисквания за данни (>200 свещи)
3. Проверете дали брокерът позволява алгоритмична търговия
4. Проверете настройките за filling mode

## Лиценз

Този код е предоставен за образователни цели. Използвайте на собствен риск.

## Автор

Базиран на стратегията описана в README.md
Имплементация: Mean Reversion Strategy EA v1.00
