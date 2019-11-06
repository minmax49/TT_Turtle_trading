# -*- coding: utf-8 -*-
"""
Created on Sat Nov  2 18:24:29 2019

@author: max
"""


import zmq
import numpy as np
#import pandas as pd
class zmq_python():
    
    def __init__(self,repsoket, pullsocket):
        # Create ZMQ Context
        self.context = zmq.Context()

        # Create REQ Socket
        self.reqSocket = self.context.socket(zmq.REQ)
        self.reqSocket.connect("tcp://localhost:" +repsoket)

        # Create PULL Socket
        self.pullSocket = self.context.socket(zmq.PULL)
        self.pullSocket.connect("tcp://localhost:"+pullsocket)
    
    def remote_send(self, socket, data):
        try:
            socket.send_string(data)
            msg_send = socket.recv_string()
            print (msg_send)
            
        except :
            print ("Waiting for PUSH from MetaTrader 4..")
            
    def remote_pull(self, socket):
        try:
            msg_pull = socket.recv(flags=zmq.NOBLOCK)
            return msg_pull
        except :
            print ("Waiting for PUSH from MetaTrader 4..")
            
    
    def get_data(self, symbol, timeframe, start_bar, end_bar):
        '''
        only start_bar and end_bar as int
        '''
        self.data = "DATA|"+ symbol+"|"+timeframe+"|"+str(start_bar)+"|"+str(end_bar+1)
        self.remote_send(self.reqSocket, self.data)
        prices= self.remote_pull(self.pullSocket)
        prices_str= str(prices)
        #print(prices_str)
        prices_arrs = prices_str[2:-1].split( "&")
        open_lst= np.asarray(prices_arrs[0].split(sep='|')[1:], dtype=np.float64)
        high_lst= np.asarray(prices_arrs[1].split(sep='|')[1:], dtype=np.float64)
        low_lst= np.asarray(prices_arrs[2].split(sep='|')[1:], dtype=np.float64)
        close_lst= np.asarray(prices_arrs[3].split(sep='|')[1:], dtype=np.float64)     
        return [np.flip(open_lst),np.flip(high_lst),np.flip(low_lst), np.flip(close_lst) ]
    
    def buy_order(self, symbol, stop_loss, take_profit):
        self.buy= "TRADE|OPEN|0|"+ str(symbol)+"|"+str(stop_loss)+"|"+str(take_profit)
        self.remote_send(self.reqSocket, self.buy)
        reply= self.remote_pull(self.pullSocket)
        return reply
    
    def sell_order(self, symbol, stop_loss, take_profit):
        self.buy= "TRADE|OPEN|1|"+ str(symbol)+"|"+str(stop_loss)+"|"+str(take_profit)
        self.remote_send(self.reqSocket, self.buy)
        reply= self.remote_pull(self.pullSocket)
        return reply
    
    def close_buy_order(self,Ticket):
        self.close_buy= "TRADE|CLOSE|0|"+ str(Ticket)
        self.remote_send(self.reqSocket, self.close_buy)
        reply= self.remote_pull(self.pullSocket)
        return reply
    
    def close_sell_order(self,Ticket):
        self.close_sell= "TRADE|CLOSE|1|"+ str(Ticket)
        self.remote_send(self.reqSocket, self.close_sell)
        reply= self.remote_pull(self.pullSocket)
        return reply
    
    def info_order(self,Ticket):
        self.close_sell= "INFO|" + str(Ticket)
        self.remote_send(self.reqSocket, self.close_sell)
        reply= self.remote_pull(self.pullSocket)
        info = str(reply)
        info = np.asarray(info[2:-1].split( "|"), dtype=np.float32)
        return info
    
    def modify_order(self,Ticket, stoploss):
        self.close_sell= "MODIFY|" + str(Ticket) + "|" + str(stoploss)
        self.remote_send(self.reqSocket, self.close_sell)
        reply= self.remote_pull(self.pullSocket)
        return reply 

    def timing(self, symbol, timeframe):
        self.data = "TIMING|"+ symbol+"|"+timeframe
        self.remote_send(self.reqSocket, self.data)
        timing= self.remote_pull(self.pullSocket)
        timing= str(timing)
        return timing[2:-1]
        