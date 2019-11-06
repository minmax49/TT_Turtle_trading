
import smtplib

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from email.mime.base import MIMEBase
from email import encoders
import random

def send_mail(status):
    me = "dream4996@gmail.com"
    #me = "minh.nguyen.50@fecredit.com.vn"
    to = "nguyenquangminh4996@gmail.com"
    cc = ["trungthanh3005@gmail.com"]
    # Create message container - the correct MIME type is multipart/alternative.
    msg = MIMEMultipart('alternative')
    msg['Subject'] = "TT_Turle Trading Test"
    msg['From'] = me
    msg['To'] = to
    msg['Cc'] = "trungthanh3005@gmail.com"

    # Create the body of the message (a plain-text and an HTML version).

    html = """
    <html>
    <head></head>
    <body>
        <h1> This is a automation mail from Max_Thor </h1>
        <p style="text-align:left">TT alert!<br>
            Testing for EURUSD H1 and M15 <br>
            <b style="color :blue ; font-family:verdana; font-size:300%;"">{}</b>
        </p>
        <img src="cid:image1"><br>
    </body>
    </html>
    """.format(status)
    # Record the MIME types of both parts - text/plain and text/html.

    part2 = MIMEText(html, 'html')
    msg.attach(part2)
    # add file
    #---------
    img_path = random.choice(['a1.jpg','a2.jpg','a3.jpg','a4.jpg','a5.jpg','a6.jpg'])
    fp = open(img_path, 'rb')
    msgImage = MIMEImage(fp.read())
    fp.close()
    msgImage.add_header('Content-ID', '<image1>')
    msg.attach(msgImage)
    #---------

    # Send the message via local SMTP server.
    server = smtplib.SMTP('smtp.gmail.com', 587)
    server.starttls()
    server.login("dream4996@gmail.com", "minh1234!@#$")
    # and message to send - here it is sent as one string.
    toaddrs = [to] + cc 
    server.sendmail(me, toaddrs, msg.as_string())
    server.quit()


if __name__ == "__main__":
    send_mail('test')
