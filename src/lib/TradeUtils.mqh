#ifndef __NOWTRADING_TRADEUTILS_MQH__
#define __NOWTRADING_TRADEUTILS_MQH__

#include <Trade/Trade.mqh>

bool IsRetriableTradeError(const uint code)
{
   return (code == TRADE_RETCODE_REQUOTE ||
           code == TRADE_RETCODE_PRICE_CHANGED ||
           code == TRADE_RETCODE_PRICE_OFF ||
           code == TRADE_RETCODE_CONNECTION ||
           code == TRADE_RETCODE_TIMEOUT ||
           code == TRADE_RETCODE_TOO_MANY_REQUESTS);
}

double NormalizeLotsBySymbol(const string symbol, const double lots)
{
   double minlot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxlot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;

   double v = MathMax(minlot, MathMin(maxlot, lots));
   double n = MathFloor(v / step) * step;
   int vol_digits = 2;
   if(step == 1.0)
      vol_digits = 0;
   else if(step == 0.1)
      vol_digits = 1;
   return NormalizeDouble(n, vol_digits);
}

bool SendMarketOrder(CTrade &trade,
                     const string symbol,
                     const bool is_buy,
                     const double volume,
                     const string comment,
                     const bool dry_run,
                     const int retries,
                     const int deviation_points)
{
   double vol = NormalizeLotsBySymbol(symbol, volume);
   if(vol <= 0.0)
      return false;

   if(dry_run)
   {
      PrintFormat("[DRYRUN] Market %s %.2f %s cmt=%s", (is_buy ? "BUY" : "SELL"), vol, symbol, comment);
      return true;
   }

   trade.SetDeviationInPoints(deviation_points);

   for(int i = 0; i < retries; i++)
   {
      bool ok = is_buy ? trade.Buy(vol, symbol, 0.0, 0.0, 0.0, comment)
                       : trade.Sell(vol, symbol, 0.0, 0.0, 0.0, comment);
      if(ok)
         return true;

      uint rc = trade.ResultRetcode();
      PrintFormat("Market order failed rc=%u (%s), attempt=%d", rc, trade.ResultRetcodeDescription(), i + 1);
      if(!IsRetriableTradeError(rc))
         break;
      Sleep(250);
   }

   return false;
}

bool SendLimitOrder(const string symbol,
                    const bool is_buy_limit,
                    const double volume,
                    const double price,
                    const long magic,
                    const string comment,
                    const bool dry_run,
                    const int retries,
                    const int deviation_points)
{
   if(dry_run)
   {
      PrintFormat("[DRYRUN] Pending %s %.2f %s @ %.5f cmt=%s", (is_buy_limit ? "BUY_LIMIT" : "SELL_LIMIT"), volume, symbol, price, comment);
      return true;
   }

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_PENDING;
   req.symbol = symbol;
   req.magic = magic;
   req.volume = NormalizeLotsBySymbol(symbol, volume);
   req.price = price;
   req.type = (is_buy_limit ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);
   req.type_time = ORDER_TIME_GTC;
   req.type_filling = ORDER_FILLING_RETURN;
   req.deviation = deviation_points;
   req.comment = comment;

   for(int i = 0; i < retries; i++)
   {
      if(OrderSend(req, res))
      {
         if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED)
            return true;
      }
      PrintFormat("Limit order failed rc=%u, attempt=%d", res.retcode, i + 1);
      if(!IsRetriableTradeError((uint)res.retcode))
         break;
      Sleep(250);
   }

   return false;
}

bool CancelAllPendingForMagicSymbol(const string symbol, const long magic, const string tag, CTrade &trade, const bool dry_run)
{
   bool all_ok = true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, tag) < 0)
         continue;

      if(dry_run)
      {
        PrintFormat("[DRYRUN] Cancel pending ticket=%I64u", ticket);
        continue;
      }

      bool ok = trade.OrderDelete(ticket);
      if(!ok)
      {
         all_ok = false;
         PrintFormat("Failed cancel pending ticket=%I64u rc=%u", ticket, trade.ResultRetcode());
      }
   }
   return all_ok;
}

bool CloseAllPositionsForMagicSymbol(const string symbol, const long magic, const string tag, CTrade &trade, const bool dry_run)
{
   bool all_ok = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, tag) < 0)
         continue;

      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(dry_run)
      {
         PrintFormat("[DRYRUN] Close position ticket=%I64u", ticket);
         continue;
      }

      bool ok = trade.PositionClose(ticket);
      if(!ok)
      {
         all_ok = false;
         PrintFormat("Failed close pos ticket=%I64u rc=%u", ticket, trade.ResultRetcode());
      }
   }

   return all_ok;
}

#endif
