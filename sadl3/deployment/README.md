## Prepare image payload

# in git/sadlos2-master/sadl3/com.ge.research.sadl.parent/io.typefox.lsp.monaco
run

```
cd ~/git/sadlos2-master/sadl3/com.ge.research.sadl.parent/io.typefox.lsp.monaco

gradle buildStandaloneTomcat

```

and copy .build/tomcat.tar.gz to here


# in git/sadl-jupyterlab/sadl-client
run

```
npm install
npm run clean
npm run build:all

python setup.py sdist
```
and copy ./dist/sadl_web-0.0.1.tar.gz to here



## Build and Start image:

```
docker build --rm=true -t sadlos3/websadl .
docker run -p 8080:8080 -p 8888:8888 sadlos3/websadl
# sh to container 
sudo docker exec -i -t <name> /bin/bash
```
