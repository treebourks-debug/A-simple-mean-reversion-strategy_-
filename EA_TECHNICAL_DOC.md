# Simple Trading Strategy EA - Техническа документация

## Структура на кода

### Основни компоненти

```
Simple_Trading_Strategy.mq5
├── Input параметри (lines 13-40)
├── Глобални променливи (lines 42-55)
├── OnInit() - Инициализация (lines 60-99)
├── OnDeinit() - Деинициализация (lines 104-110)
├── OnTick() - Основна логика (lines 115-145)
├── Indicator Functions
│   ├── CalculateSMMA() (lines 150-180)
│   ├── CalculateQQE() (lines 185-328)
│   ├── CalculateMRC() (lines 333-414)
│   └── CalculateHeikinAshiVolume() (lines 419-467)
├── Trading Logic Functions
│   ├── CheckBuyConditions() (lines 472-493)
│   └── CheckSellConditions() (lines 498-519)
├── Position Management Functions
│   ├── OpenBuyPosition() (lines 524-559)
│   ├── OpenSellPosition() (lines 564-599)
│   ├── CalculateLotSize() (lines 604-628)
│   ├── CountOpenPositions() (lines 633-648)
│   └── GetATR() (lines 653-665)
```

## Функции и алгоритми

### 1. CalculateSMMA()

**Цел**: Изчисляване на Smoothed Moving Average (SMMA)

**Алгоритъм**:
```
Първа стойност: SMA = sum(close, period) / period
Следващи стойности: SMMA = (SMMA[prev] * (period - 1) + close) / period
```

**Особености**:
- Изчислява се от най-стария към най-новия бар
- Използва рекурсивна формула за ефективност
- Буферът е настроен като series (index 0 = current)

**Връщана стойност**: `true` при успех, `false` при недостатъчно данни

### 2. CalculateQQE()

**Цел**: Изчисляване на QQE (Qualitative Quantitative Estimation) сигнали

**Алгоритъм**:
1. Изчисляване на RSI
2. EMA изглаждане на RSI (RSI Smoothing)
3. Изчисляване на ATR на RSI движението
4. Двойно EMA изглаждане (Wilders Period)
5. Изчисляване на динамични ленти (longband/shortband)
6. Определяне на тренд
7. Генериране на сигнали (QQExlong == 1 / QQExshort == 1)

**Параметри**:
- RSI Period: 14
- RSI Smoothing: 5
- Wilders Period: RSI_Period * 2 - 1 = 27
- QQE Factor: 4.238

**Връщана стойност**: `true` при успех, `false` при недостатъчно данни

**Буфери**:
- `qqeLongBuffer[]`: 1 = BUY сигнал, 0 = няма сигнал
- `qqeShortBuffer[]`: 1 = SELL сигнал, 0 = няма сигнал

### 3. CalculateMRC()

**Цел**: Изчисляване на Mean Reversion Channel

**Алгоритъм**:
1. SuperSmoother за средна линия (meanline)
   - Използва експоненциално изглаждане с косинус/синус трансформация
   - Formula: `c1 * src + c2 * prev[1] + c3 * prev[2]`
2. SuperSmoother за mean range (True Range изглаждане)
3. Изчисляване на каналите:
   - Upper Inner: `meanline + meanrange * π * InnerMult`
   - Lower Inner: `meanline - meanrange * π * InnerMult`
   - Upper Outer: `meanline + meanrange * π * OuterMult`
   - Lower Outer: `meanline - meanrange * π * OuterMult`

**Особености**:
- Използва SuperSmoother filter за по-гладки линии
- Множителите се умножават по π за правилно мащабиране

**Връщана стойност**: `true` при успех, `false` при недостатъчно данни

**Буфери**:
- `mrcMeanBuffer[]`: Средна линия
- `mrcUpperInnerBuffer[]`: Горна вътрешна лента
- `mrcLowerInnerBuffer[]`: Долна вътрешна лента
- `mrcUpperOuterBuffer[]`: Горна външна лента
- `mrcLowerOuterBuffer[]`: Долна външна лента

### 4. CalculateHeikinAshiVolume()

**Цел**: Изчисляване на Heikin-Ashi Volume и неговата MA

**Алгоритъм**:
1. Изчисляване на Heikin-Ashi свещи:
   - `HA Close = (Open + High + Low + Close) / 4`
   - `HA Open = (HA Open[prev] + HA Close[prev]) / 2`
2. Volume scaling: `Volume / Divider`
3. SMA на scaled volume

**Особености**:
- HA свещите се изчисляват рекурсивно
- Volume се мащабира за по-добра видимост
- MA се използва за филтриране на шум

**Връщана стойност**: `true` при успех, `false` при недостатъчно данни

**Буфери**:
- `haVolumeBuffer[]`: Scaled volume
- `haVolumeMaBuffer[]`: SMA на volume

### 5. CheckBuyConditions()

**Цел**: Проверка на всички условия за BUY

**Условия**:
1. `Close[1] > SMMA[1]` - Над тренда
2. `Low[1] <= MRC_Lower_Outer[1] OR Low[1] <= MRC_Lower_Inner[1]` - Достигнала долна зона
3. `Close[1] > MRC_Lower_Inner[1]` - Затворила над долната лента (реинтеграция)
4. `qqeLongBuffer[1] == 1` - QQE BUY сигнал
5. `haVolumeBuffer[1] >= haVolumeMaBuffer[1]` - Volume потвърждение

**Връщана стойност**: `true` ако всички условия са изпълнени

### 6. CheckSellConditions()

**Цел**: Проверка на всички условия за SELL

**Условия**:
1. `Close[1] < SMMA[1]` - Под тренда
2. `High[1] >= MRC_Upper_Outer[1] OR High[1] >= MRC_Upper_Inner[1]` - Достигнала горна зона
3. `Close[1] < MRC_Upper_Inner[1]` - Затворила под горната лента (реинтеграция)
4. `qqeShortBuffer[1] == 1` - QQE SELL сигнал
5. `haVolumeBuffer[1] >= haVolumeMaBuffer[1]` - Volume потвърждение

**Връщана стойност**: `true` ако всички условия са изпълнени

### 7. CalculateLotSize()

**Цел**: Изчисляване на размер на лота базиран на риск

**Формула**:
```
riskAmount = AccountBalance * RiskPercent / 100
slDistance = ATR * ATR_SL_Multiplier
slPoints = slDistance / Point
pointValue = tickValue * (point / tickSize)
lotSize = riskAmount / (slPoints * pointValue)
```

**Нормализация**:
- Минимум: `SYMBOL_VOLUME_MIN`
- Максимум: `SYMBOL_VOLUME_MAX`
- Стъпка: `SYMBOL_VOLUME_STEP`

**Връщана стойност**: Нормализиран lot size

### 8. OpenBuyPosition() / OpenSellPosition()

**Цел**: Отваряне на BUY/SELL позиция

**Процес**:
1. Вземане на текуща ATR стойност
2. Изчисляване на lot size
3. Изчисляване на SL и TP:
   - SL Distance: `ATR * ATR_SL_Multiplier`
   - TP Distance: `ATR * ATR_TP_Multiplier`
4. Отваряне на позиция с CTrade класа
5. Error handling:
   - При грешка 10030 (Invalid Filling): опит с IOC filling mode

**Логване**:
- Успех: Lot, Entry, SL, TP
- Грешка: Error code и описание

## Управление на паметта

### Динамични масиви
Всички индикаторни буфери са динамични масиви:
- Размерът се променя динамично според нуждите
- `ArraySetAsSeries(buffer, true)` - Настройка като time series
- Index 0 = current bar, Index 1 = previous bar, etc.

### Освобождаване на ресурси
- ATR индикатор handle се освобождава в `OnDeinit()`
- Масивите се освобождават автоматично

## Оптимизации

### 1. Проверка за нова свещ
```cpp
if(currentBarTime == lastBarTime)
    return;
```
- EA работи само при отваряне на нова свещ
- Предотвратява излишни изчисления

### 2. Early return
Всички проверки използват early return pattern:
```cpp
if(!condition)
    return false;
```
- Спира изпълнението при първо неизпълнено условие
- Намалява излишни изчисления

### 3. Буферни размери
- Буферите са с фиксиран размер (период + 10)
- Не се пренаписват при всяка итерация

## Error Handling

### 1. Индикатори
- Проверка за достатъчно данни (`Bars < period`)
- Връщане на `false` при недостатъчно данни

### 2. Отваряне на позиции
- Проверка на trade.ResultRetcode()
- Retry логика за различни filling modes
- Детайлно логване на грешки

### 3. Валидация на параметри
- Lot size нормализация
- SL/TP нормализация с Digits

## Известни ограничения

1. **Timeframe**: Работи само на H1 (hardcoded в OnTick)
2. **Trailing Stop**: Не е имплементиран
3. **Partial Exits**: Не са имплементирани (TP1/TP2)
4. **Session Filtering**: Няма филтриране по trading sessions
5. **Multi-symbol**: Един EA на символ (magic number идентификация)

## Препоръки за подобрения

1. **Timeframe параметър**: Добавяне на input параметър за timeframe
2. **Trailing Stop**: Имплементация на ATR-based trailing stop
3. **Partial Exits**: Затваряне на 50% при TP1 (mean line)
4. **Session Filter**: Филтриране по Asian/European/US sessions
5. **Multi-timeframe**: Добавяне на higher timeframe trend confirmation
6. **Breakeven**: Преместване на SL на BE след определен profit

## Производителност

### Средно време за изпълнение (estimate):
- CalculateSMMA: ~1ms
- CalculateQQE: ~5ms (комплексни изчисления)
- CalculateMRC: ~3ms
- CalculateHeikinAshiVolume: ~2ms
- Total per tick: ~15ms (пренебрежимо)

### Memory usage:
- ~50KB за всички буфери
- Minimal heap allocations

## Тестване

### Unit Testing (препоръчително):
1. Тестване на SMMA с known values
2. Тестване на QQE сигнали
3. Тестване на lot size calculation
4. Тестване на условия за влизане

### Integration Testing:
1. Strategy Tester с historical data
2. Demo account forward testing
3. Different market conditions

## Версии

### v1.00 (Current)
- Първоначална имплементация
- Всички основни функции
- ATR-based risk management
- Multiple indicator integration

### Planned updates:
- v1.01: Trailing stop
- v1.02: Partial exits
- v1.03: Multi-timeframe confirmation
