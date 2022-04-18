from flask import Flask, render_template
import requests
import re
import os
import socket

app = Flask(__name__)



@app.route('/',strict_slashes=False)
@app.route('/ip',strict_slashes=False)
@app.route('/ip/<ip>',strict_slashes=False)
def index(ip=None):
  
  if ip != None:
        
    pattern = re.compile("^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")
    valid_ip = pattern.match(ip.strip())
    
    if valid_ip:
        
      api_url = "http://{}:{}/{}/{}".format(api_server,api_server_port,api_path.strip('/'),ip) 
      response = requests.get(url=api_url)
      geodata = response.json()
      continent_name = geodata['continent_name']
      continent_code = geodata['continent_code']
      country_name = geodata['country_name']
      isp = geodata['isp']
      cached = geodata['cached']
      hostname = socket.gethostname()
      ip = socket.gethostbyname(hostname)
    
  
      return render_template('index.html',
                         continent_name=continent_name,
                         continent_code=continent_code,
                         country_name=country_name,
                         isp=isp,
                         cached=cached,
                         hostname=hostname,
                         ip=ip

                         )

    else:
        
      return render_template('error.html')

  else:
       
    return render_template('error.html')
    
  



if __name__ == "__main__":
    
  api_server = os.getenv("API_SERVER",None)
  api_server_port = os.getenv("API_SERVER_PORT",None)
  api_path = os.getenv("API_PATH",None)
  app_port = os.getenv('APP_PORT',"8080") 
  app.run(port=app_port,host="0.0.0.0",debug=True)
