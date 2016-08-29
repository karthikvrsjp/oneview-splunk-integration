import pika, ssl
import sys, os
from hpOneView import *
from pika.credentials import ExternalCredentials
import json
import logging
import argparse
import time
import traceback


pwd=os.getcwd()

serverProfilesList=[]
serverHardwareList=[]
global host, user, passwd, threads,tim1, dat, count, fo
threads=[]
tim1=time.strftime("%H:%M:%S")
dat = time.strftime("%d-%m-%Y")
count=0
###############################################
# Callback function that handles messages
def callback(ch, method, properties, body):
    if isinstance(body, str):
        msg = json.loads(body)
    elif str(type(body)) == "<class 'bytes'>":
        msg = json.loads(body.decode('ascii'))
    elif str(type(body)) == "<type 'unicode'>":
        msg = json.loads(body.decode("utf-8"))
    timestamp = msg['timestamp']
    resource = msg['resource']
    changeType = msg['changeType']
    if(('alertState' in resource) and ('severity' in resource)):
        if((('Active' == resource['alertState']) or ('Cleared' == resource['alertState'])) and ('Critical' == resource['severity']) ):
            print(resource)
            global count
            count = count + 1
            try:
                print("Critical Created!")
                create_syslog(resource)
            except:
                print("Error in logging the alert")

#function to convert alerts into  syslog format
def create_syslog(json_obj):
    #version=count
    global count
    fo = open(syslog_file, "a")
    created_date = json_obj['created']
    severity = json_obj['severity']
    uri = json_obj['uri']
    associated_rsc = json_obj['associatedResource']['associationType']+json_obj['associatedResource']['resourceCategory']+json_obj['associatedResource']['resourceName']+json_obj['associatedResource']['resourceUri']+json_obj['alertState']+json_obj['physicalResourceType']
    desc=json_obj['correctiveAction']
    if desc == None :
        Converted_str=convert_string(desc)
        desc=json_obj['description']+Converted_str
    else:
        desc=json_obj['description']+json_obj['correctiveAction']
    fo.write('OneView_Alerts-'+str(count)+" "+str(created_date)+" "+str(severity)+" "+str(uri)+" "+"-"+str(associated_rsc)+" "+"["+desc+"]"+" "+"\n")

#function for converting None type to string type
def convert_string(value):
    new_value = str(value)
    return new_value


def login(con, credential):
        # Login with givin credentials
        try:
                con.login(credential)
        except:
                print('Login failed')

def logout(con):
        # Logout 
        try:
                con.logout()
        except:
                print('Logout failed')



def acceptEULA(con):
        # See if we need to accept the EULA before we try to log in
        con.get_eula_status()
        try:
                if con.get_eula_status() is True:
                        con.set_eula('no')
        except Exception as e:
                print('EXCEPTION:')
                print(e)



def getCertCa(sec):
        cert = sec.get_cert_ca()
        ca = open('caroot.pem', 'w+')
        ca.write(cert)
        ca.close()


def genRabbitCa(sec):
       sec.gen_rabbitmq_internal_signed_ca()


def getRabbitKp(sec):
        cert = sec.get_rabbitmq_kp()
        ca = open('client.pem', 'w+')
        ca.write(cert['base64SSLCertData'])
        ca.close()
        ca = open('key.pem', 'w+')
        ca.write(cert['base64SSLKeyData'])
        ca.close()

def recv(host, route):

        # Pem Files needed, be sure to replace the \n returned from the APIs with CR/LF
        # caroot.pem - the CA Root certificate - GET /rest/certificates/ca
        # client.pem, first POST /rest/certificates/client/rabbitmq Request body:
        #    {"type":"RabbitMqClientCertV2","commonName":"default"}
        # GET /rest/certificates/client/rabbitmq/keypair/default
        # client.pem is the key with -----BEGIN CERTIFICATE-----
        # key.pem is the key with -----BEGIN RSA PRIVATE KEY-----

        # Setup our ssl options
        ssl_options = ({"ca_certs": "caroot.pem",
                "certfile": "client.pem",
                "keyfile": "key.pem",
                "cert_reqs": ssl.CERT_REQUIRED,
                "ssl_version": ssl.PROTOCOL_TLSv1_1,
                "server_side": False})

        # Connect to RabbitMQ
        print ("Connecting to %s:5671, to change use --host hostName " %(host))
        connection= None
        try:
            connection = pika.BlockingConnection(
                    pika.ConnectionParameters(
                            host, 5671, credentials=ExternalCredentials(),
                            ssl=True, ssl_options=ssl_options))
        except:
            connection = pika.BlockingConnection(
                    pika.ConnectionParameters(
                            host, 5671, credentials=ExternalCredentials(),
                            ssl=True, ssl_options=ssl_options))


        # Create and bind to queue
        EXCHANGE_NAME = "scmb"
        ROUTING_KEY = "scmb.#"
        if('scmb' in route):
                ROUTING_KEY = route

        channel = connection.channel()
        result = channel.queue_declare()
        queue_name = result.method.queue
        print("ROUTING KEY: %s" %(ROUTING_KEY))

        channel.queue_bind(exchange=EXCHANGE_NAME, queue=queue_name, routing_key=ROUTING_KEY)

        channel.basic_consume(callback,
                  queue=queue_name,
                  no_ack=True)

        # Start listening for messages
        channel.start_consuming()

parser = argparse.ArgumentParser(add_help=True, description='Usage')
parser.add_argument('-a', '--appliance', dest='host',default='10.54.31.212', required=False,
                   help='HPE OneView Appliance hostname or IP')
parser.add_argument('-u', '--user', dest='user', required=False,
                   default='Administrator', help='HPE OneView Username')
parser.add_argument('-p', '--pass', dest='passwd',default='hpvse123', required=False,
                   help='HPE OneView Password')
parser.add_argument('-r', '--route', dest='route', required=False,
                   default='scmb.alerts.#', help='AMQP Routing Key')
args = parser.parse_args()
credential = {'userName': args.user, 'password': args.passwd}
user = args.user
passwd = args.passwd
host = args.host
con = connection(args.host)
sec = security(con)

login(con, credential)
acceptEULA(con)

#logfilepath = pwd + os.sep + 'SCMB_LogFile.log'
#logging.basicConfig(filename=logfilepath, filemode="a", level=logging.INFO, format="%(threadName)s:%(message)s")
#logging.info(" "+dat+" "+tim1+"BEGIN : SCMB Script!!!") 

#syslog file path
syslog_file =pwd+os.sep+"LogFile_"+dat+".log"

# Generate the RabbitMQ keypair (only needs to be done one time)
try:
    genRabbitCa(sec)
except:
    print("Certificate already existing")
time.sleep(15)

try:
    getCertCa(sec)
    getRabbitKp(sec)
except:
    print("Error in certificate download"+traceback.format_exc())
time.sleep(15)

logout(con)
recv(args.host, args.route)
fo.close()
