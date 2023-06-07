image = swr.cn-east-2.myhuaweicloud.com/squids/squids-opengauss

version = 5.0.0

build-arm:
	docker buildx build --platform linux/arm64 -t $(image):$(version)-arm -f Dockerfile-arm . --push

build-amd:
	docker buildx build --platform linux/amd64 -t $(image):$(version)-amd -f Dockerfile-amd . --push

create-manifest:
	docker manifest create $(image):$(version) $(image):$(version)-arm  $(image):$(version)-amd

push-manifest:
	docker manifest push $(image):$(version)

all: build-arm build-amd create-manifest  push-manifest