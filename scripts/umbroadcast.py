#coding=utf8

import sys 
import time
import hashlib
import requests
import json
import urllib2
import argparse
import redis
import threading
import Queue
import signal

reload(sys)
sys.setdefaultencoding('utf-8')

#global 
android_result = None
android2_result = None
ios_result = None
dev_ios_result = None
google_result = None
google2_result = None
google3_result = None

stop = False

# type of message
PUSH_CHANNEL_MSG = 2
PUSH_GROUP_MSG = 3

# system code
SUCCESS = 0                   # success
DEFICIENT_CONDITION = 1       # deficient condition
ETIMEOUT = 2                  # connection timeout
NOT_SUPPORT = -1              # don't support device
EXCEPTION = -2                # raise exception when handling

CHANNEL_NAME = '9D9B9EAC04C284FF698C9C79932A13B1'
UMENG_PUSH_CENTER_ANDRIOD = 'CBF183822A80C8C8E7E6055C4E37C32A'
UMENG_PUSH_CENTER_ANDRIOD2 = 'CBF183822A80C8C8E7E6055C4E37C322'
UMENG_PUSH_CENTER_IOS = '56433D548A7D50FFBFA8967C4C7D5195'
UMENG_PUSH_CENTER_DEV_IOS = '439BF69156BCC3B9FFDDD91800EC1AF8'
GOOGLE_PUSH_CENTER_ANDRIOD = 'F89E5E44BA124D35E104054088408E11'
GOOGLE_PUSH_CENTER_ANDRIOD2 = 'F89E5E44BA124D35E104054088408E22'
GOOGLE_PUSH_CENTER_ANDRIOD3 = 'F89E5E44BA124D35E104054088408E33'

"""
@description        get key and secret of umeng from redis
@param redis        instance of redis
@param platform     name of platform
@return             result of key and secret
@date               2015/11/25
@author             db.liu
"""
def get_umeng_key_secret(redis, platform):
    keyid = None
    if(platform == 'android'):
        keyid = UMENG_PUSH_CENTER_ANDRIOD;
    elif(platform == 'android2'):
        keyid = UMENG_PUSH_CENTER_ANDRIOD2;
    elif(platform == 'ios'):
        keyid = UMENG_PUSH_CENTER_IOS;
    elif(platform == 'iosdev'):
        keyid = UMENG_PUSH_CENTER_DEV_IOS;
    elif(platform == 'google'):
        keyid = GOOGLE_PUSH_CENTER_ANDRIOD;
    elif(platform == 'google2'):
        keyid = GOOGLE_PUSH_CENTER_ANDRIOD2;
    elif(platform == 'google3'):
        keyid = GOOGLE_PUSH_CENTER_ANDRIOD3;

    pipe = redis.pipeline()
    pipe.hget(keyid, 'platform')
    pipe.hget(keyid, 'appkey')
    pipe.hget(keyid, 'app_master_secret')
    result = pipe.execute()
    return result

"""
@description        calc md5 of string
@param s            string       
@return             value of md5
@date               2015/11/25
@author             huang songfa
"""
def md5(s):
    m = hashlib.md5(s)
    return m.hexdigest()


"""
@description        push message into umeng center
@param keyid        keyid           
@param appkey       appkey of umeng center            
@param secret       secret of umeng center            
@param msg_type     type of message
@param platform     platform of device (eg. android/apple)
@param device_token token of device
@param count        count of offline messages
@return             
@date               2015/11/25
@author             huang songfa
"""
def push_unicast(keyid, appkey, secret, device_token, msg_type, platform, count):
    timestamp = int(time.time() * 1000 )
    method = 'POST'
    if(platform == 'google' or platform == 'google2'):
        # google cloud message
        url = 'https://gcm-http.googleapis.com/gcm/send'
    elif(platform == 'google3'):
        # google firebase cloud message
        url = 'https://fcm.googleapis.com/fcm/send'
    else:
        # umeng platform
        url = 'http://msg.umeng.com/api/send'

    params = None

    key_value = None
    if(msg_type == PUSH_CHANNEL_MSG or msg_type == 0):
        key_value = "receiveMessage"
    elif(msg_type == PUSH_GROUP_MSG or msg_type == 1):
        key_value = 'groupMessage'
    else:
        key_value = "receiveMessage"

    if(platform == 'ios' or platform == 'iosdev'):
        params = {'appkey': appkey,
                'timestamp': timestamp,
                'device_tokens': device_token,
                'type': 'unicast',
                'payload': 
                {
                    'aps':
                    {
                        'alert': {"loc-key": key_value, "loc-args": [str(count)]},
                        'badge': count,
                        'sound': 'default'
                    }

                },
                'production_mode': (platform == 'ios' and 'true' or 'false')}
    elif(platform == 'android' or platform == 'android2'):
        #android_text = 'You have %d %s' % (count, 'messages' if count > 1 else 'message')
        params = {'appkey': appkey,
                'timestamp': timestamp,
                'device_tokens': device_token,
                'type': 'unicast',
                'payload': 
                {
                    'display_type': 'notification',
                    'body':
                    {
                        'ticker': 'ShadowTalk',
                        'title':  key_value,                               
                        'text': count
                    }

                },
                'production_mode': 'true'}
    elif(platform == 'google' or platform == 'google2'):
        params = {
                    "to":"%s" % (device_token),
                    "notification": {
                        "title":key_value,
                        "body":count
                    }
                }
    elif(platform == 'google3'):
        params = {
                    "to":"%s" % (device_token),
                    "notification": {
                        "title_loc_key":key_value,
                        "title_loc_args":[str(count)]
                    }
                }
    else:
        return NOT_SUPPORT # not support
    
    try:
        post_body = json.dumps(params)
        # print log
        print "keyid:       ", keyid
        print "token:       ", device_token
        print "platform:    ", platform
        print "count:       ", count
        print "msg_type:    ", key_value

        if(platform == 'google' or platform == 'google2' or platform == 'google3'):
            request = urllib2.Request(url, post_body)
            request.add_header("Content-Type", "application/json")
            request.add_header("Authorization", "key=%s" % (appkey))
            r = urllib2.urlopen(request, None, 5)
            code = r.read()
            #print code
            json_code = json.loads(code)
             
            if(json_code['success'] > 0):
                print "error:        success\n"
                return SUCCESS
            else:
                print "error:       ", code["results"], "\n"
        else:
            sign = md5('%s%s%s%s' % (method, url, post_body, secret))
            r = urllib2.urlopen(url + '?sign=' + sign, post_body, 5)
            code = r.read()
            #print code
            json_code = json.loads(code)
            if(json_code['ret'] == 'SUCCESS'):
                print "error:        success\n"
                return SUCCESS
            else:
                data = json_code['data']
                print "error:       ", data["error_code"], "\n"

    except urllib2.HTTPError,e:
        print "HttpError:   ", e.reason,e.read(), "\n"
    except urllib2.URLError,e:
        print "URLError:        ", e.reason, "\n"
        if(e.reason == 'timed out'):
            return ETIMEOUT
    except:
        print "Error:           post \n"

    return EXCEPTION

"""
@description        post data
@param redis        instance of redis
@return             
@date               2015/12/05
@author             db.liu
"""
def post_work_thread(redis, message_queue):
    if(redis == None or message_queue == None):
        return

    global stop
    deficient_condition_list = []
    while(stop == False):
        try:
            if(deficient_condition_list and len(deficient_condition_list) > 0):
                # copy 
                temp_list = deficient_condition_list[:]
                for item in temp_list:
                    deficient_condition_list.remove(item)
                    ret = handle_one_post(redis, item)
                    if((ret == DEFICIENT_CONDITION) 
                        and deficient_condition_list.count(item) == 0):
                        deficient_condition_list.append(item)
                    
            # get and remove from queue
            item = message_queue.get(False)
            ret = handle_one_post(redis, item)
            if((ret == DEFICIENT_CONDITION) 
                and deficient_condition_list.count(item) == 0):
                deficient_condition_list.append(item) 
            #elif(ret != SUCCESS):
            #    print 'Do not post in this time. [', item , ']'

            message_queue.task_done()
        except Queue.Empty:
            item = None
        except Queue.Full:
            print 'Queue has been fulled, drop ', item   

        # flush log   
        sys.stdout.flush()

        time.sleep(0.1)

"""
@description        post data
@param redis        instance of redis
@param item         one itme
@return             0:success, non-zero: failure
@date               2015/12/05
@author             db.liu
"""
def handle_one_post(redis, item):

    global android_result
    global android2_result
    global ios_result
    global dev_ios_result
    global google_result
    global google2_result
    global google3_result

    keyid = item
    pipe = redis.pipeline()
    pipe.hget(keyid, 'token')
    pipe.hget(keyid, 'platform')
    pipe.hget(keyid, 'count')       # get count
    pipe.hget(keyid, 'type')        # get type
    pipe.hget(keyid, 'last_time')   # update fetch timestamp
    result = pipe.execute()
    #print "execute result: \n%s:\n %s " % (keyid, result)

    token = result[0]
    platform = result[1]
    count = 0
    if(result[2]):
        count = int(result[2])
    msg_type = result[3]
    last_time = result[4]
    
    # strategy of posting:
    # post once per 5 seconds 
    # or counts in redis more than 2
    unicast = False
    if(last_time == None or last_time == 0):
        unicast = True
    elif(count > 2):
        unicast = True
    elif(time.time() - float(last_time) > 5):
        unicast = True

    if(unicast == True):
        
        if(count == 0):
            return SUCCESS

        if(token and len(token) > 0):
            #text = "You have %s unread messages." % count
            appkey = None
            secret = None
            if(platform == 'android'):
                appkey = android_result[1] 
                secret = android_result[2] 
            elif (platform == 'android2'):
                appkey = android2_result[1] 
                secret = android2_result[2] 
            elif (platform == 'ios'):
                appkey = ios_result[1] 
                secret = ios_result[2]
            elif (platform == 'iosdev'):
                appkey = dev_ios_result[1] 
                secret = dev_ios_result[2]
            elif (platform == 'google'):
                appkey = google_result[1] 
                secret = google_result[2]
            elif (platform == 'google2'):
                appkey = google2_result[1] 
                secret = google2_result[2]
            elif (platform == 'google3'):
                appkey = google3_result[1] 
                secret = google3_result[2]
            else:
                print 'Error: Not support %s' % (platform)

            if(appkey and secret):
                
                # push into umeng
                ret = push_unicast(keyid, appkey, secret, token, 
                        int(msg_type), platform, count)
                if(ret == SUCCESS):
                    # reset timestamp and count
                    reset_record(redis, keyid, count)               
                    return SUCCESS
                else:
                    reset_record(redis, keyid, count)               
                    return ret
            else:
                print 'Error: appkey or secret is None.'
                reset_record(redis, keyid, count)               
                return NOT_SUPPORT       # not support
        else:
            print 'keyid:        - ', keyid
            print 'paltfrom:     - ', platform
            print 'type:         - ', msg_type
            print 'Error:        - ', 'token is empty', '\n'
            reset_record(redis, keyid, count)
            return EXCEPTION

    return DEFICIENT_CONDITION

def reset_record(redis, keyid, count):
    pipe = redis.pipeline()
    pipe.hset(keyid, 'last_time', time.time())
    pipe.hincrby(keyid, 'count', -count)
    pipe.execute()

"""
@description        handle channel message
@param redis        instance of redis
@return             
@date               2015/12/03
@author             db.liu
"""
def handle_message_forever(redis): 
    # get emeng key and secret
    global android_result
    global android2_result
    global ios_result
    global dev_ios_result
    global google_result
    global google2_result
    global google3_result
    android_result = get_umeng_key_secret(redis, 'android')
    android2_result = get_umeng_key_secret(redis, 'android2')
    ios_result = get_umeng_key_secret(redis, 'ios')
    dev_ios_result = get_umeng_key_secret(redis, 'iosdev')
    google_result = get_umeng_key_secret(redis, 'google')
    google2_result = get_umeng_key_secret(redis, 'google2')
    google3_result = get_umeng_key_secret(redis, 'google3')
    print "key and secret: ", android_result
    print "key and secret: ", android2_result
    print "key and secret: ", ios_result
    print "key and secret: ", dev_ios_result
    print "key and secret: ", google_result
    print "key and secret: ", google2_result
    print "key and secret: ", google3_result

    # create queue
    message_queue = Queue.Queue(1024)
    print 'queue ', message_queue
    # create post-work thread
    post_work = threading.Thread(group = None, 
                                target = post_work_thread,
                                args = (redis, message_queue))
    post_work.start()

    # create pubsub
    pubsub = redis.pubsub()
    # subcribe push-service
    pubsub.subscribe(CHANNEL_NAME)

    global stop
    while(stop == False):
        # handle redis's message
        message = pubsub.get_message()
        if(message):
            if(message['type'] == 'message' and message['channel'] == CHANNEL_NAME):
                keyid = message['data']
                #print 'keyid: ', keyid
                #handle_one_post(redis, keyid)
                # enqueue
                try:
                    message_queue.put(keyid);       
                except Queue.Full:
                    print 'Queue has been fulled, directly post.'   
                    handle_one_post(redis, keyid)
            
        sys.stdout.flush()

        time.sleep(0.1)

    message_queue.join()
    post_work.join()

"""
@description        handle INT of signal 
@param redis        instance of redis
@param platform     name of platform
@return             result of key and secret
@date               2015/11/25
@author             db.liu
"""
def handle_sigint(a, b):
    global stop 
    stop = True

if __name__ == '__main__':
    # parse argument
    parser = argparse.ArgumentParser()
    parser.add_argument('-R', action = 'store', dest = 'redis_host', help = 'host of redis-server')


    # handle signal
    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGTERM, handle_sigint)
    signal.signal(signal.SIGSEGV, handle_sigint)
    
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

    try:
        # create redis
        redis = redis.StrictRedis(host, port)
        # handle message forever
        handle_message_forever(redis);
    except:
        print 'error: connect redis unsuccessfully'

