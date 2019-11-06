# -*- coding: utf-8 -*-
"""
Created on Sun Nov  3 04:56:35 2019

@author: max
"""

from twilio.rest import Client

# Your Account SID from twilio.com/console
account_sid = "ACae0d35af5c03aa8b55f1ac8d00115387"
# Your Auth Token from twilio.com/console
auth_token  = "1291d5e0afefd637d3193a589b4221e4"

client = Client(account_sid, auth_token)

"""
message = client.messages.create(
    to= "+84914198598", 
    from_="+12015089680",
    body="Hello from Python!")

print(message.sid)
"""

to= "+84988960103" 
#to= "+84914198598"
from_ = "+12015089680"

TWIML_INSTRUCTIONS_URL = \
  "http://static.fullstackpython.com/phone-calls-python.xml"

client.calls.create(to=to, from_=from_,url=TWIML_INSTRUCTIONS_URL, method="GET")