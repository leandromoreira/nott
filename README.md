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
```

# UI

![NOTT's UI](/img/nott_view.png "NOTT's UI")

