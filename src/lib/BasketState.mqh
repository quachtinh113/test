#ifndef __NOWTRADING_BASKETSTATE_MQH__
#define __NOWTRADING_BASKETSTATE_MQH__

struct BasketState
{
   bool active;
   int direction; // +1 buy, -1 sell, 0 unknown
   datetime open_time;
   double last_fill_price;
   int dca_count;
   double total_profit;
   int position_count;
   int pending_count;
};

bool IsOurPosition(const string symbol, const long magic, const string tag)
{
   string psymbol = PositionGetString(POSITION_SYMBOL);
   long pmagic = (long)PositionGetInteger(POSITION_MAGIC);
   string cmt = PositionGetString(POSITION_COMMENT);
   return (psymbol == symbol && pmagic == magic && StringFind(cmt, tag) >= 0);
}

bool IsOurOrder(const string symbol, const long magic, const string tag)
{
   string osymbol = OrderGetString(ORDER_SYMBOL);
   long omagic = (long)OrderGetInteger(ORDER_MAGIC);
   string cmt = OrderGetString(ORDER_COMMENT);
   return (osymbol == symbol && omagic == magic && StringFind(cmt, tag) >= 0);
}

void ResetBasketState(BasketState &s)
{
   s.active = false;
   s.direction = 0;
   s.open_time = 0;
   s.last_fill_price = 0.0;
   s.dca_count = 0;
   s.total_profit = 0.0;
   s.position_count = 0;
   s.pending_count = 0;
}

bool ReconstructBasketState(const string symbol, const long magic, const string tag, BasketState &state)
{
   ResetBasketState(state);

   datetime latest_fill_time = 0;

   int ptotal = PositionsTotal();
   for(int i = 0; i < ptotal; i++)
   {
      if(!PositionSelectByIndex(i))
         continue;
      if(!IsOurPosition(symbol, magic, tag))
         continue;

      state.active = true;
      state.position_count++;
      state.total_profit += PositionGetDouble(POSITION_PROFIT);

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(state.direction == 0)
         state.direction = (type == POSITION_TYPE_BUY ? 1 : -1);

      datetime ptime = (datetime)PositionGetInteger(POSITION_TIME);
      if(state.open_time == 0 || ptime < state.open_time)
         state.open_time = ptime;

      datetime update_time = (datetime)PositionGetInteger(POSITION_TIME_UPDATE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(update_time >= latest_fill_time)
      {
         latest_fill_time = update_time;
         state.last_fill_price = open_price;
      }

      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, "DCA_") >= 0)
         state.dca_count++;
   }

   int ototal = OrdersTotal();
   for(int j = 0; j < ototal; j++)
   {
      ulong oticket = OrderGetTicket(j);
      if(oticket == 0 || !OrderSelect(oticket))
         continue;
      if(!IsOurOrder(symbol, magic, tag))
         continue;

      ENUM_ORDER_STATE ostate = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
      if(ostate != ORDER_STATE_PLACED && ostate != ORDER_STATE_PARTIAL)
         continue;

      state.active = true;
      state.pending_count++;

      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(state.direction == 0)
      {
         if(otype == ORDER_TYPE_BUY_LIMIT || otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY_STOP_LIMIT)
            state.direction = 1;
         else if(otype == ORDER_TYPE_SELL_LIMIT || otype == ORDER_TYPE_SELL_STOP || otype == ORDER_TYPE_SELL_STOP_LIMIT)
            state.direction = -1;
      }

      datetime otime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(state.open_time == 0 || otime < state.open_time)
         state.open_time = otime;
   }

   return true;
}

#endif
