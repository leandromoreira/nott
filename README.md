[![Build Status](https://travis-ci.org/leandromoreira/nott.svg?branch=master)](https://travis-ci.org/leandromoreira/nott) [![license](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)

# NOTT - New OTT

In the three-post series, we’re going to build:
*  a simple [**video platform**](https://leandromoreira.com.br/2020/04/19/building-an-open-source-ott-platform/) using open-source software (nginx-rtmp, ffmpeg, nginx)
* add [features, using Lua code](https://leandromoreira.com.br/2020/04/19/empowering-nginx-with-lua-code/) on the front end
* design a platform that will enable to [**add code dynamically**](https://leandromoreira.com.br/2020/04/19/building-an-edge-computing-platform/)

# Architecture

![an overview of the NOTT project](/img/ott_overview.png "an overview of the NOTT project")

# How to use it

```bash
# make sure you're using MacOS
git clone https://github.com/leandromoreira/nott.git
cd nott
make run

# wait until the platform is up and running
# and run the video generator in another tab
make broadcast_tvshow

# ^ for linux users, you might need to use --network=host 
# and your IP instead of this docker.for.mac.host.internal
# for windows user I dunno =(
# but you can use OBS and point to your own machine

# open your browser and point it to http://localhost:8080/app

# in a different tab - you can test the stream
http http://localhost:8080/hls/colorbar.m3u8

# in another tab - let's add CU to redis
# -- first need to discovery the redis cluster id
docker ps | grep redis

# -- then let's connect to the redis cluster
docker exec -it f44ed71b3056 redis-cli -c -p 7000
# inside redis-cluster let's add the CU
set authentication "rewrite||local token = ngx.var.arg_token or ngx.var.cookie_superstition \n if token ~= 'token' then \n return ngx.exit(ngx.HTTP_FORBIDDEN) \n else \n ngx.header['Set-Cookie'] = {'superstition=token'} \n end"
sadd coding_units authentication

# go back and test the stream response - you should eventually (after max 20s)
# receive 403 as response
http http://localhost:8080/hls/colorbar.m3u8

# add the token and it'll work again
http http://localhost:8080/hls/colorbar.m3u8?token=token
```

# UI

![NOTT's UI](/img/nott_view.png "NOTT's UI")

