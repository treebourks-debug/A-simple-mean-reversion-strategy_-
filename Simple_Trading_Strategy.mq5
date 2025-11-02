//+------------------------------------------------------------------+
//|                                      Simple_Trading_Strategy.mq5 |
//|                        Mean Reversion Strategy with Trend Filter |
//|                                   https://www.github.com          |
//+------------------------------------------------------------------+
#property copyright "Mean Reversion Strategy"
#property link      "https://www.github.com"
#property version   "1.00"
#property description "Пълнофункционален Expert Advisor за MetaTrader 5"
#property description "Имплементира Mean Reversion стратегия с тренд филтър"
#property description ""
#property description "Индикатори:"
#property description "- SMMA 200: Тренд филтър (над=BUY, под=SELL)"
#property description "- QQE Signals: Тригери за влизане"
#property description "- Mean Reversion Channel: Зони за действие"
#property description "- Heikin-Ashi Volume: Потвърждение на обема"
#property description ""
#property description "Управление на риска:"
#property description "- ATR-базиран Stop Loss и Take Profit"
#property description "- Процент от баланса за размер на лота"
#property description "- Максимум 3 едновременни позиции"
#property strict

#include <Trade\Trade.mqh>

//--- Input параметри
input group "=== Основни параметри ==="
input int      MagicNumber = 123456;           // Magic Number за идентификация
input double   RiskPercent = 2.0;              // Риск процент от баланса
input int      MaxPositions = 3;               // Максимален брой позиции

input group "=== ATR параметри ==="
input int      ATR_Period = 14;                // ATR период
input double   ATR_SL_Multiplier = 2.0;        // ATR множител за Stop Loss
input double   ATR_TP_Multiplier = 3.0;        // ATR множител за Take Profit

input group "=== SMMA 200 параметри ==="
input int      SMMA_Period = 200;              // SMMA период

input group "=== QQE параметри ==="
input int      RSI_Period = 14;                // RSI период
input int      RSI_Smoothing = 5;              // RSI изглаждане
input double   QQE_Factor = 4.238;             // QQE фактор
input int      QQE_Threshold = 10;             // QQE праг

input group "=== Mean Reversion Channel параметри ==="
input int      MRC_Length = 200;               // MRC дължина
input double   MRC_InnerMult = 1.0;            // Вътрешен канал множител
input double   MRC_OuterMult = 2.415;          // Външен канал множител

input group "=== Heikin-Ashi Volume параметри ==="
input double   HA_Divider = 4.0;               // Volume делител
input int      HA_MA_Length = 20;              // Volume MA период

//--- Константи
#define BUFFER_SIZE 300
#define TRADE_RETCODE_INVALID_FILL 10030

//--- Глобални променливи
CTrade trade;
int atrHandle;
double smmaBuffer[];
double qqeLongBuffer[];
double qqeShortBuffer[];
double mrcMeanBuffer[];
double mrcUpperInnerBuffer[];
double mrcLowerInnerBuffer[];
double mrcUpperOuterBuffer[];
double mrcLowerOuterBuffer[];
double haVolumeBuffer[];
double haVolumeMaBuffer[];
datetime lastBarTime = 0;
bool buffersInitialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Инициализация на trade обект
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    
    //--- Определяне на режим на изпълнение
    ENUM_SYMBOL_TRADE_EXECUTION exec_mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
    if(exec_mode == SYMBOL_TRADE_EXECUTION_MARKET)
    {
        trade.SetTypeFilling(ORDER_FILLING_FOK);
    }
    else
    {
        trade.SetTypeFilling(ORDER_FILLING_RETURN);
    }
    
    //--- Създаване на ATR индикатор
    atrHandle = iATR(_Symbol, PERIOD_H1, ATR_Period);
    if(atrHandle == INVALID_HANDLE)
    {
        Print("Грешка при създаване на ATR индикатор");
        return INIT_FAILED;
    }
    
    //--- Инициализация на буфери
    ArraySetAsSeries(smmaBuffer, true);
    ArraySetAsSeries(qqeLongBuffer, true);
    ArraySetAsSeries(qqeShortBuffer, true);
    ArraySetAsSeries(mrcMeanBuffer, true);
    ArraySetAsSeries(mrcUpperInnerBuffer, true);
    ArraySetAsSeries(mrcLowerInnerBuffer, true);
    ArraySetAsSeries(mrcUpperOuterBuffer, true);
    ArraySetAsSeries(mrcLowerOuterBuffer, true);
    ArraySetAsSeries(haVolumeBuffer, true);
    ArraySetAsSeries(haVolumeMaBuffer, true);
    
    //--- Предварително заделяне на памет за буферите
    int maxPeriod = MathMax(MathMax(SMMA_Period, MRC_Length), BUFFER_SIZE);
    ArrayResize(smmaBuffer, maxPeriod + 10);
    ArrayResize(qqeLongBuffer, BUFFER_SIZE);
    ArrayResize(qqeShortBuffer, BUFFER_SIZE);
    ArrayResize(mrcMeanBuffer, maxPeriod + 10);
    ArrayResize(mrcUpperInnerBuffer, maxPeriod + 10);
    ArrayResize(mrcLowerInnerBuffer, maxPeriod + 10);
    ArrayResize(mrcUpperOuterBuffer, maxPeriod + 10);
    ArrayResize(mrcLowerOuterBuffer, maxPeriod + 10);
    ArrayResize(haVolumeBuffer, HA_MA_Length + 10);
    ArrayResize(haVolumeMaBuffer, HA_MA_Length + 10);
    
    buffersInitialized = true;
    
    Print("Expert Advisor инициализиран успешно за символ: ", _Symbol);
    Print("Параметри: SMMA=", SMMA_Period, " MRC=", MRC_Length, " ATR=", ATR_Period);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Освобождаване на индикатор handles
    if(atrHandle != INVALID_HANDLE)
        IndicatorRelease(atrHandle);
    
    Print("Expert Advisor деинициализиран");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Проверка за нова свещ
    datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
    if(currentBarTime == lastBarTime)
        return;
    lastBarTime = currentBarTime;
    
    //--- Изчисление на индикаторите
    if(!CalculateSMMA())
        return;
    
    if(!CalculateQQE())
        return;
    
    if(!CalculateMRC())
        return;
    
    if(!CalculateHeikinAshiVolume())
        return;
    
    //--- Проверка на текущия брой позиции
    int positionsCount = CountOpenPositions();
    if(positionsCount >= MaxPositions)
        return;
    
    //--- Проверка за BUY сигнал
    if(CheckBuyConditions())
    {
        OpenBuyPosition();
    }
    //--- Проверка за SELL сигнал
    else if(CheckSellConditions())
    {
        OpenSellPosition();
    }
}

//+------------------------------------------------------------------+
//| Изчисление на SMMA 200                                           |
//+------------------------------------------------------------------+
bool CalculateSMMA()
{
    int barsCalculated = Bars(_Symbol, PERIOD_H1);
    
    if(barsCalculated < SMMA_Period + 10)
        return false;
    
    int copyBars = SMMA_Period + 10;
    
    //--- Изчисление на SMMA от най-стария до най-новия бар
    // Започваме от най-стария бар (index = copyBars-1)
    for(int i = copyBars - 1; i >= 0; i--)
    {
        double close = iClose(_Symbol, PERIOD_H1, i);
        
        if(i == copyBars - 1)
        {
            // Първа стойност - SMA
            double sum = 0.0;
            for(int j = 0; j < SMMA_Period; j++)
            {
                sum += iClose(_Symbol, PERIOD_H1, i + j);
            }
            smmaBuffer[i] = sum / SMMA_Period;
        }
        else
        {
            // SMMA формула: (SMMA[1] * (len - 1) + close) / len
            smmaBuffer[i] = (smmaBuffer[i+1] * (SMMA_Period - 1) + close) / SMMA_Period;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Изчисление на QQE Signals                                        |
//+------------------------------------------------------------------+
bool CalculateQQE()
{
    int barsCalculated = Bars(_Symbol, PERIOD_H1);
    if(barsCalculated < RSI_Period + RSI_Smoothing + 100)
        return false;
    
    double rsiBuffer[];
    double rsiMaBuffer[];
    double atrRsiBuffer[];
    double maAtrRsiBuffer[];
    double darBuffer[];
    double longbandBuffer[];
    double shortbandBuffer[];
    int trendBuffer[];
    double fastAtrRsiTLBuffer[];
    int qqeXlongBuffer[];
    int qqeXshortBuffer[];
    
    ArrayResize(rsiBuffer, BUFFER_SIZE);
    ArrayResize(rsiMaBuffer, BUFFER_SIZE);
    ArrayResize(atrRsiBuffer, BUFFER_SIZE);
    ArrayResize(maAtrRsiBuffer, BUFFER_SIZE);
    ArrayResize(darBuffer, BUFFER_SIZE);
    ArrayResize(longbandBuffer, BUFFER_SIZE);
    ArrayResize(shortbandBuffer, BUFFER_SIZE);
    ArrayResize(trendBuffer, BUFFER_SIZE);
    ArrayResize(fastAtrRsiTLBuffer, BUFFER_SIZE);
    ArrayResize(qqeXlongBuffer, BUFFER_SIZE);
    ArrayResize(qqeXshortBuffer, BUFFER_SIZE);
    
    //--- Изчисление на RSI
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        double gains = 0, losses = 0;
        for(int j = 0; j < RSI_Period; j++)
        {
            double change = iClose(_Symbol, PERIOD_H1, i+j) - iClose(_Symbol, PERIOD_H1, i+j+1);
            if(change > 0)
                gains += change;
            else
                losses += MathAbs(change);
        }
        double avgGain = gains / RSI_Period;
        double avgLoss = losses / RSI_Period;
        double rs = avgLoss == 0 ? 100 : avgGain / avgLoss;
        rsiBuffer[i] = 100 - (100 / (1 + rs));
    }
    
    //--- RSI EMA изглаждане
    double multiplier = 2.0 / (RSI_Smoothing + 1);
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        if(i == BUFFER_SIZE - 1)
            rsiMaBuffer[i] = rsiBuffer[i];
        else
            rsiMaBuffer[i] = (rsiBuffer[i] - rsiMaBuffer[i+1]) * multiplier + rsiMaBuffer[i+1];
    }
    
    //--- ATR на RSI
    int wildersPeriod = RSI_Period * 2 - 1;
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        if(i < BUFFER_SIZE - 1)
            atrRsiBuffer[i] = MathAbs(rsiMaBuffer[i+1] - rsiMaBuffer[i]);
        else
            atrRsiBuffer[i] = 0;
    }
    
    //--- MaAtrRsi
    multiplier = 2.0 / (wildersPeriod + 1);
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        if(i == BUFFER_SIZE - 1)
            maAtrRsiBuffer[i] = atrRsiBuffer[i];
        else
            maAtrRsiBuffer[i] = (atrRsiBuffer[i] - maAtrRsiBuffer[i+1]) * multiplier + maAtrRsiBuffer[i+1];
    }
    
    //--- dar (второ EMA изглаждане)
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        if(i == BUFFER_SIZE - 1)
            darBuffer[i] = maAtrRsiBuffer[i] * QQE_Factor;
        else
            darBuffer[i] = (maAtrRsiBuffer[i] - darBuffer[i+1]) * multiplier + darBuffer[i+1];
        darBuffer[i] *= QQE_Factor;
    }
    
    //--- Изчисление на ленти и тренд
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        double deltaFastAtrRsi = darBuffer[i];
        double rsIndex = rsiMaBuffer[i];
        double newshortband = rsIndex + deltaFastAtrRsi;
        double newlongband = rsIndex - deltaFastAtrRsi;
        
        if(i < BUFFER_SIZE - 1)
        {
            longbandBuffer[i] = (rsiMaBuffer[i+1] > longbandBuffer[i+1] && rsIndex > longbandBuffer[i+1]) ? 
                                 MathMax(longbandBuffer[i+1], newlongband) : newlongband;
            shortbandBuffer[i] = (rsiMaBuffer[i+1] < shortbandBuffer[i+1] && rsIndex < shortbandBuffer[i+1]) ?
                                  MathMin(shortbandBuffer[i+1], newshortband) : newshortband;
            
            bool cross_short = rsIndex > shortbandBuffer[i+1] && rsiMaBuffer[i+1] <= shortbandBuffer[i+1];
            bool cross_long = longbandBuffer[i+1] > rsIndex && longbandBuffer[i+1] <= rsiMaBuffer[i+1];
            
            trendBuffer[i] = cross_short ? 1 : (cross_long ? -1 : trendBuffer[i+1]);
        }
        else
        {
            longbandBuffer[i] = newlongband;
            shortbandBuffer[i] = newshortband;
            trendBuffer[i] = 1;
        }
        
        fastAtrRsiTLBuffer[i] = trendBuffer[i] == 1 ? longbandBuffer[i] : shortbandBuffer[i];
    }
    
    //--- QQE сигнали
    for(int i = BUFFER_SIZE - 1; i >= 0; i--)
    {
        if(i < BUFFER_SIZE - 1)
        {
            qqeXlongBuffer[i] = fastAtrRsiTLBuffer[i] < rsiMaBuffer[i] ? qqeXlongBuffer[i+1] + 1 : 0;
            qqeXshortBuffer[i] = fastAtrRsiTLBuffer[i] > rsiMaBuffer[i] ? qqeXshortBuffer[i+1] + 1 : 0;
        }
        else
        {
            qqeXlongBuffer[i] = 0;
            qqeXshortBuffer[i] = 0;
        }
        
        qqeLongBuffer[i] = (qqeXlongBuffer[i] == 1) ? 1 : 0;
        qqeShortBuffer[i] = (qqeXshortBuffer[i] == 1) ? 1 : 0;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Изчисление на Mean Reversion Channel                             |
//+------------------------------------------------------------------+
bool CalculateMRC()
{
    int barsCalculated = Bars(_Symbol, PERIOD_H1);
    if(barsCalculated < MRC_Length + 10)
        return false;
    
    double pi = 3.14159265358979323846;
    
    //--- SuperSmoother за средна линия
    for(int i = 0; i < MRC_Length + 10; i++)
    {
        double src = (iHigh(_Symbol, PERIOD_H1, i) + iLow(_Symbol, PERIOD_H1, i) + iClose(_Symbol, PERIOD_H1, i)) / 3.0;
        
        if(i >= 2)
        {
            double a1 = MathExp(-1.414 * pi / MRC_Length);
            double b1 = 2 * a1 * MathCos(1.414 * pi / MRC_Length);
            double c2 = b1;
            double c3 = -a1 * a1;
            double c1 = 1 - c2 - c3;
            
            mrcMeanBuffer[i] = c1 * src + c2 * mrcMeanBuffer[i-1] + c3 * mrcMeanBuffer[i-2];
        }
        else
        {
            mrcMeanBuffer[i] = src;
        }
    }
    
    //--- Изчисление на mean range (SuperSmoother на True Range)
    double meanRange = 0;
    for(int i = 0; i < MRC_Length + 10; i++)
    {
        double tr = iHigh(_Symbol, PERIOD_H1, i) - iLow(_Symbol, PERIOD_H1, i);
        if(i > 0)
        {
            double prevClose = iClose(_Symbol, PERIOD_H1, i+1);
            tr = MathMax(tr, MathAbs(iHigh(_Symbol, PERIOD_H1, i) - prevClose));
            tr = MathMax(tr, MathAbs(iLow(_Symbol, PERIOD_H1, i) - prevClose));
        }
        
        if(i == 0)
            meanRange = tr;
        else if(i >= 2)
        {
            double a1 = MathExp(-1.414 * pi / MRC_Length);
            double b1 = 2 * a1 * MathCos(1.414 * pi / MRC_Length);
            double c2 = b1;
            double c3 = -a1 * a1;
            double c1 = 1 - c2 - c3;
            
            meanRange = c1 * tr + c2 * meanRange;
        }
    }
    
    //--- Изчисление на каналите
    for(int i = 0; i < MRC_Length + 10; i++)
    {
        mrcUpperInnerBuffer[i] = mrcMeanBuffer[i] + meanRange * pi * MRC_InnerMult;
        mrcLowerInnerBuffer[i] = mrcMeanBuffer[i] - meanRange * pi * MRC_InnerMult;
        mrcUpperOuterBuffer[i] = mrcMeanBuffer[i] + meanRange * pi * MRC_OuterMult;
        mrcLowerOuterBuffer[i] = mrcMeanBuffer[i] - meanRange * pi * MRC_OuterMult;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Изчисление на Heikin-Ashi Volume                                 |
//+------------------------------------------------------------------+
bool CalculateHeikinAshiVolume()
{
    int barsCalculated = Bars(_Symbol, PERIOD_H1);
    if(barsCalculated < HA_MA_Length + 10)
        return false;
    
    int copyBars = HA_MA_Length + 10;
    ArrayResize(haVolumeBuffer, copyBars);
    ArrayResize(haVolumeMaBuffer, copyBars);
    
    //--- Изчисление на Heikin-Ashi свещи и volume
    // Трябва да изчислим от най-стария към най-новия за HA рекурсията
    double haOpenArray[];
    double haCloseArray[];
    ArrayResize(haOpenArray, copyBars);
    ArrayResize(haCloseArray, copyBars);
    
    for(int i = copyBars - 1; i >= 0; i--)
    {
        double open = iOpen(_Symbol, PERIOD_H1, i);
        double high = iHigh(_Symbol, PERIOD_H1, i);
        double low = iLow(_Symbol, PERIOD_H1, i);
        double close = iClose(_Symbol, PERIOD_H1, i);
        
        haCloseArray[i] = (open + high + low + close) / 4.0;
        
        if(i == copyBars - 1)
            haOpenArray[i] = (open + close) / 2.0;
        else
            haOpenArray[i] = (haOpenArray[i+1] + haCloseArray[i+1]) / 2.0;
        
        //--- Volume scaled - просто копираме volume, не зависи от HA посоката
        long volume = iVolume(_Symbol, PERIOD_H1, i);
        haVolumeBuffer[i] = volume / HA_Divider;
    }
    
    //--- Изчисление на SMA на volume
    for(int i = 0; i < copyBars; i++)
    {
        if(i + HA_MA_Length > copyBars)
            continue;
            
        double sum = 0;
        for(int j = 0; j < HA_MA_Length; j++)
        {
            sum += haVolumeBuffer[i + j];
        }
        haVolumeMaBuffer[i] = sum / HA_MA_Length;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка за BUY условия                                          |
//+------------------------------------------------------------------+
bool CheckBuyConditions()
{
    double close = iClose(_Symbol, PERIOD_H1, 1);
    double low = iLow(_Symbol, PERIOD_H1, 1);
    
    //--- 1. Close > SMMA(200)
    if(close <= smmaBuffer[1])
        return false;
    
    //--- 2. Цената достигна долната зона на MRC
    bool atLowerZone = (low <= mrcLowerOuterBuffer[1] || low <= mrcLowerInnerBuffer[1]) && 
                       (close > mrcLowerInnerBuffer[1]);
    if(!atLowerZone)
        return false;
    
    //--- 3. QQE BUY сигнал
    if(qqeLongBuffer[1] != 1)
        return false;
    
    //--- 4. Heikin-Ashi Volume >= Volume MA
    if(haVolumeBuffer[1] < haVolumeMaBuffer[1])
        return false;
    
    Print("BUY сигнал детектиран!");
    return true;
}

//+------------------------------------------------------------------+
//| Проверка за SELL условия                                         |
//+------------------------------------------------------------------+
bool CheckSellConditions()
{
    double close = iClose(_Symbol, PERIOD_H1, 1);
    double high = iHigh(_Symbol, PERIOD_H1, 1);
    
    //--- 1. Close < SMMA(200)
    if(close >= smmaBuffer[1])
        return false;
    
    //--- 2. Цената достигна горната зона на MRC
    bool atUpperZone = (high >= mrcUpperOuterBuffer[1] || high >= mrcUpperInnerBuffer[1]) && 
                       (close < mrcUpperInnerBuffer[1]);
    if(!atUpperZone)
        return false;
    
    //--- 3. QQE SELL сигнал
    if(qqeShortBuffer[1] != 1)
        return false;
    
    //--- 4. Heikin-Ashi Volume >= Volume MA
    if(haVolumeBuffer[1] < haVolumeMaBuffer[1])
        return false;
    
    Print("SELL сигнал детектиран!");
    return true;
}

//+------------------------------------------------------------------+
//| Отваряне на BUY позиция                                          |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
    double atrValue = GetATR();
    if(atrValue <= 0)
        return;
    
    double lotSize = CalculateLotSize(atrValue);
    if(lotSize <= 0)
        return;
    
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    //--- Изчисление на SL и TP
    double slDistance = atrValue * ATR_SL_Multiplier;
    double tpDistance = atrValue * ATR_TP_Multiplier;
    
    double sl = NormalizeDouble(ask - slDistance, digits);
    double tp = NormalizeDouble(ask + tpDistance, digits);
    
    //--- Отваряне на позиция
    if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "BUY Signal"))
    {
        Print("BUY позиция отворена успешно: Lot=", lotSize, " Entry=", ask, " SL=", sl, " TP=", tp);
    }
    else
    {
        int error = trade.ResultRetcode();
        Print("Грешка при отваряне на BUY позиция: ", trade.ResultRetcodeDescription(), " (", error, ")");
        
        //--- Опит с различен filling mode
        if(error == TRADE_RETCODE_INVALID_FILL)
        {
            trade.SetTypeFilling(ORDER_FILLING_IOC);
            if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "BUY Signal"))
            {
                Print("BUY позиция отворена с IOC filling mode");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Отваряне на SELL позиция                                         |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
    double atrValue = GetATR();
    if(atrValue <= 0)
        return;
    
    double lotSize = CalculateLotSize(atrValue);
    if(lotSize <= 0)
        return;
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    //--- Изчисление на SL и TP
    double slDistance = atrValue * ATR_SL_Multiplier;
    double tpDistance = atrValue * ATR_TP_Multiplier;
    
    double sl = NormalizeDouble(bid + slDistance, digits);
    double tp = NormalizeDouble(bid - tpDistance, digits);
    
    //--- Отваряне на позиция
    if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "SELL Signal"))
    {
        Print("SELL позиция отворена успешно: Lot=", lotSize, " Entry=", bid, " SL=", sl, " TP=", tp);
    }
    else
    {
        int error = trade.ResultRetcode();
        Print("Грешка при отваряне на SELL позиция: ", trade.ResultRetcodeDescription(), " (", error, ")");
        
        //--- Опит с различен filling mode
        if(error == TRADE_RETCODE_INVALID_FILL)
        {
            trade.SetTypeFilling(ORDER_FILLING_IOC);
            if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "SELL Signal"))
            {
                Print("SELL позиция отворена с IOC filling mode");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Изчисление на размер на лота                                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double atrValue)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * RiskPercent / 100.0;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double slDistance = atrValue * ATR_SL_Multiplier;
    double slPoints = slDistance / point;
    
    //--- Изчисление на lot size
    double pointValue = tickValue * (point / tickSize);
    double lotSize = riskAmount / (slPoints * pointValue);
    
    //--- Нормализиране спрямо минимум/максимум
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, lotSize);
    lotSize = MathMin(maxLot, lotSize);
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Броене на отворени позиции                                       |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Получаване на ATR стойност                                       |
//+------------------------------------------------------------------+
double GetATR()
{
    double atrArray[];
    ArraySetAsSeries(atrArray, true);
    
    if(CopyBuffer(atrHandle, 0, 0, 2, atrArray) != 2)
    {
        Print("Грешка при копиране на ATR данни");
        return 0;
    }
    
    return atrArray[1];
}
//+------------------------------------------------------------------+
