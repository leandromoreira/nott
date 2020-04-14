.PHONY: down run broadcast_tvshow

down:
	docker-compose down -v

run: down
	docker-compose run --rm --service-ports edge

test:
	docker-compose run --rm test

broadcast_tvshow:
	docker run --rm jrottenberg/ffmpeg:4.1 -hide_banner -re -f lavfi -i 'testsrc2=size=1280x720:rate=60,format=yuv420p' \
                       -f lavfi -i 'sine=frequency=440:sample_rate=48000:beep_factor=4' \
                       -c:v libx264 -preset ultrafast -tune zerolatency -profile:v high \
                       -b:v 1400k -bufsize 2800k -x264opts keyint=120:min-keyint=120:scenecut=-1 \
		       -c:a aac -b:a 32k -f flv rtmp://docker.for.mac.host.internal:1935/encoder/colorbar


