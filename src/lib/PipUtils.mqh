#ifndef __NOWTRADING_PIPUTILS_MQH__
#define __NOWTRADING_PIPUTILS_MQH__

double PipSize(const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
}

double PipToPrice(const string symbol, const double pips)
{
   return pips * PipSize(symbol);
}

double PriceToPips(const string symbol, const double price_distance)
{
   double pip = PipSize(symbol);
   if(pip <= 0.0)
      return 0.0;
   return price_distance / pip;
}

double NormalizePriceBySymbol(const string symbol, const double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

#endif
