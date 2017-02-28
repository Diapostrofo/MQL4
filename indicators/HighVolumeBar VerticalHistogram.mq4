
#property copyright "Scriptong"
#property link "scriptong@mail.ru"

#property indicator_chart_window                   

#define MAX_DAY_VOLATILITY             2000

// ����������� ��������� ����������
extern color     i_supportColor        = C'79, 123, 153';
extern color     i_resistanceColor     = C'134, 53, 53';
extern color     i_indefiniteColor     = DarkGray;

extern int       i_indBarsCount        = 5000;


// ������ ���������� ���������� ����������
bool g_activate,                                   // ������� �������� �������������..
                                                   // ..����������
     g_init;                                       // ���������� ��� �������������..
                                                   // ..����������� ���������� ������..
                                                   // ..������� � ������ ����������..
                                                   // ..��������� �������������
int g_volumesArray[MAX_DAY_VOLATILITY];            // ������ ��� ������ ������� �������

datetime g_lastCheckedBar;                         // ����� �������� ����������..
                                                   // ..������������ ���� �� �1
     
#define PREFIX "HVBVH_"                            // ������� ����������� ��������,..
                                                   // ..������������ ����������� 

#define SIGN_TREND_LINE               "TR_LINE_"   // ������� ������� "��������� �����"


#include <stderror.mqh>
                                                   
//+-------------------------------------------------------------------------------------+
//| Custom indicator initialization function                                            |
//+-------------------------------------------------------------------------------------+
int init()
{
   g_activate = false;                             // ��������� �� ���������������
   g_init = true;
   g_lastCheckedBar = 0;
   
   if (!TuningParameters())                        // ������� ��������� ��������..
      return (-1);                                 // ..����������� ���������� - �������
                                                   // ..��������� �������������
           
   IsAllBarsAvailable(PERIOD_M1);                  // ������ �������� ������ �� �� �1

   g_activate = true;                              // ��������� ������� ���������������
   return(0);
}
//+-------------------------------------------------------------------------------------+
//| �������� ������������ ����������� ����������                                        |
//+-------------------------------------------------------------------------------------+
bool TuningParameters()
{
   string name = WindowExpertName();

   if (Period() > PERIOD_H4)
   {
      Print(name, ": ��������� �� �������� �� ����������� ����, ��� H4.");
      return (false);
   }

   int period = Period();
   if (period == 0)
   {
      Alert(name, ": ��������� ������ ��������� - ������ 0 �����. ��������� ��������.");
      return (false);
   }
   
   if (Point == 0)
   {
      Alert(name, ": ��������� ������ ��������� - �������� ������ ����� ����. ",
                  "��������� ��������.");
      return (false);
   }
   
   return (true);
}
//+-------------------------------------------------------------------------------------+
//| �������� ����������� ����� ���������� ����������                                    |
//+-------------------------------------------------------------------------------------+
bool IsAllBarsAvailable(int tf)
{
   // ���������� ������� ����, � �������� ���������� �������� ��������
   if (g_lastCheckedBar == 0)
      int lastBar = iBars(NULL, tf) - 1;
   else
      lastBar = iBarShift(NULL, tf, g_lastCheckedBar);

   if (GetLastError() == ERR_HISTORY_WILL_UPDATED)
      return (false);
      
   // �������� ����������� �����
   for (int i = lastBar - 1; i > 0; i--)
   {
      iTime(NULL, tf, i);
      if (GetLastError() == ERR_HISTORY_WILL_UPDATED)
         return (false);
   }
   
   // ��� ���� ��������
   g_lastCheckedBar = iTime(NULL, tf, 1);
   return (true);
}
//+-------------------------------------------------------------------------------------+
//| Custom indicator deinitialization function                                          |
//+-------------------------------------------------------------------------------------+
int deinit()
{
   DeleteAllObjects();
   return(0);
}
//+-------------------------------------------------------------------------------------+
//| �������� ���� ��������, ��������� ����������                                        |
//+-------------------------------------------------------------------------------------+
void DeleteAllObjects()
{
   for (int i = ObjectsTotal() - 1; i >= 0; i--)     
      if (StringSubstr(ObjectName(i), 0, StringLen(PREFIX)) == PREFIX)
         ObjectDelete(ObjectName(i));
}
//+-------------------------------------------------------------------------------------+
//| ����������� ������� ����, � �������� ���������� ����������� ����������              |
//+-------------------------------------------------------------------------------------+
int GetRecalcIndex(int& total)
{
   static int lastBarsCnt;                         // ����������� ������� ���� �������,..
   if (g_init)                                     // ..�� ������� ����� ��������..
   {                                               // ..���������� ��������
      lastBarsCnt = 0;
      g_init = false;
   }
   total = Bars - 2;                               
                                                   
    
   if (i_indBarsCount > 0 && i_indBarsCount < total)// ���� �� ����� ������������ ���..
      total = i_indBarsCount;                      // ..�������, �� ������ � ����������..
                                                   // ..����
   if (lastBarsCnt < Bars - 1)                     // ���-�� ����������� ����� - 0. �����
   {                                               // ..������� ��� ����������� �������
      lastBarsCnt = Bars;
      DeleteAllObjects();                          
      return (total);                              // ���� ��� ������� - �� total
   }
   
   int newBarsCnt = Bars - lastBarsCnt;
   lastBarsCnt = Bars;
   return (newBarsCnt);                            // �������� � ������ ����
}
//+-------------------------------------------------------------------------------------+
//| ����������� ��������� �����                                                         |
//+-------------------------------------------------------------------------------------+
void ShowTrendLine(int index, datetime leftTime, double leftPrice, datetime rightTime,
                   color clr)
{
   string name = PREFIX + SIGN_TREND_LINE + leftTime + index;

   if (ObjectFind(name) < 0)
   {
      ObjectCreate(name, OBJ_TREND, 0, leftTime, leftPrice, rightTime, leftPrice);
      ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(name, OBJPROP_COLOR, clr);
      ObjectSet(name, OBJPROP_BACK, true);
      ObjectSet(name, OBJPROP_RAY, false);
      return;
   }
   
   ObjectMove(name, 0, leftTime, leftPrice);
   ObjectMove(name, 1, rightTime, leftPrice);
   ObjectSet(name, OBJPROP_COLOR, clr);
}
//+-------------------------------------------------------------------------------------+
//| ����������� ����������� ���������� ���  � ����������������� ������� ������� ���..   |
//| ..�������������                                                                     |
//+-------------------------------------------------------------------------------------+
int GetDayVolatility(int leftIndex, int rightIndex, int& volumesArray[], 
                     double& minDayPrice)
{
   int barsPerDay = leftIndex - rightIndex + 1;
   
   minDayPrice = iLow(NULL, PERIOD_M1, 
                      iLowest(NULL, PERIOD_M1, MODE_LOW, barsPerDay, rightIndex));
   double maxDayPrice = iHigh(NULL, PERIOD_M1, 
                              iHighest(NULL, PERIOD_M1, MODE_HIGH, 
                                       barsPerDay, rightIndex));
                                       
   int dayVolatility = MathRound((maxDayPrice - minDayPrice + Point) / Point);
   if (dayVolatility > MAX_DAY_VOLATILITY)
      ArrayResize(volumesArray, dayVolatility);
   
   ArrayInitialize(volumesArray, 0);   
   return (dayVolatility);
}
//+-------------------------------------------------------------------------------------+
//| ������ ������� ����� ����� � ������ �������                                         |
//+-------------------------------------------------------------------------------------+
void SaveVolumes(double minBarPrice, double maxBarPrice, double minDayPrice,
                 double volume, int& volumesArray[], int& maxVolume, 
                 double& maxVolumePrice)
{
   for (double price = minBarPrice; 
        IsFirstMoreOrEqualThanSecond(maxBarPrice, price); 
        price += Point)
   {
      int indexOfArray = MathRound((price - minDayPrice) / Point);
      volumesArray[indexOfArray] += volume;
      if (maxVolume < volumesArray[indexOfArray])
      {
         maxVolume = volumesArray[indexOfArray];
         maxVolumePrice = price;
      }
   }
}
//+-------------------------------------------------------------------------------------+
//| ������������ �������� ������� � ��������������� �� �������� �����                   |
//+-------------------------------------------------------------------------------------+
void FormVolumesArray(int leftIndex, int rightIndex, int& volumesArray[], 
                      int& dayVolatility, double& minDayPrice, int& maxVolume, 
                      double& maxVolumePrice)
{
   dayVolatility = GetDayVolatility(leftIndex, rightIndex, volumesArray, minDayPrice);
   maxVolume = 0;

   for (int i = leftIndex; i >= rightIndex; i--)
   {
      double minBarPrice = iLow(NULL, PERIOD_M1, i); 
      double maxBarPrice = iHigh(NULL, PERIOD_M1, i); 
      if (IsValuesEquals(minBarPrice, maxBarPrice))
         continue;

      int volume = iVolume(NULL, PERIOD_M1, i);
      SaveVolumes(minBarPrice, maxBarPrice, minDayPrice, volume, 
                  volumesArray, maxVolume, maxVolumePrice);
   }
}
//+-------------------------------------------------------------------------------------+
//| ���������� �������� ����� ��������� ��, �������������� ���� ����� ��������� ��������|
//+-------------------------------------------------------------------------------------+
int GetIndexesOfDayRange(datetime timeOfNextDay, int& endDayBar, bool isNewDay)
{
   endDayBar = 0;
   if (isNewDay)
      endDayBar = iBarShift(NULL, PERIOD_M1, timeOfNextDay) + 1;
   int beginDayBar = endDayBar;
   int total = iBars(NULL, PERIOD_M1);

   while (TimeDayOfYear(iTime(NULL, PERIOD_M1, beginDayBar)) == 
          TimeDayOfYear(iTime(NULL, PERIOD_M1, endDayBar))
          &&
          beginDayBar < total)
      beginDayBar++;
      
   return (beginDayBar - 1);
}
//+-------------------------------------------------------------------------------------+
//| ������ ��� ����� ������ �����, ��� ������?                                          |
//+-------------------------------------------------------------------------------------+
bool IsFirstMoreOrEqualThanSecond(double first, double second)
{
   return (first - second > - Point / 100);
}
//+-------------------------------------------------------------------------------------+
//| ������ ����� ������ ��� ������ (first > second)?                                    |
//+-------------------------------------------------------------------------------------+
bool IsFirstMoreThanSecond(double first, double second)
{
   return (first - second > Point / 1000);
}
//+-------------------------------------------------------------------------------------+
//| �������� �����?                                                                     |
//+-------------------------------------------------------------------------------------+
bool IsValuesEquals(double first, double second)
{
   return (MathAbs(first - second) < Point / 1000);
}
//+-------------------------------------------------------------------------------------+
//| ����������� ����� �����������                                                       |
//+-------------------------------------------------------------------------------------+
color GetHistogrammColor(double maxVolumePrice, int endDayBar)
{
   double dayClosePrice = iClose(NULL, PERIOD_M1, endDayBar);
   
   if (IsValuesEquals(maxVolumePrice, dayClosePrice))
      return (i_indefiniteColor);
      
   if (IsFirstMoreThanSecond(maxVolumePrice, dayClosePrice))
      return (i_resistanceColor);
      
   return (i_supportColor);
}
//+-------------------------------------------------------------------------------------+
//| ����������� ��������� �������                                                       |
//+-------------------------------------------------------------------------------------+
void ShowLevels(int dayVolatility, int& volumesArray[], double minDayPrice, 
                datetime dayBeginTime, int endDayBar, int maxVolume, 
                double maxVolumePrice)
{
   // ����������� ���������� ������, ������������� �� ��������� ������� �����
   double secondsInDay = MathMax(1, 
                                 iTime(NULL, PERIOD_M1, endDayBar) - dayBeginTime + 60);

   double secondsPerVolume = secondsInDay / maxVolume;
   
   // ����������� ����� �����������
   color showColor = GetHistogrammColor(maxVolumePrice, endDayBar);

   // ����������� �����������   
   for (int i = 0; i < dayVolatility; i++)
   {
      double price = minDayPrice + i * Point;
      datetime volume = dayBeginTime + MathRound(secondsPerVolume * volumesArray[i]);
      ShowTrendLine(i, dayBeginTime, price, volume, showColor);  
   }
}
//+-------------------------------------------------------------------------------------+
//| ��������� ������ ��������� ����                                                     |
//+-------------------------------------------------------------------------------------+
void ProcessOneCandle(int index)
{
   // ���� ��� �������� ����� ������ �����, �� ����� �� ��������������
   datetime timeOfBar = Time[index];
   datetime prevBarTime = Time[index + 1];
   if (TimeDayOfYear(timeOfBar) == TimeDayOfYear(prevBarTime) && index != 0)
      return;
      
   // ���������� ���� � ������� ������ ���  
   int endDayBar;
   int beginDayBar = GetIndexesOfDayRange(timeOfBar, endDayBar, index != 0);   
   datetime dayBeginTime = iTime(NULL, PERIOD_M1, beginDayBar);
      
   // ������������ ������� ������ ��� ������� �������������� �� �� ������
   double minDayPrice, maxVolumePrice;
   int maxVolume, dayVolatility;
   FormVolumesArray(beginDayBar, endDayBar, g_volumesArray, 
                    dayVolatility, minDayPrice, maxVolume, maxVolumePrice);
   if (maxVolume == 0)
      return;                    
   
   // ����������� �������
   ShowLevels(dayVolatility, g_volumesArray, minDayPrice, 
              dayBeginTime, endDayBar, maxVolume, maxVolumePrice);
}
//+-------------------------------------------------------------------------------------+
//| ����������� ������ ����������                                                       |
//+-------------------------------------------------------------------------------------+
void ShowIndicatorData(int limit, int total)
{
   for (int i = limit; i >= 0; i--)
      ProcessOneCandle(i);
}
//+-------------------------------------------------------------------------------------+
//| Custom indicator iteration function                                                 |
//+-------------------------------------------------------------------------------------+
int start()
{
   if (!g_activate)                                // ���� ��������� �� ������..
      return (0);                                  // ..�������������, �� �������� ��..
                                                   // ..�� ������
                                                   
   if (!IsAllBarsAvailable(PERIOD_M1))             // �������� ���������� ������ �� �� �1
      return (0);
                                                   
   int total;   
   int limit = GetRecalcIndex(total);              // � ������ ���� �������� ����������

   ShowIndicatorData(limit, total);                // ����������� ������ ����������
   
   WindowRedraw();

   return(0);
}