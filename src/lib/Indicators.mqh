#ifndef __NOWTRADING_INDICATORS_MQH__
#define __NOWTRADING_INDICATORS_MQH__

bool GetRsiClosed(const string symbol, ENUM_TIMEFRAMES tf, const int period, const int shift, double &value)
{
   value = 0.0;
   int h = iRSI(symbol, tf, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE)
      return false;

   double buff[];
   ArraySetAsSeries(buff, true);
   int copied = CopyBuffer(h, 0, shift, 1, buff);
   IndicatorRelease(h);
   if(copied != 1)
      return false;

   value = buff[0];
   return true;
}

bool GetRsiCrossM30(const string symbol, const int period, bool &cross_up, bool &cross_down, double &prev_rsi, double &curr_rsi)
{
   cross_up = false;
   cross_down = false;
   prev_rsi = 0.0;
   curr_rsi = 0.0;

   int h = iRSI(symbol, PERIOD_M30, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE)
      return false;

   double buff[2];
   ArraySetAsSeries(buff, true);
   // shift=1 (latest closed), shift=2 (previous closed)
   int copied = CopyBuffer(h, 0, 1, 2, buff);
   IndicatorRelease(h);
   if(copied != 2)
      return false;

   curr_rsi = buff[0];
   prev_rsi = buff[1];

   cross_up = (prev_rsi <= 50.0 && curr_rsi > 50.0);
   cross_down = (prev_rsi >= 50.0 && curr_rsi < 50.0);
   return true;
}

#endif
