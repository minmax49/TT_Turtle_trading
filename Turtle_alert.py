 # -*- coding: utf-8 -*-
"""
Created on Sun Nov  3 00:39:35 2019

@author: max
"""



import Turtle_client as pm4
import time
import numpy as np
import matplotlib.pyplot as plt 
import send_mail 


def turtle_trading(trade, symbol='EURUSD', timeframe='60'):
    data = trade.get_data(symbol=symbol, timeframe=timeframe,
                              start_bar=0, end_bar=60)
    highs, lows, closes = data[1], data[2], data[3]
    trends = []
    status = ""
    for i, close in enumerate(closes[20:]):
        #rhigh,rlow,shigh,slow  = high_low_rs(highs[20+i-20: 20+i], lows[20+i-20: 20+i])
        high_l,low_l = highs[20+i-20: 20+i],  lows[20+i-20: 20+i]
        rhigh,rlow = max(high_l[-20:]), min(low_l[-20:])
        trend = status
        if close > rhigh  and status != "OP_BUY":
            trend = "OP_BUY"
        elif close < rlow and status != "OP_SELL":
            trend = "OP_SELL"

        status = trend 
        trends.append(trend)
    
    trend_type = ""
    if trends[-1] != trends[-2]:
        trend_type = trends[-1] 
    return trends, trend_type
 
    
if __name__ == "__main__":
    
    trade= pm4.zmq_python('1111', '1112')
    turtle_h1 = ""
    turtle_m15 = ""
    
    while True:
        alert = ""
        print('---'*12 , 'h1')
        
        # check turtle h1
        trends_h1,trend_type_h1 = turtle_trading(trade, symbol='EURUSD', timeframe='60')
        if trend_type_h1 != "":
            turtle_h1 = trend_type_h1 
            turtle_m15 = "" # reset turtle_m15

        # check turtle h1
        #if turtle_h1 != "":

        trends_m15,trend_type_m15 = turtle_trading(trade, symbol='EURUSD', timeframe='15')
        
        # check alert
        if turtle_h1 == "OP_BUY" :
            if trends_m15[-1] == "OP_BUY" and trade.timing(symbol='EURUSD', timeframe='15')  <= 30 :
                alert = "BUY" 
                send_mail.send_mail(alert)
                
        elif turtle_h1 == "OP_SELL" :
            if trends_m15[-1] == "OP_SELL" and trade.timing(symbol='EURUSD', timeframe='15')  >= 30 :
                alert = "SELL"
                send_mail.send_mail(alert)


        
        time.sleep(10)
        

