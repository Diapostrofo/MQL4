//+------------------------------------------------------------------+
//|                                                 ax_adv_020_6.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+

/*
  gator ���������-�����������
*/
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict


#import "fx_sample_001.dll"
        void   axInit(string symbol);
        void   axDeinit(string symbol);
        void   axAddOrder(string symbol, int ticket, double sl, int fibo_level, int ext_data, double by_rsi);
        void   axRemoveOrder(string symbol, int ticket);
        double axGetOrderSL(string symbol, int ticket);
        int    axGetOrderFiboLevel(string symbol, int ticket);
        int    axGetOrderExtData(string symbol, int ticket);
        double axGetOrderByRSI(string symbol, int ticket);
        bool   axSetOrderSL(string symbol, int ticket, double sl);
        bool   axSetOrderFiboLevel(string symbol, int ticket, int fibo_level);
        bool   axSetOrderExtData(string symbol, int ticket, int ext_data);
        bool   axSetOrderByRSI(string symbol, int ticket, double by_rsi);
        //array
        void   axClearArray(string symbol);
        void   axAddArrayValue(string symbol, double v);
        double axGetArrayMinValue(string symbol);
        double axGetArrayMaxValue(string symbol);
        //atr_array
        void   axClearATRArray(string symbol);
        void   axAddATRArrayValue(string symbol, int trend_type, double price, double atr_value);
        double axGetATRArrayMinPrice(string symbol);
        double axGetATRArrayMinPriceATR(string symbol);
        double axGetATRArrayMaxPrice(string symbol);
        double axGetATRArrayMaxPriceATR(string symbol);        
#import

#import "fx_sample_002.dll"
        int axInsertMQLData3(string symbol,int timeframe,double sum_up,double sum_up_weighted,int count_up,double sum_down,double sum_down_weighted,int count_down,string bartime);
        int axInsertMQLData4(string symbol,int timeframe,double sum_up,double sum_down,string bartime);
#import



#include <stdlib.mqh>

MqlRates g_ready_bar;

//####################################################################
int g_ticket=-1;//����� �������� ������
input int g_delta_points=10;//����� ����, � ������
//input double g_lots_3=0.01;//������ ���� 3
//input double g_lots_2=0.01;//������ ���� 2
input double g_lot=0.01;//���
input int g_slippage=3;//���������������
input int g_try_count=3;//���������� �������
//input double g_gator_magic_value=1.00000018;//��������� ����� ������
//double g_gator_magic_value=1.001;//��������� ����� ������
/*input */double g_gator_wake_up_val=1.001;//����� �����������
bool g_set_tp=false;//������������� ���� TakeProfit
int g_reversal_bar_cnt_wait=3;//���������� ����� ��� ��������� �����������
//int g_direct_order_exp_bar_count=3;//����� �������� ��������� (������ �����),� �����
//int g_reverse_order_exp_bar_count=21;//����� �������� ��������� (�������� �����),� �����
input int g_order_exp_bar_count=3;//����� �������� ���������,� �����
int g_order_count;//���������� ������� ������� 
double g_gator_bar_diff=1;//���������� ����� ������� � ����� (�����������) (� �����:))
double g_profit_coef=1.0;//������� TakeProfit � ��������� TakeProfit/StopLoss
int g_handle;
double g_profit=1.0;
double g_loss=-0.5;
double g_fibo_coef=0.382;//0.236 0.382 0.500 0.618
//input int g_rsi_period=14;//RSI ������
input int g_demark_period=5;//DeMarker ������
//input bool g_use_rsi_signal=true;//������������ DeMarker ��� �������������
input bool g_logging=false;//����� ����������� � ����

double g_buy_max;
double g_sell_min;
double g_buy_loc_min;
double g_sell_loc_max;
double g_upper_frac;
double g_lower_frac;

double g_fibo_coefs[5];

#include "ax_bar_utils.mqh"

input bool g_use_ichimoku=false;//������������ ichimoku kumo ��� ���������� �����
input adv_trade_mode g_trade_mode=ADVTRADEMODE_BOTH;//����� ������ 0-������ BUY,1-������ SELL,2-� BUY, � SELL

#include "ax_tick_worker.mqh"

const double g_min_level =0.99;
const double g_max_level =1.01;

ax_tick_worker g_tick_worker;

//####################################################################

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
 axInit(Symbol());
 
 g_ticket=-1;//������ ���
 
 g_order_count=0; 

 g_fibo_coefs[FIBO_100]=1.000;
 //g_fibo_coefs[FIBO_618]=0.618;
 g_fibo_coefs[FIBO_618]=0.764;
 g_fibo_coefs[FIBO_500]=0.500;
 g_fibo_coefs[FIBO_382]=0.382;
 g_fibo_coefs[FIBO_236]=0.236;
 
 g_tick_worker.init(TICKWORKGLOBALMODE_BW,Period(),g_min_level,g_max_level);
 
 //����� �������� �������� ���������� ��������������� ����
 MqlRates rates[];
 ArrayCopyRates(rates,NULL,0);

 g_ready_bar=rates[1]; 
 
 if(g_logging)
 {
  string filename=Symbol()+"_"+IntegerToString(Period())+".log"; 
 
  g_handle=FileOpen(filename,FILE_WRITE|FILE_TXT); 
 }
 
 return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
 axDeinit(Symbol());
 
 if(g_logging)
  FileClose(g_handle);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
 MqlRates rates[];
 ArrayCopyRates(rates,NULL,0);

 if(!ax_bar_utils::is_equal(g_ready_bar,rates[1]))//������� ��������� ���
 {
  g_ready_bar=rates[1];//��� ����� ����� �������������� ��� - �������� � ���
  
  //ax_bar_utils::CloseAllOrdersByProfit(OP_BUY,g_profit,g_loss,g_slippage);

  //ax_bar_utils::CloseAllOrdersByProfit(OP_SELL,g_profit,g_loss,g_slippage);
  rsi_mode rsim=ax_bar_utils::get_rsi_mode(g_demark_period);
  
  ax_bar_utils::WriteFile(EnumToString(rsim));
  
  //���������� �����
  gator_formation_trend gft=ax_bar_utils::get_gator_formation_trend(MODE_SMMA,-2,-2,-2,3);
  
  switch(rsim)
  {
   case RSIMODE_MIDDLE_UPPER: //axClearArray(Symbol());
                              axClearATRArray(Symbol());
   case RSIMODE_UPPER: //axAddArrayValue(Symbol(),g_ready_bar.high);
                       axAddATRArrayValue(Symbol(),gft,g_ready_bar.high,NormalizeDouble(iATR(NULL,0,14,1),Digits));
                       //ax_bar_utils::WriteFile("add ready_bar.high="+DoubleToString(g_ready_bar.high));
                       break;
   
   case RSIMODE_MIDDLE_LOWER: //axClearArray(Symbol());
                              axClearATRArray(Symbol());
   case RSIMODE_LOWER://axAddArrayValue(Symbol(),g_ready_bar.low);
                      axAddATRArrayValue(Symbol(),gft,g_ready_bar.low,NormalizeDouble(iATR(NULL,0,14,1),Digits));
                      //ax_bar_utils::WriteFile("add ready_bar.low="+DoubleToString(g_ready_bar.low));
                      break;
   
   case RSIMODE_UPPER_MIDDLE: //����� ����� � BUY
                              //g_all_buy_modify_success=ax_bar_utils::SetAllOrderSLbyFibo3(OP_BUY,axGetArrayMaxValue(Symbol()))==0;
                              //if(g_all_buy_modify_success)
                              // axClearArray(Symbol());
                              ax_bar_utils::SetAllOrderSLbyATR2(OP_SELL,axGetATRArrayMaxPrice(Symbol())+2.618*axGetATRArrayMaxPriceATR(Symbol()));
                              break;
   case RSIMODE_LOWER_MIDDLE: //����� ����� � SELL
                              //g_all_sell_modify_success=ax_bar_utils::SetAllOrderSLbyFibo3(OP_SELL,axGetArrayMinValue(Symbol()))==0;
                              //if(g_all_sell_modify_success)
                              // axClearArray(Symbol());
                              ax_bar_utils::SetAllOrderSLbyATR2(OP_BUY,axGetATRArrayMinPrice(Symbol())-2.618*axGetATRArrayMinPriceATR(Symbol()));
                              break;
  }//switch
 }
 
 //ax_bar_utils::CloseAllOrdersByProfit(OP_BUY,g_profit,g_loss,g_slippage);

 //ax_bar_utils::CloseAllOrdersByProfit(OP_SELL,g_profit,g_loss,g_slippage);
  
 string err_msg;
 //ax_order_settings order_set(g_lot,g_slippage,"DELAYED",g_order_exp_bar_count,MathAbs(g_profit/g_loss),FIBO_618,g_try_count,g_profit,g_loss);
 ax_order_settings order_set(g_lot,g_slippage,"DELAYED",g_order_exp_bar_count,0,FIBO_618,g_try_count);
 
 /*
 double sum_up;
 double sum_down;
 
 t_tickbarpair tbp=g_tick_worker.get_tickbarpair(TICKWORKMODE_SINGLE,sum_up,sum_down);
 
 if(tbp!=TICKBARPAIR_NONE)//��� ������������
 {
  axInsertMQLData4(Symbol(),Period(),sum_up,sum_down,TimeToString(g_ready_bar.time));
 }
 */
 
 t_tickbarpair tbp=g_tick_worker.get_tickbarpair(TICKWORKMODE_SINGLE);
 
 //Print(Symbol()," 1 ",EnumToString(tbp));
 
 //��������� ������� ������������ ���� (�� ��������)
 //���� tickworker ���-�� ������, �� ������ ��� ������������ - ���������� rates[1] � rates[2] 
 if(tbp==TICKBARPAIR_NONEUP && rates[1].low<rates[2].low/* && rates[1].high<rates[2].high*/)//��� ����������� �����
 {
  //Print(Symbol()," 2 UP");
  
  if(ax_bar_utils::get_bar_gator_position(rates,BARPOSITION_UNDERGATOR,BARPOSITIONMODE_FULL,1))
  {
   //Print(Symbol()," 3 UP UNDERGATOR");
  
  if(ax_bar_utils::gator_cross_distance(rates,BARPOSITION_UNDERGATOR))
   ax_bar_utils::trade6_simple(rates,TRADEMODE_BUY,order_set,err_msg,g_use_ichimoku,ORDERSLTYPE_SINGLEBAR);
  }
 }
 else
 if(tbp==TICKBARPAIR_NONEDOWN && rates[1].high>rates[2].high/* && rates[1].low>rates[2].low*/)//��� ����������� ����
 {
  //Print(Symbol()," 2 DOWN");
  
  if(ax_bar_utils::get_bar_gator_position(rates,BARPOSITION_ABOVEGATOR,BARPOSITIONMODE_FULL,1))
  {
   //Print(Symbol()," 3 DOWN ABOVEGATOR");  
   
  if(ax_bar_utils::gator_cross_distance(rates,BARPOSITION_ABOVEGATOR))
   ax_bar_utils::trade6_simple(rates,TRADEMODE_SELL,order_set,err_msg,g_use_ichimoku,ORDERSLTYPE_SINGLEBAR);
  }
 }
 
 if(StringLen(err_msg)!=0)
  Print(Symbol()," ",err_msg);
}

//+------------------------------------------------------------------+
