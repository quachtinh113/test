#property strict
#property version   "1.00"
#property description "NowTrading Demon-Mode $20/30min RSI Basket EA"

#include <Trade/Trade.mqh>
#include "lib/PipUtils.mqh"
#include "lib/Indicators.mqh"
#include "lib/BasketState.mqh"
#include "lib/TradeUtils.mqh"

input long   InpMagicNumber            = 20260302;
input string InpCommentTag             = "NOWTRADING_DEMON_RSI_BASKET";
input int    InpRsiPeriod              = 14;
input double InpMaxSpreadPips          = 2.0;
input double InpMinFreeMarginPercent   = 60.0;
input int    InpMaxBasketsPerDay       = 6;
input bool   InpDryRunMode             = false;
input int    InpMaxDcaLayers           = 3;
input int    InpTradeRetries           = 3;
input int    InpDeviationPoints        = 20;

input double InpBaseLotA               = 0.15;
input double InpBaseLotB               = 0.15;
input double InpBaseLimitLot           = 0.10;
input double InpDcaLot                 = 0.10;
input double InpBaseLimitDistancePips  = 10.0;
input double InpDcaDistancePips        = 30.0;
input double InpBasketTpUsd            = 20.0;
input double InpHardStopUsd            = -250.0;

CTrade g_trade;
datetime g_last_eval_minute = 0;
datetime g_day_anchor = 0;
int g_baskets_today = 0;

int BasketAgeHours(const BasketState &s)
{
   if(!s.active || s.open_time <= 0)
      return 0;
   return (int)((TimeCurrent() - s.open_time) / 3600);
}

bool IsNeutralRegime(const double rsi)
{
   return (rsi > 45.0 && rsi < 55.0);
}

void ResetDayCounterIfNeeded()
{
   MqlDateTime now_dt, anchor_dt;
   TimeToStruct(TimeCurrent(), now_dt);

   if(g_day_anchor == 0)
   {
      now_dt.hour = 0; now_dt.min = 0; now_dt.sec = 0;
      g_day_anchor = StructToTime(now_dt);
      return;
   }

   TimeToStruct(g_day_anchor, anchor_dt);
   if(anchor_dt.year != now_dt.year || anchor_dt.mon != now_dt.mon || anchor_dt.day != now_dt.day)
   {
      now_dt.hour = 0; now_dt.min = 0; now_dt.sec = 0;
      g_day_anchor = StructToTime(now_dt);
      g_baskets_today = 0;
      Print("Day rolled. baskets_today reset.");
   }
}

int CountBasketsOpenedToday(const string symbol, const long magic, const string tag)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime day_start = StructToTime(dt);

   if(!HistorySelect(day_start, TimeCurrent()))
      return 0;

   int count = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;

      string cmt = HistoryDealGetString(ticket, DEAL_COMMENT);
      if(StringFind(cmt, tag + "|BASE_MKT1") >= 0)
         count++;
   }

   return count;
}

bool IsEntryMinute(datetime now)
{
   MqlDateTime t;
   TimeToStruct(now, t);
   return (t.min == 1 || t.min == 31);
}

bool IsNewMinute(datetime now)
{
   datetime minute_anchor = now - (now % 60);
   if(minute_anchor == g_last_eval_minute)
      return false;

   g_last_eval_minute = minute_anchor;
   return true;
}

bool BuildEntrySignal(int &direction)
{
   direction = 0;

   double rsi_h4 = 0.0, rsi_h1 = 0.0;
   if(!GetRsiClosed(_Symbol, PERIOD_H4, InpRsiPeriod, 1, rsi_h4))
      return false;
   if(!GetRsiClosed(_Symbol, PERIOD_H1, InpRsiPeriod, 1, rsi_h1))
      return false;

   if(IsNeutralRegime(rsi_h4) || IsNeutralRegime(rsi_h1))
   {
      PrintFormat("ENTRY BLOCK: neutral regime H4=%.2f H1=%.2f", rsi_h4, rsi_h1);
      return true;
   }

   bool cross_up = false, cross_down = false;
   double m30_prev = 0.0, m30_curr = 0.0;
   if(!GetRsiCrossM30(_Symbol, InpRsiPeriod, cross_up, cross_down, m30_prev, m30_curr))
      return false;

   if(rsi_h4 >= 55.0 && rsi_h1 >= 55.0 && cross_up)
      direction = 1;
   else if(rsi_h4 <= 45.0 && rsi_h1 <= 45.0 && cross_down)
      direction = -1;
   else
      PrintFormat("ENTRY BLOCK: RSI not aligned H4=%.2f H1=%.2f M30(prev=%.2f curr=%.2f)", rsi_h4, rsi_h1, m30_prev, m30_curr);

   return true;
}

bool OpenBaseBasket(const int direction)
{
   bool is_buy = (direction > 0);
   string side = is_buy ? "BUY" : "SELL";

   if(!SendMarketOrder(g_trade, _Symbol, is_buy, InpBaseLotA, InpCommentTag + "|BASE_MKT1", InpDryRunMode, InpTradeRetries, InpDeviationPoints))
      return false;
   if(!SendMarketOrder(g_trade, _Symbol, is_buy, InpBaseLotB, InpCommentTag + "|BASE_MKT2", InpDryRunMode, InpTradeRetries, InpDeviationPoints))
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double anchor = is_buy ? ask : bid;
   double lmt_price = is_buy ? (anchor - PipToPrice(_Symbol, InpBaseLimitDistancePips))
                             : (anchor + PipToPrice(_Symbol, InpBaseLimitDistancePips));
   lmt_price = NormalizePriceBySymbol(_Symbol, lmt_price);

   if(!SendLimitOrder(_Symbol, is_buy, InpBaseLimitLot, lmt_price, InpMagicNumber, InpCommentTag + "|BASE_LMT", InpDryRunMode, InpTradeRetries, InpDeviationPoints))
      return false;

   PrintFormat("BASKET OPENED: %s base 0.15+0.15 and limit 0.10 @ %.5f", side, lmt_price);
   return true;
}

void CloseAndReset(const string reason)
{
   PrintFormat("EXIT TRIGGERED: %s", reason);
   CloseAllPositionsForMagicSymbol(_Symbol, InpMagicNumber, InpCommentTag, g_trade, InpDryRunMode);
   CancelAllPendingForMagicSymbol(_Symbol, InpMagicNumber, InpCommentTag, g_trade, InpDryRunMode);
}

void CheckExitRules(const BasketState &state)
{
   if(!state.active)
      return;

   if(state.total_profit >= InpBasketTpUsd)
   {
      CloseAndReset("Basket TP +20 USD");
      return;
   }

   if(state.total_profit <= InpHardStopUsd)
   {
      CloseAndReset("Hard stop -250 USD");
      return;
   }

   int age_h = BasketAgeHours(state);
   if(age_h >= 12)
   {
      double rsi_h4 = 0.0, rsi_d1 = 0.0;
      if(!GetRsiClosed(_Symbol, PERIOD_H4, InpRsiPeriod, 1, rsi_h4) ||
         !GetRsiClosed(_Symbol, PERIOD_D1, InpRsiPeriod, 1, rsi_d1))
      {
         Print("EXIT CHECK WARN: could not read H4/D1 RSI.");
         return;
      }

      if(state.direction > 0 && rsi_h4 < 45.0 && rsi_d1 < 45.0)
      {
         CloseAndReset("12h reversal exit BUY basket (H4&D1 bearish)");
         return;
      }
      if(state.direction < 0 && rsi_h4 > 55.0 && rsi_d1 > 55.0)
      {
         CloseAndReset("12h reversal exit SELL basket (H4&D1 bullish)");
         return;
      }
   }
}

void CheckDca(const BasketState &state)
{
   if(!state.active || state.position_count <= 0)
      return;

   int age_h = BasketAgeHours(state);
   if(age_h >= 6)
   {
      Print("DCA BLOCK: basket age >= 6h.");
      return;
   }

   if(state.dca_count >= InpMaxDcaLayers)
   {
      Print("DCA BLOCK: max dca layers reached.");
      return;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double free_margin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
   double free_margin_pct = (equity > 0.0 ? (free_margin / equity) * 100.0 : 0.0);
   if(free_margin_pct < InpMinFreeMarginPercent)
   {
      PrintFormat("DCA BLOCK: free margin %% %.2f < %.2f", free_margin_pct, InpMinFreeMarginPercent);
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(state.direction > 0)
   {
      double trigger = state.last_fill_price - PipToPrice(_Symbol, InpDcaDistancePips);
      if(bid <= trigger)
      {
         if(SendMarketOrder(g_trade, _Symbol, true, InpDcaLot, InpCommentTag + "|DCA_" + IntegerToString(state.dca_count + 1), InpDryRunMode, InpTradeRetries, InpDeviationPoints))
            PrintFormat("DCA BUY executed at Bid=%.5f trigger=%.5f", bid, trigger);
      }
   }
   else if(state.direction < 0)
   {
      double trigger = state.last_fill_price + PipToPrice(_Symbol, InpDcaDistancePips);
      if(ask >= trigger)
      {
         if(SendMarketOrder(g_trade, _Symbol, false, InpDcaLot, InpCommentTag + "|DCA_" + IntegerToString(state.dca_count + 1), InpDryRunMode, InpTradeRetries, InpDeviationPoints))
            PrintFormat("DCA SELL executed at Ask=%.5f trigger=%.5f", ask, trigger);
      }
   }
}

void CheckEntry(const BasketState &state)
{
   if(state.active)
   {
      Print("ENTRY BLOCK: active basket exists.");
      return;
   }

   if(g_baskets_today >= InpMaxBasketsPerDay)
   {
      PrintFormat("ENTRY BLOCK: max baskets/day reached (%d).", g_baskets_today);
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread_pips = PriceToPips(_Symbol, ask - bid);
   if(spread_pips > InpMaxSpreadPips)
   {
      PrintFormat("ENTRY BLOCK: spread %.2f pips > %.2f", spread_pips, InpMaxSpreadPips);
      return;
   }

   int direction = 0;
   if(!BuildEntrySignal(direction))
   {
      Print("ENTRY BLOCK: indicator read failed.");
      return;
   }
   if(direction == 0)
      return;

   if(OpenBaseBasket(direction))
   {
      g_baskets_today++;
      PrintFormat("Entry accepted. baskets_today=%d", g_baskets_today);
   }
}

int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_baskets_today = CountBasketsOpenedToday(_Symbol, InpMagicNumber, InpCommentTag);

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   now_dt.hour = 0; now_dt.min = 0; now_dt.sec = 0;
   g_day_anchor = StructToTime(now_dt);

   PrintFormat("INIT OK: baskets_today=%d symbol=%s magic=%I64d", g_baskets_today, _Symbol, InpMagicNumber);
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   ResetDayCounterIfNeeded();

   BasketState state;
   ReconstructBasketState(_Symbol, InpMagicNumber, InpCommentTag, state);

   CheckExitRules(state);

   // Refresh state after possible close
   ReconstructBasketState(_Symbol, InpMagicNumber, InpCommentTag, state);
   if(state.active)
      CheckDca(state);

   datetime now = TimeCurrent();
   if(!IsNewMinute(now))
      return;
   if(!IsEntryMinute(now))
      return;

   // Entry is only checked at minute 01 / 31
   ReconstructBasketState(_Symbol, InpMagicNumber, InpCommentTag, state);
   CheckEntry(state);
}
