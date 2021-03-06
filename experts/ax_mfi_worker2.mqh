//+------------------------------------------------------------------+
//|                                               ax_mfi_worker2.mqh |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "http://www.mql4.com"
#property strict

class ax_mfi_worker2
{
 public:
  bool value(MqlRates& rates[],int shift,t_mfivalue indival);
  
 private:
  t_mfivalue bwmfi(MqlRates& rates[],int shift);
  t_mfivalue axmfi_1(MqlRates& rates[],int shift);
  t_mfivalue axmfi_2(MqlRates& rates[],int shift);
  t_mfivalue axmfi_3(MqlRates& rates[],int shift);
  t_mfivalue get_val(double mfi,double prev_mfi,long v,long prev_v);
};

//+------------------------------------------------------------------+
bool ax_mfi_worker2::value(MqlRates& rates[],int shift,t_mfivalue indival)
{
 int cnt=0;
 
 if(this.bwmfi(rates,shift)==indival)
  cnt++;
  
 if(this.axmfi_1(rates,shift)==indival)
  cnt++;
  
 if(this.axmfi_2(rates,shift)==indival)
  cnt++;
  
 if(this.axmfi_3(rates,shift)==indival)
  cnt++;
  
 return cnt>=3;//три из четырех
}

//+------------------------------------------------------------------+
t_mfivalue ax_mfi_worker2::bwmfi(MqlRates &rates[],int shift)
{
 double mfi      =(rates[shift].high-rates[shift].low)/rates[shift].tick_volume/_Point;
 double prev_mfi =(rates[shift+1].high-rates[shift+1].low)/rates[shift+1].tick_volume/_Point;
 
 return this.get_val(mfi,prev_mfi,rates[shift].tick_volume,rates[shift+1].tick_volume);
}

//+------------------------------------------------------------------+
t_mfivalue ax_mfi_worker2::axmfi_1(MqlRates& rates[],int shift)
{
 double gator       =iAlligator(NULL,0,13,8,8,5,5,3,MODE_SMMA,PRICE_MEDIAN,MODE_GATORJAW,shift);
 double prev_gator  =iAlligator(NULL,0,13,8,8,5,5,3,MODE_SMMA,PRICE_MEDIAN,MODE_GATORJAW,shift+1);
 
 double median      =(rates[shift].high+rates[shift].low)/2;
 double prev_median =(rates[shift+1].high+rates[shift+1].low)/2;
 
 double mfi      =MathAbs(median-gator)/rates[shift].tick_volume/_Point;
 double prev_mfi =MathAbs(prev_median-prev_gator)/rates[shift+1].tick_volume/_Point;
 
 return this.get_val(mfi,prev_mfi,rates[shift].tick_volume,rates[shift+1].tick_volume);
}

//+------------------------------------------------------------------+
t_mfivalue ax_mfi_worker2::axmfi_2(MqlRates &rates[],int shift)
{
 double mfi      =MathAbs(rates[shift].close-rates[shift].open)/rates[shift].tick_volume/_Point;
 double prev_mfi =MathAbs(rates[shift+1].close-rates[shift+1].open)/rates[shift+1].tick_volume/_Point;
 
 return this.get_val(mfi,prev_mfi,rates[shift].tick_volume,rates[shift+1].tick_volume);
}

//+------------------------------------------------------------------+
t_mfivalue ax_mfi_worker2::axmfi_3(MqlRates &rates[],int shift)
{
 double diff_h=(rates[shift].high-rates[shift].low)/rates[shift].tick_volume/_Point;
 double diff_o=MathAbs(rates[shift].close-rates[shift].open)/rates[shift].tick_volume/_Point;
       
 double mfi=(diff_h+diff_o)/2;
 
 diff_h=(rates[shift+1].high-rates[shift+1].low)/rates[shift+1].tick_volume/_Point;
 diff_o=MathAbs(rates[shift+1].close-rates[shift+1].open)/rates[shift+1].tick_volume/_Point;
 
 double prev_mfi =(diff_h+diff_o)/2;
 
 return this.get_val(mfi,prev_mfi,rates[shift].tick_volume,rates[shift+1].tick_volume);
}

//+------------------------------------------------------------------+
t_mfivalue ax_mfi_worker2::get_val(double mfi,double prev_mfi,long v,long prev_v)
{
 if(mfi>prev_mfi && v>prev_v)
  return MFIVALUE_GREEN;
  
 if(mfi<prev_mfi && v>prev_v)
  return MFIVALUE_PINK;
  
 if(mfi>prev_mfi && v<prev_v)
  return MFIVALUE_BLUE;
  
 return MFIVALUE_BROWN;
}

//+------------------------------------------------------------------+
