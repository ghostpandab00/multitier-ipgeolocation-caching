import os
import requests
import json
import redis
from flask import Flask , jsonify
import boto3



def get_seceret(*,secret_name=None,secret_key=None,region_name=None):

  secrets_client = boto3.client(service_name ="secretsmanager",region_name=region_name)
  response = secrets_client.get_secret_value(SecretId=secret_name)
  ipstack_secrets = json.loads(response['SecretString'])
  return ipstack_secrets[secret_key] 



def get_from_cache(*,host=None):
  
  try: 

    redis_con = redis.Redis(host=redis_host,port=redis_port)
    cached_result = redis_con.get(host)
     
    if cached_result:

      output = json.loads(cached_result)
      output["cached"] = "True"
      return output

    else:

      return False
    
  except:

    return "Error In get_from_cache function."

    
 


def set_to_cache(*,host=None,ipgeolocation_key=None):
  
  try:

    redis_con = redis.Redis(host=redis_host,port=redis_port)
    ipgeolocation_url = "https://api.ipgeolocation.io/ipgeo?apiKey={}&ip={}".format(ipgeolocation_key,host)
    geodata = requests.get(url=ipgeolocation_url)
    geodata = geodata.json()
    geodata["cached"] = "False"
    redis_con.set(host,json.dumps(geodata))
    redis_con.expire(host,3600)

    return geodata

  except:
   
    return "Error In set_to_cache function."

    


app = Flask(__name__)

@app.route('/api/v1/<ip>')
def ipstack(ip=None):
  
  output = get_from_cache(host=ip)
  
  if output: 
    
    return jsonify(output)
   
  output = set_to_cache(host=ip,ipgeolocation_key=ipgeolocation_key)

  return jsonify(output)



    





if __name__ == "__main__":

  redis_port = os.getenv("REDIS_PORT","6379")
  redis_host = os.getenv("REDIS_HOST",None)
  app_port = os.getenv("APP_PORT","8080")
  ipgeolocation_key = os.getenv("API_KEY", None)
  ipgeolocation_key_from_secret = os.getenv("API_KEY_FROM_SECRETSMANAGER",False)
  ipgeolocation_key_secret_name = os.getenv("SECRET_NAME",None)
  ipgeolocation_key_name = os.getenv("SECRET_KEY",None)
  aws_region = os.getenv("REGION_NAME",None)

  if ipgeolocation_key_from_secret == "True":

    ipgeolocation_key = get_seceret(secret_name=ipgeolocation_key_secret_name,
                                    secret_key=ipgeolocation_key_name,
                                    region_name=aws_region )

      
  app.run(port=app_port,host="0.0.0.0",debug=True)
  







