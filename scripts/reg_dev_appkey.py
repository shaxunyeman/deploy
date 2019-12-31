import time
import hashlib
import requests
import json
import urllib2
import argparse
import redis

# type of message
PUSH_CHANNEL_MSG = 2
PUSH_GROUP_MSG = 3

CHANNEL_NAME = '9D9B9EAC04C284FF698C9C79932A13B1'
UMENG_PUSH_CENTER_ANDRIOD = 'CBF183822A80C8C8E7E6055C4E37C32A'
UMENG_PUSH_CENTER_ANDRIOD2 = 'CBF183822A80C8C8E7E6055C4E37C322'
UMENG_PUSH_CENTER_IOS = '56433D548A7D50FFBFA8967C4C7D5195'
UMENG_PUSH_CENTER_DEV_IOS = '439BF69156BCC3B9FFDDD91800EC1AF8'
GOOGLE_PUSH_CENTER_ANDRIOD = 'F89E5E44BA124D35E104054088408E11'
GOOGLE_PUSH_CENTER_ANDRIOD2 = 'F89E5E44BA124D35E104054088408E22'
GOOGLE_PUSH_CENTER_ANDRIOD3 = 'F89E5E44BA124D35E104054088408E33'

def reg_key_and_secret(redis):
    pipe = redis.pipeline()

    # register umeng's key and secret
    pipe.hset(UMENG_PUSH_CENTER_ANDRIOD, 'platform', 'android')
    pipe.hset(UMENG_PUSH_CENTER_ANDRIOD, 'appkey', '559ba39467e58e3a39001862')
    pipe.hset(UMENG_PUSH_CENTER_ANDRIOD, 'app_master_secret', 'xytnkdesvkio0xlkcqfsrnbnwf5qmi2b')
    
    pipe.hset(UMENG_PUSH_CENTER_ANDRIOD2, 'platform', 'android2')
    pipe.hset(UMENG_PUSH_CENTER_ANDRIOD2, 'appkey', '57bbb1af67e58e7239002353')
    pipe.hset(UMENG_PUSH_CENTER_ANDRIOD2, 'app_master_secret', '0ul0ng7fgnyu4xpeyry7yzogalnygmlw')


    pipe.hset(UMENG_PUSH_CENTER_DEV_IOS, 'platform', 'iosdev')
    pipe.hset(UMENG_PUSH_CENTER_DEV_IOS, 'appkey', '558a118567e58edeb0005e3d')
    pipe.hset(UMENG_PUSH_CENTER_DEV_IOS, 'app_master_secret', 'ti14xkuzlkl8tjfmwuscznrq5nrzhw2f')

    pipe.hset(UMENG_PUSH_CENTER_IOS, 'platform', 'ios')
    pipe.hset(UMENG_PUSH_CENTER_IOS, 'appkey', '558a118567e58edeb0005e3d')
    pipe.hset(UMENG_PUSH_CENTER_IOS, 'app_master_secret', 'ti14xkuzlkl8tjfmwuscznrq5nrzhw2f')

    # register google play's key and secret
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD, 'platform', 'google')
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD, 'appkey', 'AIzaSyAz17BH7UOEoGTrUm58Lz4JtEH640apK3c')
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD, 'app_master_secret', '128359019842')

    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD2, 'platform', 'google2')
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD2, 'appkey', 'AIzaSyB45vsygzGVhUHybZwhdTpbG7fkPc_i5Zg')
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD2, 'app_master_secret', '858563768464')
    
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD3, 'platform', 'google3')
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD3, 'appkey', 'AAAA2rlpa4U:APA91bFWRw3iDfm6vVPpsALEq13ZUlkmB1kV5OygH7U_igawkbkogRQqGh6X7qWAn0ib3NPC3bym_iaOd10_KLOGbhuMyd6QUJxXszvW3jsHRTZlZ-mb6PSOeaWgYsyjbMRVPxMfipbc')
    pipe.hset(GOOGLE_PUSH_CENTER_ANDRIOD3, 'app_master_secret', '939413564293')
    
    result = pipe.execute()
    return result

if __name__ == '__main__':
    # parse argument
    parser = argparse.ArgumentParser()
    parser.add_argument('-R', action = 'store', dest = 'redis_host', help = 'host of redis-server')
    
    results = parser.parse_args()

    # host of redis-server
    redis_host = results.redis_host
    host_port = redis_host.split(':')
    host = None 
    port = 6379
    if(len(host_port) == 2):
        host = host_port[0]
        port = int(host_port[1])
    else:
        host = host_port[0]
    
    print "connect to redis: %s:%d" % (host, port) 

    # create redis
    redis = redis.StrictRedis(host, port)

    # handle message forever
    result = reg_key_and_secret(redis)
    print 'store dev key: ', result

